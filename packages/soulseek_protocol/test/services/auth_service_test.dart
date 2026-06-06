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

  bool initCalled = false;
  bool connectCalled = false;
  bool disconnectCalled = false;
  bool disposeCalled = false;

  void init() {
    initCalled = true;
  }

  Future<void> connect(String username, String password) async {
    connectCalled = true;
    _username = username;
  }

  Future<void> disconnect() async {
    disconnectCalled = true;
  }

  void setServer(String host, int port) {}
  void sendMessage(SoulseekMessage message) {
    sentMessages.add(message);
  }
  void sendRaw(int code, Uint8List payload) {}

  void injectMessage(SoulseekMessage message) {
    _messageController.add(message);
  }

  void dispose() {
    disposeCalled = true;
    _stateController.close();
    _messageController.close();
    _connectionInfoController.close();
  }
}

void main() {
  group('AuthService', () {
    late MockServerTransport mockServer;
    late AuthService auth;

    setUp(() {
      mockServer = MockServerTransport();
      auth = AuthService(server: mockServer);
      auth.init();
    });

    tearDown(() {
      auth.dispose();
    });

    test('init calls server init', () {
      expect(mockServer.initCalled, isTrue);
    });

    test('dispose cleans up', () {
      auth.dispose();
      expect(mockServer.disposeCalled, isTrue);
    });

    test('initial state is disconnected and not authenticated', () {
      expect(auth.state, equals(ServerConnectionState.disconnected));
      expect(auth.authenticated, isFalse);
      expect(auth.username, isNull);
    });

    group('connect', () {
      test('delegates to server', () async {
        await auth.connect('alice', 'secret');
        expect(mockServer.connectCalled, isTrue);
        expect(mockServer.username, equals('alice'));
      });

      test('exposes username after connect', () async {
        await auth.connect('alice', 'secret');
        expect(auth.username, equals('alice'));
      });

      test('starts not authenticated', () async {
        await auth.connect('alice', 'secret');
        expect(auth.authenticated, isFalse);
      });
    });

    group('disconnect', () {
      test('calls server disconnect', () async {
        await auth.disconnect();
        expect(mockServer.disconnectCalled, isTrue);
      });

      test('is safe when already disconnected', () async {
        await auth.disconnect();
        await auth.disconnect();
        expect(mockServer.disconnectCalled, isTrue);
      });
    });

    group('connection state', () {
    test('stateChanges stream forwards server state', () async {
      final states = <ServerConnectionState>[];
      final sub = auth.connectionState.listen((s) => states.add(s));

      mockServer._stateController.add(ServerConnectionState.connected);
      await Future.delayed(Duration.zero);

      expect(states, contains(ServerConnectionState.connected));
      await sub.cancel();
    });

    test('authenticated state reflects server authentication', () async {
      mockServer._authenticated = true;
      expect(auth.authenticated, isTrue);
    });
    });

    group('connection info', () {
      test('connectionInfo forwards server info', () async {
        final infos = <ConnectionInfo>[];
        final sub = auth.connectionInfo.listen((i) => infos.add(i));

        mockServer._connectionInfoController.add(ConnectionInfo(
          authenticated: true,
          localIp: 0x7F000001,
          localPort: 2244,
        ));
        await Future.delayed(Duration.zero);

        expect(infos, isNotEmpty);
        expect(infos.first.authenticated, isTrue);
        await sub.cancel();
      });
    });

  });
}
