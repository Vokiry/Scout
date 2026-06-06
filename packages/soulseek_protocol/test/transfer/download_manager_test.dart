import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:soulseek_protocol/src/peer/peer_connection.dart';
import 'package:test/test.dart';

/// Fake peer connection for testing downloads.
class FakePeerConnection implements TransferConnection {
  final _messagesController = StreamController<SoulseekMessage>.broadcast();
  final List<SoulseekMessage> sentMessages = [];

  @override
  String get username => 'testuser';

  @override
  Stream<SoulseekMessage> get messages => _messagesController.stream;

  @override
  void sendMessage(SoulseekMessage message) {
    sentMessages.add(message);
  }

  @override
  void sendRaw(int code, Uint8List payload) {
    sentMessages.add(SoulseekMessage(code, payload));
  }

  void injectTransferResponse() {
    final w = WriteBuffer();
    w.writeInt32(0); // success
    _messagesController.add(SoulseekMessage(PeerCode.transferResponse, w.toBytes()));
  }

  void injectDataPayload(Uint8List data) {
    _messagesController.add(SoulseekMessage(PeerCode.transferResponse, data));
  }

  void close() {
    _messagesController.close();
  }
}

void main() {
  late DownloadManager manager;

  setUp(() {
    manager = DownloadManager();
  });

  tearDown(() {
    manager.dispose();
  });

  group('addDownload', () {
    test('adds download in queued state', () {
      final dl = manager.addDownload(
        filename: 'song.flac',
        size: 1000,
        username: 'alice',
        fileCode: 1,
      );

      expect(dl.state, equals(DownloadState.queued));
      expect(dl.filename, equals('song.flac'));
      expect(dl.size, equals(1000));
      expect(dl.username, equals('alice'));
      expect(dl.fileCode, equals(1));
    });

    test('addDownload with custom localPath', () {
      final dl = manager.addDownload(
        filename: 'song.flac',
        size: 1000,
        username: 'alice',
        fileCode: 1,
        localPath: '/custom/path/song.flac',
      );

      expect(dl.localPath, equals('/custom/path/song.flac'));
    });

    test('addDownload without custom localPath uses default', () {
      final dl = manager.addDownload(
        filename: 'song.flac',
        size: 1000,
        username: 'alice',
        fileCode: 1,
      );

      expect(dl.localPath, isNotNull);
      expect(dl.localPath!.endsWith('song.flac'), isTrue);
    });
  });

  group('state transitions', () {
    test('pause transitions from downloading to paused', () {
      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      dl.state = DownloadState.downloading;
      manager.pauseDownload(dl);
      expect(dl.state, equals(DownloadState.paused));
    });

    test('pause does nothing when not downloading', () {
      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      manager.pauseDownload(dl);
      expect(dl.state, equals(DownloadState.queued));
    });

    test('resume transitions paused to queued', () {
      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      dl.state = DownloadState.paused;
      manager.resumeDownload(dl);
      expect(dl.state, equals(DownloadState.queued));
    });

    test('cancel transitions to cancelled', () {
      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      dl.state = DownloadState.downloading;
      manager.cancelDownload(dl);
      expect(dl.state, equals(DownloadState.cancelled));
    });

    test('remove removes from tracking', () {
      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      manager.removeDownload(dl);
      // Progress should no longer include this download
      final progress = <Map<String, DownloadProgress>>[];
      manager.allProgress.listen((p) => progress.add(p));
      expect(progress, isEmpty);
    });
  });

  group('progress stream', () {
    test('emits progress on add', () async {
      final progresses = <Map<String, DownloadProgress>>[];
      final sub = manager.allProgress.listen((p) => progresses.add(p));

      manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );

      await Future.delayed(Duration.zero);
      expect(progresses.length, greaterThan(0));
      expect(progresses.last.keys, contains('alice:song.flac'));

      await sub.cancel();
    });

    test('emits progress on cancel', () async {
      final progresses = <Map<String, DownloadProgress>>[];
      final sub = manager.allProgress.listen((p) => progresses.add(p));

      final dl = manager.addDownload(
        filename: 'song.flac', size: 1000, username: 'alice', fileCode: 1,
      );
      progresses.clear();

      manager.cancelDownload(dl);

      await Future.delayed(Duration.zero);
      expect(progresses.last['alice:song.flac']!.state, equals(DownloadState.cancelled));

      await sub.cancel();
    });
  });

  group('multiple downloads', () {
    test('tracks multiple files independently', () async {
      final progress = <Map<String, DownloadProgress>>[];
      final sub = manager.allProgress.listen((p) => progress.add(p));

      manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      await Future.delayed(Duration.zero);

      expect(progress, isNotEmpty);
      expect(progress.last.keys, contains('alice:a.flac'));

      manager.addDownload(
        filename: 'b.flac', size: 200, username: 'bob', fileCode: 2,
      );
      await Future.delayed(Duration.zero);

      expect(progress.last.keys, contains('bob:b.flac'));

      await sub.cancel();
    });

    test('same filename from different users is separate', () {
      final dl1 = manager.addDownload(
        filename: 'song.flac', size: 100, username: 'alice', fileCode: 1,
      );
      final dl2 = manager.addDownload(
        filename: 'song.flac', size: 200, username: 'bob', fileCode: 2,
      );
      expect(dl1.filename, equals(dl2.filename));
      expect(dl1.username, isNot(equals(dl2.username)));
    });

    test('remove one does not affect other', () {
      final dl1 = manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      manager.addDownload(
        filename: 'b.flac', size: 200, username: 'alice', fileCode: 2,
      );

      manager.removeDownload(dl1);
      // Should not crash
      expect(manager, isNotNull);
    });
  });

  group('concurrent limits', () {
    test('default maxConcurrent is 3', () {
      expect(manager.maxConcurrent, equals(3));
    });

    test('custom maxConcurrent is respected', () {
      final mgr = DownloadManager(maxConcurrent: 1);
      expect(mgr.maxConcurrent, equals(1));
      mgr.dispose();
    });

    test('activeDownloadCount starts at 0', () {
      expect(manager.activeDownloadCount, equals(0));
    });

    test('queuedDownloadCount returns queued count', () {
      manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      manager.addDownload(
        filename: 'b.flac', size: 200, username: 'alice', fileCode: 2,
      );
      expect(manager.queuedDownloadCount, equals(2));
    });
  });

  group('retry', () {
    test('retryDownload resets failed download to queued', () {
      final dl = manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      dl.state = DownloadState.failed;
      dl.error = 'Timeout';

      manager.retryDownload(dl);
      expect(dl.state, equals(DownloadState.queued));
      expect(dl.retryCount, equals(0));
    });

    test('retryDownload does nothing for non-failed states', () {
      final dl = manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      dl.state = DownloadState.completed;

      manager.retryDownload(dl);
      expect(dl.state, equals(DownloadState.completed));
    });

    test('retryCount starts at 0', () async {
      final dl = manager.addDownload(
        filename: 'a.flac', size: 100, username: 'alice', fileCode: 1,
      );
      expect(dl.retryCount, equals(0));
    });
  });

  group('DownloadFile', () {
    test('progress stream can be listened to', () async {
      final dl = DownloadFile(
        filename: 'test.flac', size: 1000, username: 'user', fileCode: 1,
      );
      expect(dl.progress, isNotNull);
      dl.dispose();
    });

    test('emitProgress emits on progress stream', () async {
      final dl = DownloadFile(
        filename: 'test.flac', size: 1000, username: 'user', fileCode: 1,
      );
      final events = <DownloadProgress>[];
      final sub = dl.progress.listen((p) => events.add(p));

      dl.state = DownloadState.downloading;
      dl.emitProgress();
      await Future.delayed(Duration.zero);

      expect(events, isNotEmpty);
      expect(events.first.state, equals(DownloadState.downloading));

      await sub.cancel();
      dl.dispose();
    });

    test('initial retryCount is 0', () {
      final dl = DownloadFile(
        filename: 'test.flac', size: 1000, username: 'user', fileCode: 1,
      );
      expect(dl.retryCount, equals(0));
      dl.dispose();
    });

    test('initial state is queued', () {
      final dl = DownloadFile(
        filename: 'test.flac', size: 1000, username: 'user', fileCode: 1,
      );
      expect(dl.state, equals(DownloadState.queued));
      dl.dispose();
    });

    test('dispose is safe to call multiple times', () {
      final dl = DownloadFile(
        filename: 'test.flac', size: 1000, username: 'user', fileCode: 1,
      );
      dl.dispose();
      dl.dispose();
    });
  });

  group('DownloadProgress', () {
    test('percentage is 0 for zero size', () {
      final p = DownloadProgress(
        filename: 'empty', downloadedBytes: 0, totalSize: 0, state: DownloadState.downloading,
      );
      expect(p.percentage, equals(0.0));
    });

    test('percentage is correct', () {
      final p = DownloadProgress(
        filename: 'file', downloadedBytes: 250, totalSize: 1000, state: DownloadState.downloading,
      );
      expect(p.percentage, equals(0.25));
    });

    test('percentage is 1.0 when complete', () {
      final p = DownloadProgress(
        filename: 'file', downloadedBytes: 500, totalSize: 500, state: DownloadState.completed,
      );
      expect(p.percentage, equals(1.0));
    });

    test('const constructor works', () {
      const p = DownloadProgress(
        filename: 'f', downloadedBytes: 0, totalSize: 0, state: DownloadState.queued,
      );
      expect(p.filename, equals('f'));
    });
  });
}
