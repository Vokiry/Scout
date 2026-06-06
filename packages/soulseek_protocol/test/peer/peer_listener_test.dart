import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:soulseek_protocol/src/connection/socket_manager.dart';
import 'package:soulseek_protocol/src/peer/peer_listener.dart';
import 'package:test/test.dart';

void main() {
  group('IncomingConnection', () {
    test('implements TransferConnection', () {
      final sm = SocketManager();
      final conn = IncomingConnection(sm, username: 'testuser');
      expect(conn.username, equals('testuser'));
      expect(conn.messages, isNotNull);
      conn.dispose();
    });

    test('username can be set', () {
      final sm = SocketManager();
      final conn = IncomingConnection(sm);
      conn.username = 'remote';
      expect(conn.username, equals('remote'));
      conn.dispose();
    });
  });

  group('PeerListener', () {
    test('start binds to a port and isListening is true', () async {
      final uploadManager = UploadManager();
      final listener = PeerListener(uploadManager: uploadManager);

      await listener.start(0);
      expect(listener.isListening, isTrue);
      expect(listener.port, greaterThan(0));

      await listener.stop();
      expect(listener.isListening, isFalse);
      uploadManager.dispose();
    });

    test('stop is safe when not started', () async {
      final uploadManager = UploadManager();
      final listener = PeerListener(uploadManager: uploadManager);

      await listener.stop();
      expect(listener.isListening, isFalse);

      uploadManager.dispose();
    });

    test('dispose is safe to call multiple times', () async {
      final uploadManager = UploadManager();
      final listener = PeerListener(uploadManager: uploadManager);

      await listener.start(0);
      listener.dispose();
      listener.dispose();

      uploadManager.dispose();
    });
  });
}
