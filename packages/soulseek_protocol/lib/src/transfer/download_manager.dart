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

  StreamController<DownloadProgress>? _progressController;

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

  Stream<DownloadProgress> get progress {
    _progressController ??= StreamController<DownloadProgress>.broadcast();
    return _progressController!.stream;
  }

  void dispose() {
    _progressController?.close();
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

  DownloadManager();

  Stream<Map<String, DownloadProgress>> get allProgress => _progressController.stream;

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
    return download;
  }

  Future<void> startDownload(DownloadFile download, PeerConnection connection) async {
    if (download.state != DownloadState.queued) return;

    download.state = DownloadState.requesting;

    try {
      // Send transfer request
      final request = TransferRequest(
        direction: Direction.download,
        fileCode: download.fileCode,
        filename: download.filename,
        fileSize: download.size,
      );
      connection.sendMessage(SoulseekMessage(request.code, request.serialize().toBytes()));

      download.state = DownloadState.downloading;
      _emitProgress();

      // Wait for transfer response and start receiving
      await _receiveFile(download, connection);
    } catch (e) {
      download.state = DownloadState.failed;
      download.error = e.toString();
      _emitProgress();
    }
  }

  Future<void> _receiveFile(DownloadFile download, PeerConnection connection) async {
    final file = File(download.localPath!);
    final raf = await file.open(mode: FileMode.write);
    int lastBytes = 0;
    final stopwatch = Stopwatch()..start();

    try {
      final subscription = connection.messages.listen((message) async {
        if (message.code == PeerCode.transferResponse) {
          final buffer = ReadBuffer(message.payload);
          final response = buffer.readInt32();
          if (response != 0) {
            // Error
            download.state = DownloadState.failed;
            download.error = 'Transfer denied (code: $response)';
            return;
          }
        }

        // Write received data
        raf.writeFromSync(message.payload);

        download.downloadedBytes += message.payload.length;
        download.position += message.payload.length;

        // Calculate speed every 500ms
        if (stopwatch.elapsedMilliseconds >= 500) {
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          download.speed = (download.downloadedBytes - lastBytes) / elapsed;
          lastBytes = download.downloadedBytes;
          stopwatch.reset();
        }

        _emitProgress();

        if (download.downloadedBytes >= download.size) {
          download.state = DownloadState.completed;
          _emitProgress();
        }
      });

      // Wait for completion
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return download.state == DownloadState.downloading;
      });

      await subscription.cancel();
    } finally {
      await raf.close();
    }
  }

  void pauseDownload(DownloadFile download) {
    if (download.state == DownloadState.downloading) {
      download.state = DownloadState.paused;
      _emitProgress();
    }
  }

  void resumeDownload(DownloadFile download) {
    if (download.state == DownloadState.paused) {
      download.state = DownloadState.queued;
      _emitProgress();
    }
  }

  void cancelDownload(DownloadFile download) {
    download.state = DownloadState.cancelled;
    _emitProgress();
  }

  void removeDownload(DownloadFile download) {
    _downloads.remove('${download.username}:${download.filename}');
    download.dispose();
    _emitProgress();
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
    _downloads.clear();
  }
}
