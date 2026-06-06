import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

class MockServerTransport implements ServerTransport {
  final _stateController = StreamController<ServerConnectionState>.broadcast();
  final _messageController = StreamController<SoulseekMessage>.broadcast();
  final _connectionInfoController = StreamController<ConnectionInfo>.broadcast();
  bool _authenticated = false;
  String? _username;

  final List<SoulseekMessage> sentMessages = [];

  Stream<ServerConnectionState> get stateChanges => _stateController.stream;
  Stream<SoulseekMessage> get messages => _messageController.stream;
  Stream<ConnectionInfo> get connectionInfo => _connectionInfoController.stream;
  ServerConnectionState get state => ServerConnectionState.disconnected;
  bool get authenticated => _authenticated;
  String? get username => _username;

  void init() {}
  Future<void> connect(String username, String password) async {}
  Future<void> disconnect() async {}
  void setServer(String host, int port) {}
  void sendMessage(SoulseekMessage message) {
    sentMessages.add(message);
  }
  void sendRaw(int code, Uint8List payload) {}
  void dispose() {
    _stateController.close();
    _messageController.close();
    _connectionInfoController.close();
  }
}

void main() {
  group('ChatService', () {
    late MockServerTransport mockServer;
    late ChatService chat;

    setUp(() {
      mockServer = MockServerTransport();
      chat = ChatService(server: mockServer);
      chat.init();
    });

    tearDown(() {
      chat.dispose();
    });

    group('sendPrivateMessage', () {
      test('sends private message with correct code', () {
        chat.sendPrivateMessage('alice', 'hello');

        expect(mockServer.sentMessages.length, equals(1));
        final msg = mockServer.sentMessages[0];
        expect(msg.code, equals(ServerCode.privateMessage));
      });

      test('serializes username and message', () {
        chat.sendPrivateMessage('bob', 'hi there');

        final buffer = ReadBuffer(mockServer.sentMessages[0].payload);
        expect(buffer.readString(), equals('bob'));
        expect(buffer.readString(), equals('hi there'));
      });

      test('uses correct message code (51)', () {
        chat.sendPrivateMessage('carol', 'test');
        expect(mockServer.sentMessages[0].code, equals(51));
      });
    });

    group('privateMessages stream', () {
      test('emits PrivateMessage from server message', () async {
        final messages = <PrivateMessage>[];
        final sub = chat.privateMessages.listen((m) => messages.add(m));

        final w = WriteBuffer();
        w.writeString('alice');
        w.writeString('hello');
        w.writeInt32(12345);

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.privateMessage, w.toBytes()),
        );
        await Future.delayed(Duration.zero);

        expect(messages.length, equals(1));
        expect(messages[0].username, equals('alice'));
        expect(messages[0].message, equals('hello'));
        expect(messages[0].timestamp, equals(12345));

        await sub.cancel();
      });

      test('ignores non-private-message codes', () async {
        final messages = <PrivateMessage>[];
        final sub = chat.privateMessages.listen((m) => messages.add(m));

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.ping, Uint8List(0)),
        );
        await Future.delayed(Duration.zero);

        expect(messages, isEmpty);
        await sub.cancel();
      });

      test('malformed private message does not crash', () async {
        final messages = <PrivateMessage>[];
        final sub = chat.privateMessages.listen((m) => messages.add(m));

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.privateMessage, Uint8List(0)),
        );
        await Future.delayed(Duration.zero);

        expect(messages, isEmpty);
        await sub.cancel();
      });

      test('multiple messages are all delivered', () async {
        final messages = <PrivateMessage>[];
        final sub = chat.privateMessages.listen((m) => messages.add(m));

        for (int i = 0; i < 3; i++) {
          final w = WriteBuffer();
          w.writeString('user$i');
          w.writeString('msg$i');
          w.writeInt32(i);

          mockServer._messageController.add(
            SoulseekMessage(ServerCode.privateMessage, w.toBytes()),
          );
        }
        await Future.delayed(Duration.zero);

        expect(messages.length, equals(3));
        expect(messages[0].username, equals('user0'));
        expect(messages[2].username, equals('user2'));

        await sub.cancel();
      });
    });

    group('lifecycle', () {
      test('dispose cancels subscription', () {
        chat.dispose();
        chat.dispose(); // safe to call twice
      });
    });
  });
}
