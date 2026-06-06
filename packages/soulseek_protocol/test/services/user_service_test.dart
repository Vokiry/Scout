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
  group('UserService', () {
    late MockServerTransport mockServer;
    late UserService users;

    setUp(() {
      mockServer = MockServerTransport();
      users = UserService(server: mockServer);
      users.init();
    });

    tearDown(() {
      users.dispose();
    });

    group('addUser', () {
      test('sends add user message', () {
        users.addUser('bob');

        expect(mockServer.sentMessages.length, equals(1));
        final msg = mockServer.sentMessages[0];
        expect(msg.code, equals(ServerCode.addUser));

        final buffer = ReadBuffer(msg.payload);
        expect(buffer.readString(), equals('bob'));
      });

      test('sends with correct username', () {
        users.addUser('charlie');
        final buffer = ReadBuffer(mockServer.sentMessages[0].payload);
        expect(buffer.readString(), equals('charlie'));
      });
    });

    group('getPeerAddress', () {
      test('sends get peer address message', () {
        users.getPeerAddress('carol');

        expect(mockServer.sentMessages.length, equals(1));
        final msg = mockServer.sentMessages[0];
        expect(msg.code, equals(ServerCode.getPeerAddress));

        final buffer = ReadBuffer(msg.payload);
        expect(buffer.readString(), equals('carol'));
      });
    });

    group('userStatus stream', () {
      test('emits UserStatus from server message', () async {
        final statuses = <UserStatus>[];
        final sub = users.userStatus.listen((s) => statuses.add(s));

        final w = WriteBuffer();
        w.writeString('dave');
        w.writeInt32(1); // online

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.statusResponse, w.toBytes()),
        );
        await Future.delayed(Duration.zero);

        expect(statuses.length, equals(1));
        expect(statuses[0].username, equals('dave'));
        expect(statuses[0].status, equals(1));

        await sub.cancel();
      });

      test('ignores non-status message codes', () async {
        final statuses = <UserStatus>[];
        final sub = users.userStatus.listen((s) => statuses.add(s));

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.ping, Uint8List(0)),
        );
        await Future.delayed(Duration.zero);

        expect(statuses, isEmpty);
        await sub.cancel();
      });

      test('malformed status does not crash', () async {
        final statuses = <UserStatus>[];
        final sub = users.userStatus.listen((s) => statuses.add(s));

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.statusResponse, Uint8List(0)),
        );
        await Future.delayed(Duration.zero);

        expect(statuses, isEmpty);
        await sub.cancel();
      });

      test('multiple status updates are all delivered', () async {
        final statuses = <UserStatus>[];
        final sub = users.userStatus.listen((s) => statuses.add(s));

        for (int i = 0; i < 3; i++) {
          final w = WriteBuffer();
          w.writeString('user$i');
          w.writeInt32(i);

          mockServer._messageController.add(
            SoulseekMessage(ServerCode.statusResponse, w.toBytes()),
          );
        }
        await Future.delayed(Duration.zero);

        expect(statuses.length, equals(3));

        await sub.cancel();
      });
    });

    group('lifecycle', () {
      test('dispose cancels subscription', () {
        users.dispose();
        users.dispose(); // safe to call twice
      });
    });
  });
}
