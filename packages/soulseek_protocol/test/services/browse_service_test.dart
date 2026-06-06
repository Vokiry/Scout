import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:soulseek_protocol/src/peer/peer_connection.dart';
import 'package:test/test.dart';

/// Mock peer connection for testing BrowseService.
class MockPeerConnection implements TransferConnection {
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

  void injectMessage(SoulseekMessage message) {
    _messagesController.add(message);
  }

  void close() {
    _messagesController.close();
  }
}

void main() {
  group('BrowseService', () {
    late BrowseService service;
    late MockPeerConnection mockConnection;

    setUp(() {
      service = BrowseService();
      mockConnection = MockPeerConnection();
    });

    tearDown(() {
      mockConnection.close();
      service.dispose();
    });

    test('sends FolderContentsRequest', () {
      service.browseUser(connection: mockConnection);
      expect(mockConnection.sentMessages.length, equals(1));
      final msg = mockConnection.sentMessages.first;
      expect(msg.code, equals(PeerCode.folderContents));
    });

    test('sends FolderContentsRequest with custom directory', () {
      service.browseUser(connection: mockConnection, directory: 'Music');
      final msg = mockConnection.sentMessages.first;
      final buffer = ReadBuffer(msg.payload);
      expect(buffer.readString(), equals('Music'));
    });

    test('returns parsed FolderContentsReply', () async {
      final w = WriteBuffer();
      w.writeInt32(1); // folderCount
      w.writeString('Music');
      w.writeInt32(1); // fileCount
      w.writeInt32(0);
      w.writeString('song.flac');
      w.writeUint64(BigInt.from(5000));
      w.writeString('flac');
      w.writeInt32(0);

      final result = service.browseUser(connection: mockConnection);
      mockConnection.injectMessage(
        SoulseekMessage(PeerCode.folderContentsReply, w.toBytes()),
      );

      final reply = await result;
      expect(reply.folders.length, equals(1));
      expect(reply.folders[0].path, equals('Music'));
      expect(reply.folders[0].files[0].filename, equals('song.flac'));
    });

    test('throws on malformed response', () async {
      final result = service.browseUser(connection: mockConnection);
      mockConnection.injectMessage(
        SoulseekMessage(PeerCode.folderContentsReply, Uint8List(0)),
      );

      expect(result, throwsA(isA<Exception>()));
    });

    test('ignores non-reply messages on connection stream', () async {
      final w = WriteBuffer();
      w.writeInt32(1);
      w.writeString('Music');
      w.writeInt32(0);

      final result = service.browseUser(connection: mockConnection);
      mockConnection.injectMessage(
        SoulseekMessage(PeerCode.transferRequest, Uint8List(0)),
      );
      // After a short delay, inject the real reply
      await Future.delayed(Duration(milliseconds: 10));
      mockConnection.injectMessage(
        SoulseekMessage(PeerCode.folderContentsReply, w.toBytes()),
      );

      final reply = await result;
      expect(reply.folders.length, equals(1));
    });

    test('times out when no response received', () async {
      final result = service.browseUser(
        connection: mockConnection,
        timeout: Duration(milliseconds: 10),
      );

      expect(result, throwsA(isA<TimeoutException>()));
    });
  });
}
