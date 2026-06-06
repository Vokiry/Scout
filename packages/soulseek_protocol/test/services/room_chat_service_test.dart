import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

class MockServerTransport implements ServerTransport {
  final _messageController = StreamController<SoulseekMessage>.broadcast();
  final _stateController = StreamController<ServerConnectionState>.broadcast();
  final _connectionInfoController = StreamController<ConnectionInfo>.broadcast();
  final List<SoulseekMessage> sentMessages = [];

  @override
  Stream<ServerConnectionState> get stateChanges => _stateController.stream;

  @override
  Stream<SoulseekMessage> get messages => _messageController.stream;

  @override
  Stream<ConnectionInfo> get connectionInfo => _connectionInfoController.stream;

  @override
  ServerConnectionState get state => ServerConnectionState.disconnected;

  @override
  bool get authenticated => false;

  @override
  String? get username => null;

  @override
  void init() {}

  @override
  void setServer(String host, int port) {}

  @override
  Future<void> connect(String username, String password) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void sendMessage(SoulseekMessage message) {
    sentMessages.add(message);
  }

  @override
  void sendRaw(int code, Uint8List payload) {
    sentMessages.add(SoulseekMessage(code, payload));
  }

  @override
  void dispose() {
    _messageController.close();
    _stateController.close();
    _connectionInfoController.close();
  }

  void injectMessage(SoulseekMessage message) {
    _messageController.add(message);
  }
}

void main() {
  group('RoomChatService', () {
    late RoomChatService service;
    late MockServerTransport mockServer;

    setUp(() {
      mockServer = MockServerTransport();
      service = RoomChatService(server: mockServer);
      service.init();
    });

    tearDown(() {
      service.dispose();
      mockServer.dispose();
    });

    test('joinRoom sends joinRoom message', () {
      service.joinRoom('Room1');
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.joinRoom));
      final r = ReadBuffer(msg.payload);
      expect(r.readString(), equals('Room1'));
    });

    test('leaveRoom sends leaveRoom message', () {
      service.leaveRoom('Room1');
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.leaveRoom));
    });

    test('sendMessage sends roomMessage', () {
      service.sendMessage('Room1', 'hello');
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.roomMessage));
      final r = ReadBuffer(msg.payload);
      expect(r.readString(), equals('Room1'));
      expect(r.readString(), equals('hello'));
    });

    test('requestRoomList sends roomList message', () {
      service.requestRoomList();
      expect(mockServer.sentMessages.length, equals(1));
      expect(mockServer.sentMessages.first.code, equals(ServerCode.roomList));
    });

    test('setRoomTicker sends roomTickerSet', () {
      service.setRoomTicker('Room1', 'hello');
      expect(mockServer.sentMessages.length, equals(1));
      expect(mockServer.sentMessages.first.code, equals(ServerCode.roomTickerSet));
    });

    test('removeRoomTicker sends roomTickerRemove', () {
      service.removeRoomTicker('Room1');
      expect(mockServer.sentMessages.length, equals(1));
      expect(mockServer.sentMessages.first.code, equals(ServerCode.roomTickerRemove));
    });

    test('roomMessages emits on incoming roomMessage', () async {
      final messages = <RoomMessage>[];
      final sub = service.roomMessages.listen((m) => messages.add(m));

      final w = WriteBuffer();
      w.writeString('Room1');
      w.writeString('alice');
      w.writeString('hello');

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.roomMessage, w.toBytes()),
      );

      await Future.delayed(Duration.zero);
      expect(messages.length, equals(1));
      expect(messages.first.roomName, equals('Room1'));
      expect(messages.first.username, equals('alice'));
      expect(messages.first.message, equals('hello'));

      await sub.cancel();
    });

    test('userJoined emits on incoming userJoinedRoom', () async {
      final events = <UserJoinedRoom>[];
      final sub = service.userJoined.listen((e) => events.add(e));

      final w = WriteBuffer();
      w.writeString('Room1');
      w.writeString('alice');
      w.writeInt32(3);
      w.writeInt32(1000);
      w.writeInt32(500);
      w.writeInt32(10);

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.userJoinedRoom, w.toBytes()),
      );

      await Future.delayed(Duration.zero);
      expect(events.length, equals(1));
      expect(events.first.roomName, equals('Room1'));
      expect(events.first.username, equals('alice'));

      await sub.cancel();
    });

    test('userLeft emits on incoming userLeftRoom', () async {
      final events = <UserLeftRoom>[];
      final sub = service.userLeft.listen((e) => events.add(e));

      final w = WriteBuffer();
      w.writeString('Room1');
      w.writeString('alice');

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.userLeftRoom, w.toBytes()),
      );

      await Future.delayed(Duration.zero);
      expect(events.length, equals(1));
      expect(events.first.roomName, equals('Room1'));

      await sub.cancel();
    });

    test('roomList emits on incoming roomList', () async {
      final lists = <RoomList>[];
      final sub = service.roomList.listen((l) => lists.add(l));

      final w = WriteBuffer();
      w.writeInt32(1);
      w.writeString('Room1');
      w.writeInt32(10);

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.roomList, w.toBytes()),
      );

      await Future.delayed(Duration.zero);
      expect(lists.length, equals(1));
      expect(lists.first.rooms.length, equals(1));

      await sub.cancel();
    });

    test('ignores non-room messages', () async {
      final messages = <RoomMessage>[];
      final sub = service.roomMessages.listen((m) => messages.add(m));

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.searchResponse, Uint8List(0)),
      );

      await Future.delayed(Duration.zero);
      expect(messages, isEmpty);

      await sub.cancel();
    });

    test('malformed room messages do not crash', () async {
      final messages = <RoomMessage>[];
      final sub = service.roomMessages.listen((m) => messages.add(m));

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.roomMessage, Uint8List(0)),
      );

      await Future.delayed(Duration.zero);
      expect(messages, isEmpty);

      await sub.cancel();
    });
  });
}
