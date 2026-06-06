import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

class MockSocketTransport implements SocketTransport {
  final _stateController = StreamController<SocketStateChanged>.broadcast();
  final _messageController = StreamController<SoulseekMessage>.broadcast();
  SocketState _state = SocketState.disconnected;

  @override
  Stream<SocketStateChanged> get stateChanges => _stateController.stream;
  @override
  Stream<SoulseekMessage> get messages => _messageController.stream;
  @override
  SocketState get state => _state;

  final List<SoulseekMessage> sentMessages = [];

  @override
  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 10)}) async {
    _state = SocketState.connected;
    _stateController.add(SocketStateChanged(state: SocketState.connected));
  }

  @override
  Future<void> disconnect() async {
    _state = SocketState.disconnected;
    _stateController.add(SocketStateChanged(state: SocketState.disconnected));
    _stateController.close();
    _messageController.close();
  }

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
    _stateController.close();
    _messageController.close();
  }

  void injectMessage(SoulseekMessage message) {
    _messageController.add(message);
  }

  void injectRawMessage(int code, List<int> payload) {
    _messageController.add(SoulseekMessage(code, Uint8List.fromList(payload)));
  }
}

void main() {
  late MockSocketTransport mockSocket;
  late ServerConnection server;

  setUp(() {
    mockSocket = MockSocketTransport();
    server = ServerConnection(socketTransport: mockSocket);
    server.init();
  });

  tearDown(() {
    server.dispose();
  });

  group('initial state', () {
    test('starts disconnected and not authenticated', () {
      expect(server.state, equals(ServerConnectionState.disconnected));
      expect(server.authenticated, isFalse);
      expect(server.username, isNull);
    });
  });

  group('connect', () {
    test('sends login message', () async {
      await server.connect('testuser', 'testpass');

      expect(server.username, equals('testuser'));
      expect(mockSocket.sentMessages.length, greaterThanOrEqualTo(1));
      final loginMsg = mockSocket.sentMessages[0];
      expect(loginMsg.code, equals(1)); // Login code

      // Verify login payload
      final buffer = ReadBuffer(loginMsg.payload);
      expect(buffer.readString(), equals('testuser'));
      expect(buffer.readString(), equals('testpass'));
    });
  });

  group('message handling', () {
    test('login response sets authenticated', () async {
      await server.connect('u', 'p');
      mockSocket.sentMessages.clear();

      // Inject login response
      final w = WriteBuffer();
      w.writeInt32(1); // success
      w.writeInt32(0x7F000001);
      w.writeInt32(2244);
      mockSocket.injectMessage(SoulseekMessage(ServerCode.loginResponse, w.toBytes()));

      // Wait for async processing
      await Future.delayed(Duration.zero);
      expect(server.authenticated, isTrue);
    });

    test('failed login response sets authenticated false', () async {
      await server.connect('u', 'p');
      mockSocket.sentMessages.clear();

      final w = WriteBuffer();
      w.writeInt32(0); // failure
      w.writeInt32(0);
      w.writeInt32(0);
      mockSocket.injectMessage(SoulseekMessage(ServerCode.loginResponse, w.toBytes()));

      await Future.delayed(Duration.zero);
      expect(server.authenticated, isFalse);
    });

    test('ping triggers pong response', () async {
      await server.connect('u', 'p');
      mockSocket.sentMessages.clear();

      mockSocket.injectMessage(SoulseekMessage(ServerCode.ping, Uint8List(0)));
      await Future.delayed(Duration.zero);

      expect(mockSocket.sentMessages.any((m) => m.code == ServerCode.pong), isTrue);
    });

    test('non-handled messages are forwarded to messages stream', () async {
      await server.connect('u', 'p');
      mockSocket.sentMessages.clear();

      final received = <SoulseekMessage>[];
      final sub = server.messages.listen((msg) => received.add(msg));

      mockSocket.injectMessage(SoulseekMessage(42, Uint8List.fromList([0xFF])));
      await Future.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received[0].code, equals(42));

      await sub.cancel();
    });

    test('server shutdown emits connection info', () async {
      await server.connect('u', 'p');
      mockSocket.sentMessages.clear();

      final w = WriteBuffer();
      w.writeString('Server is shutting down');

      final infoEvents = <ConnectionInfo>[];
      final sub = server.connectionInfo.listen((info) => infoEvents.add(info));

      mockSocket.injectMessage(SoulseekMessage(ServerCode.serverShuttingDown, w.toBytes()));
      await Future.delayed(Duration.zero);

      expect(infoEvents.any((i) => i.serverShuttingDown), isTrue);
      expect(infoEvents.any((i) => i.message == 'Server is shutting down'), isTrue);

      await sub.cancel();
    });
  });

  group('state changes', () {
    test('emits connecting state', () async {
      final states = <ServerConnectionState>[];
      final sub = server.stateChanges.listen((s) => states.add(s));

      await server.connect('u', 'p');
      expect(states, contains(ServerConnectionState.connecting));

      await sub.cancel();
    });

    test('emits disconnected on disconnect', () async {
      await server.connect('u', 'p');

      final states = <ServerConnectionState>[];
      final sub = server.stateChanges.listen((s) => states.add(s));

      await server.disconnect();
      await Future.delayed(Duration.zero); // let stream event deliver

      expect(states, contains(ServerConnectionState.disconnected));

      await sub.cancel();
    });
  });
}
