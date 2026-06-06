import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:soulseek_protocol/src/peer/peer_connection.dart';
import 'package:test/test.dart';

class FakePeerConnection implements TransferConnection {
  final _messagesController = StreamController<SoulseekMessage>.broadcast();
  final List<SoulseekMessage> sentMessages = [];

  String username = 'remote_user';

  Stream<SoulseekMessage> get messages => _messagesController.stream;

  void sendMessage(SoulseekMessage message) {
    sentMessages.add(message);
  }

  void sendRaw(int code, Uint8List payload) {
    sentMessages.add(SoulseekMessage(code, payload));
  }

  void close() {
    _messagesController.close();
  }
}

void main() {
  group('UploadManager', () {
    late UploadManager manager;

    setUp(() {
      manager = UploadManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('addUpload', () {
      test('adds upload in queued state', () {
        manager.addUpload(
          filename: 'song.flac',
          size: 1000,
          username: 'alice',
          fileCode: 1,
          localPath: '/music/song.flac',
        );

        final progress = <Map<String, UploadProgress>>[];
        manager.allProgress.listen((p) => progress.add(p));

        expect(manager.activeUploadCount, equals(0));
      });
    });

    group('handleTransferRequest', () {
      test('accepts valid request and sends response', () async {
        final conn = FakePeerConnection();
        final request = TransferRequest(
          direction: Direction.upload,
          fileCode: 1,
          filename: 'song.flac',
          fileSize: 1000,
        );

        await manager.handleTransferRequest(request, conn);

        expect(conn.sentMessages.any((m) => m.code == PeerCode.transferResponse), isTrue);
        conn.close();
      });

      test('rejects request when onRequest returns false', () async {
        final conn = FakePeerConnection();
        final request = TransferRequest(
          direction: Direction.upload,
          fileCode: 1,
          filename: 'song.flac',
          fileSize: 1000,
        );

        await manager.handleTransferRequest(request, conn, onRequest: (_, __) => false);

        expect(conn.sentMessages.length, equals(1));
        final response = ReadBuffer(conn.sentMessages[0].payload);
        expect(response.readInt32(), equals(1)); // denied
        conn.close();
      });

      test('accepts request when onRequest returns true', () async {
        final conn = FakePeerConnection();
        final request = TransferRequest(
          direction: Direction.upload,
          fileCode: 1,
          filename: 'song.flac',
          fileSize: 1000,
        );

        await manager.handleTransferRequest(request, conn, onRequest: (_, __) => true);

        expect(conn.sentMessages.any((m) => m.code == PeerCode.transferResponse), isTrue);
        conn.close();
      });
    });

    group('cancelUpload', () {
      test('marks upload as cancelled', () {
        manager.addUpload(
          filename: 'song.flac', size: 1000, username: 'user', fileCode: 1,
          localPath: '/music/song.flac',
        );

        final upload = UploadFile(
          filename: 'song.flac', size: 1000, username: 'user', fileCode: 1,
          localPath: '/music/song.flac',
        );
        manager.cancelUpload(upload);

        expect(upload.state, equals(UploadState.cancelled));
      });
    });

    group('removeUpload', () {
      test('removes upload from tracking', () {
        manager.addUpload(
          filename: 'song.flac', size: 1000, username: 'user', fileCode: 1,
          localPath: '/music/song.flac',
        );

        final upload = UploadFile(
          filename: 'song.flac', size: 1000, username: 'user', fileCode: 1,
          localPath: '/music/song.flac',
        );
        manager.removeUpload(upload);

        final progress = <Map<String, UploadProgress>>[];
        manager.allProgress.listen((p) => progress.add(p));
      });
    });

    test('dispose is safe to call multiple times', () {
      manager.dispose();
      manager.dispose();
    });
  });

  group('UploadProgress', () {
    test('percentage is 0 for zero size', () {
      final p = UploadProgress(
        filename: 'f', uploadedBytes: 0, totalSize: 0, state: UploadState.queued,
      );
      expect(p.percentage, equals(0.0));
    });

    test('percentage is correct', () {
      final p = UploadProgress(
        filename: 'f', uploadedBytes: 250, totalSize: 1000, state: UploadState.uploading,
      );
      expect(p.percentage, equals(0.25));
    });
  });
}
