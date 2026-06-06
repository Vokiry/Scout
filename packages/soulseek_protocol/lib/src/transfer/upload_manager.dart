import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';
import '../peer/peer_connection.dart' show TransferConnection;

enum UploadState { queued, uploading, paused, completed, failed, cancelled }

class UploadFile {
  final String filename;
  final int size;
  final String username;
  final int fileCode;
  final String localPath;

  UploadState state;
  int uploadedBytes;
  double? speed;
  String? error;

  UploadFile({
    required this.filename,
    required this.size,
    required this.username,
    required this.fileCode,
    required this.localPath,
    this.state = UploadState.queued,
    this.uploadedBytes = 0,
  });
}

class UploadProgress {
  final String filename;
  final int uploadedBytes;
  final int totalSize;
  final double? speed;
  final UploadState state;

  const UploadProgress({
    required this.filename,
    required this.uploadedBytes,
    required this.totalSize,
    this.speed,
    required this.state,
  });

  double get percentage => totalSize > 0 ? uploadedBytes / totalSize : 0;
}

class UploadManager {
  final Map<String, UploadFile> _uploads = {};
  final _progressController = StreamController<Map<String, UploadProgress>>.broadcast();
  int _activeCount = 0;

  final int maxConcurrent;
  final int _maxChunkSize = 1024 * 1024; // 1MB per chunk

  UploadManager({this.maxConcurrent = 3});

  Stream<Map<String, UploadProgress>> get allProgress => _progressController.stream;
  int get activeUploadCount => _activeCount;

  void addUpload({
    required String filename,
    required int size,
    required String username,
    required int fileCode,
    required String localPath,
  }) {
    final upload = UploadFile(
      filename: filename,
      size: size,
      username: username,
      fileCode: fileCode,
      localPath: localPath,
    );
    _uploads['$username:$filename'] = upload;
    _emitProgress();
  }

  Future<void> handleTransferRequest(
    TransferRequest request,
    TransferConnection connection, {
    bool Function(String filename, int size)? onRequest,
  }) async {
    final key = '${connection.username}:${request.filename}';
    final existing = _uploads[key];

    if (onRequest != null && !onRequest(request.filename, request.fileSize)) {
      _sendTransferResponse(connection, 1); // denied
      return;
    }

    if (existing != null) {
      existing.state = UploadState.uploading;
    } else {
      final upload = UploadFile(
        filename: request.filename,
        size: request.fileSize,
        username: connection.username,
        fileCode: request.fileCode,
        localPath: request.filename,
        state: UploadState.uploading,
      );
      _uploads[key] = upload;
    }

    _sendTransferResponse(connection, 0); // accepted
    _activeCount++;
    _emitProgress();

    try {
      await _sendFile(connection, key, request.filename, request.fileSize);
    } catch (e) {
      final upload = _uploads[key];
      if (upload != null) {
        upload.state = UploadState.failed;
        upload.error = e.toString();
        _emitProgress();
      }
    } finally {
      _activeCount--;
    }
  }

  Future<void> _sendFile(
    TransferConnection connection,
    String key,
    String filename,
    int fileSize,
  ) async {
    final file = File(filename);
    if (!await file.exists()) {
      _sendTransferResponse(connection, 2); // file not found
      final upload = _uploads[key];
      if (upload != null) {
        upload.state = UploadState.failed;
        upload.error = 'File not found';
        _emitProgress();
      }
      return;
    }

    final raf = await file.open(mode: FileMode.read);
    int sent = 0;
    final stopwatch = Stopwatch()..start();

    try {
      while (sent < fileSize) {
        final chunkSize = _maxChunkSize;
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;

        final msg = SoulseekMessage(PeerCode.transferResponse, Uint8List.fromList(chunk));
        connection.sendMessage(msg);

        sent += chunk.length;
        final upload = _uploads[key];
        if (upload != null) {
          upload.uploadedBytes = sent;
          if (stopwatch.elapsedMilliseconds >= 500) {
            upload.speed = chunk.length / (stopwatch.elapsedMilliseconds / 1000.0);
            stopwatch.reset();
          }
          _emitProgress();
        }
      }

      final upload = _uploads[key];
      if (upload != null && upload.state != UploadState.cancelled) {
        upload.state = UploadState.completed;
        _emitProgress();
      }
    } finally {
      await raf.close();
    }
  }

  void _sendTransferResponse(TransferConnection connection, int responseCode) {
    final w = WriteBuffer();
    w.writeInt32(responseCode);
    connection.sendRaw(PeerCode.transferResponse, w.toBytes());
  }

  void cancelUpload(UploadFile upload) {
    upload.state = UploadState.cancelled;
    _emitProgress();
  }

  void removeUpload(UploadFile upload) {
    _uploads.remove('${upload.username}:${upload.filename}');
    _emitProgress();
  }

  void _emitProgress() {
    final progressMap = <String, UploadProgress>{};
    for (final entry in _uploads.entries) {
      final u = entry.value;
      progressMap[entry.key] = UploadProgress(
        filename: u.filename,
        uploadedBytes: u.uploadedBytes,
        totalSize: u.size,
        speed: u.speed,
        state: u.state,
      );
    }
    _progressController.add(progressMap);
  }

  void dispose() {
    _progressController.close();
    _uploads.clear();
  }
}
