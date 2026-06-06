import 'dart:async';
import 'dart:io';

import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';
import '../peer/peer_connection.dart';

enum DownloadState { queued, requesting, downloading, paused, completed, failed, cancelled }

class DownloadFile {
  final String filename;
  final int size;
  final String username;
  final int fileCode;
  final String? localPath;

  DownloadState state;
  int downloadedBytes;
  int position;
  String? error;
  double? speed;
  String? placeInQueue;
  int retryCount = 0;

  final _progressController = StreamController<DownloadProgress>.broadcast();

  DownloadFile({
    required this.filename,
    required this.size,
    required this.username,
    required this.fileCode,
    this.localPath,
    this.state = DownloadState.queued,
    this.downloadedBytes = 0,
    this.position = 0,
  });

  Stream<DownloadProgress> get progress => _progressController.stream;

  void emitProgress() {
    _progressController.add(DownloadProgress(
      filename: filename,
      downloadedBytes: downloadedBytes,
      totalSize: size,
      speed: speed,
      state: state,
    ));
  }

  void dispose() {
    _progressController.close();
  }
}

class DownloadProgress {
  final String filename;
  final int downloadedBytes;
  final int totalSize;
  final double? speed;
  final DownloadState state;

  const DownloadProgress({
    required this.filename,
    required this.downloadedBytes,
    required this.totalSize,
    this.speed,
    required this.state,
  });

  double get percentage => totalSize > 0 ? downloadedBytes / totalSize : 0;
}

class DownloadManager {
  final Map<String, DownloadFile> _downloads = {};
  final _progressController = StreamController<Map<String, DownloadProgress>>.broadcast();
  Timer? _speedTimer;
  int _activeCount = 0;

  final int maxConcurrent;
  final int maxRetries;
  final Map<String, PeerConnection> _activeConnections = {};

  DownloadManager({
    this.maxConcurrent = 3,
    this.maxRetries = 3,
  });

  Stream<Map<String, DownloadProgress>> get allProgress => _progressController.stream;
  int get activeDownloadCount => _activeCount;
  int get queuedDownloadCount => _downloads.values.where((d) => d.state == DownloadState.queued).length;

  DownloadFile addDownload({
    required String filename,
    required int size,
    required String username,
    required int fileCode,
    String? localPath,
  }) {
    final download = DownloadFile(
      filename: filename,
      size: size,
      username: username,
      fileCode: fileCode,
      localPath: localPath ?? _defaultPath(filename),
    );
    _downloads['$username:$filename'] = download;
    _emitProgress();
    _processQueue();
    return download;
  }

  Future<void> startDownload(DownloadFile download, PeerConnection connection) async {
    if (download.state != DownloadState.queued && download.state != DownloadState.failed) return;

    _activeCount++;
    download.state = DownloadState.requesting;
    _activeConnections['${download.username}:${download.filename}'] = connection;
    _emitProgress();

    try {
      final request = TransferRequest(
        direction: Direction.download,
        fileCode: download.fileCode,
        filename: download.filename,
        fileSize: download.size,
      );
      connection.sendMessage(SoulseekMessage(request.code, request.serialize().toBytes()));

      download.state = DownloadState.downloading;
      _emitProgress();

      await _receiveFile(download, connection);
    } catch (e) {
      download.state = DownloadState.failed;
      download.error = e.toString();
      if (download.retryCount < maxRetries) {
        download.retryCount++;
        download.state = DownloadState.queued;
      }
      _emitProgress();
    } finally {
      _activeCount--;
      _activeConnections.remove('${download.username}:${download.filename}');
      _processQueue();
    }
  }

  Future<void> _receiveFile(DownloadFile download, PeerConnection connection) async {
    final file = File(download.localPath!);
    final raf = await file.open(mode: FileMode.write);
    int lastBytes = 0;
    final stopwatch = Stopwatch()..start();

    try {
      final sub = connection.messages.listen((message) async {
        if (message.code == PeerCode.transferResponse) {
          final buffer = ReadBuffer(message.payload);
          final response = buffer.readInt32();
          if (response != 0) {
            download.state = DownloadState.failed;
            download.error = 'Transfer denied (code: $response)';
            download.emitProgress();
            return;
          }
        }

        raf.writeFromSync(message.payload);
        download.downloadedBytes += message.payload.length;
        download.position += message.payload.length;

        if (stopwatch.elapsedMilliseconds >= 500) {
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          download.speed = (download.downloadedBytes - lastBytes) / elapsed;
          lastBytes = download.downloadedBytes;
          stopwatch.reset();
        }

        _emitProgress();
        download.emitProgress();

        if (download.downloadedBytes >= download.size) {
          download.state = DownloadState.completed;
          _emitProgress();
          download.emitProgress();
        }
      });

      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return download.state == DownloadState.downloading;
      });

      await sub.cancel();
    } finally {
      await raf.close();
    }
  }

  void pauseDownload(DownloadFile download) {
    if (download.state == DownloadState.downloading) {
      download.state = DownloadState.paused;
      _emitProgress();
      download.emitProgress();
    }
  }

  void resumeDownload(DownloadFile download) {
    if (download.state == DownloadState.paused) {
      download.state = DownloadState.queued;
      _emitProgress();
      _processQueue();
    }
  }

  void cancelDownload(DownloadFile download) {
    download.state = DownloadState.cancelled;
    _emitProgress();
    download.emitProgress();
  }

  void removeDownload(DownloadFile download) {
    _downloads.remove('${download.username}:${download.filename}');
    _activeConnections.remove('${download.username}:${download.filename}');
    download.dispose();
    _emitProgress();
  }

  void retryDownload(DownloadFile download) {
    if (download.state == DownloadState.failed) {
      download.retryCount = 0;
      download.state = DownloadState.queued;
      _emitProgress();
      _processQueue();
    }
  }

  void _processQueue() {
    if (_activeCount >= maxConcurrent) return;

    final queued = _downloads.values
        .where((d) => d.state == DownloadState.queued)
        .toList();

    for (final download in queued) {
      if (_activeCount >= maxConcurrent) break;
      final key = '${download.username}:${download.filename}';
      final conn = _activeConnections[key];
      if (conn != null) {
        _activeCount++;
        download.state = DownloadState.requesting;
        _emitProgress();
        _startQueuedDownload(download, conn);
      }
    }
  }

  Future<void> _startQueuedDownload(DownloadFile download, PeerConnection connection) async {
    try {
      await startDownload(download, connection);
    } catch (e) {
      download.state = DownloadState.failed;
      download.error = e.toString();
      _emitProgress();
    }
  }

  void _emitProgress() {
    final progressMap = <String, DownloadProgress>{};
    for (final entry in _downloads.entries) {
      final d = entry.value;
      progressMap[entry.key] = DownloadProgress(
        filename: d.filename,
        downloadedBytes: d.downloadedBytes,
        totalSize: d.size,
        speed: d.speed,
        state: d.state,
      );
    }
    _progressController.add(progressMap);
  }

  String _defaultPath(String filename) {
    final name = filename.split(Platform.pathSeparator).last;
    final dir = Directory.systemTemp.path;
    return '$dir/$name';
  }

  void dispose() {
    _speedTimer?.cancel();
    _progressController.close();
    for (final d in _downloads.values) {
      d.dispose();
    }
    for (final conn in _activeConnections.values) {
      conn.disconnect();
    }
    _downloads.clear();
    _activeConnections.clear();
  }
}
