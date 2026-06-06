import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

class FakeSocketTransport implements SocketTransport {
  final _stateController = StreamController<SocketStateChanged>.broadcast();
  final _messageController = StreamController<SoulseekMessage>.broadcast();
  SocketState _state = SocketState.disconnected;

  @override
  Stream<SocketStateChanged> get stateChanges => _stateController.stream;
  @override
  Stream<SoulseekMessage> get messages => _messageController.stream;
  @override
  SocketState get state => _state;

  bool connectCalled = false;
  String? lastHost;
  int? lastPort;
  bool disconnectCalled = false;
  bool failConnect = false;

    @override
  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 10)}) async {
    connectCalled = true;
    lastHost = host;
    lastPort = port;
    if (failConnect) {
      _state = SocketState.disconnected;
      _stateController.add(SocketStateChanged(
        state: SocketState.disconnected,
        errorType: SocketErrorType.connectionRefused,
      ));
      return;
    }
    _state = SocketState.connected;
    _stateController.add(SocketStateChanged(state: SocketState.connected));
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    _state = SocketState.disconnected;
    _stateController.add(SocketStateChanged(state: SocketState.disconnected));
  }

  void emitDisconnected({String? error}) {
    _state = SocketState.disconnected;
    _stateController.add(SocketStateChanged(
      state: SocketState.disconnected,
      errorMessage: error,
    ));
  }

  @override
  void sendMessage(SoulseekMessage message) {}

  @override
  void sendRaw(int code, Uint8List payload) {}

  @override
  void dispose() {
    _stateController.close();
    _messageController.close();
  }
}

void main() {
  group('ReconnectionManager', () {
    test('initial state is not running', () {
      final fakeSocket = FakeSocketTransport();
      final reconnector = ReconnectionManager(fakeSocket);
      expect(reconnector.state.isRunning, isFalse);
      expect(reconnector.state.attempt, equals(0));
      reconnector.dispose();
    });

    test('start calls connect and is initially running', () async {
      final fakeSocket = FakeSocketTransport();
      final reconnector = ReconnectionManager(fakeSocket);

      expect(reconnector.state.isRunning, isFalse);
      reconnector.start('localhost', 2244);
      // After start(), the _tryReconnect() should have called connect()
      // synchronously because connect() is async but doesn't await before
      // setting connectCalled.
      expect(fakeSocket.connectCalled, isTrue,
          reason: '_tryReconnect should have called connect on the socket');
      expect(fakeSocket.lastHost, equals('localhost'));
      expect(fakeSocket.lastPort, equals(2244));
      expect(reconnector.state.isRunning, isTrue,
          reason: '_isRunning should be true synchronously after start()');

      // Let async events (connect success -> _onSocketStateChange) complete
      // before dispose to avoid adding events to closed controller
      await Future<void>.delayed(Duration.zero);
      reconnector.dispose();
    });

    test('stop resets state', () {
      final fakeSocket = FakeSocketTransport();
      final reconnector = ReconnectionManager(fakeSocket);

      reconnector.start('localhost', 2244);
      reconnector.stop();

      expect(reconnector.state.isRunning, isFalse);
      expect(reconnector.state.attempt, equals(0));

      reconnector.dispose();
    });

    test('stops after max connection failures', () async {
      final fakeSocket = FakeSocketTransport();
      fakeSocket.failConnect = true;

      final reconnector = ReconnectionManager(
        fakeSocket,
        config: ReconnectionConfig(
          baseDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 10),
          multiplier: 1.0,
          maxAttempts: 3,
          jitterMs: 0,
        ),
      );

      // Track final state changes
      final states = <ReconnectionState>[];
      final sub = reconnector.stateChanges.listen((s) => states.add(s));

      reconnector.start('localhost', 2244);

      // Wait for reconnection attempts to exhaust
      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(reconnector.state.isRunning, isFalse);
      expect(states.any((s) => s.isFinal), isTrue);
      expect(reconnector.state.attempt, greaterThanOrEqualTo(3));

      await sub.cancel();
      reconnector.dispose();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('resets attempt counter on reset()', () async {
      final fakeSocket = FakeSocketTransport();
      fakeSocket.failConnect = true;

      final reconnector = ReconnectionManager(
        fakeSocket,
        config: ReconnectionConfig(
          baseDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
          multiplier: 1.0,
          maxAttempts: 10,
          jitterMs: 0,
        ),
      );

      reconnector.start('localhost', 2244);

      // Let some attempts happen
      await Future<void>.delayed(Duration(milliseconds: 20));
      expect(reconnector.state.attempt, greaterThan(0));

      reconnector.reset();
      expect(reconnector.state.attempt, equals(0));

      reconnector.dispose();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('connected state stops reconnection', () async {
      final fakeSocket = FakeSocketTransport();
      fakeSocket.failConnect = true;

      final reconnector = ReconnectionManager(
        fakeSocket,
        config: ReconnectionConfig(
          baseDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
          multiplier: 1.0,
          maxAttempts: 10,
          jitterMs: 0,
        ),
      );

      reconnector.start('localhost', 2244);
      await Future<void>.delayed(Duration(milliseconds: 10));

      // Now make connections succeed
      fakeSocket.failConnect = false;
      // Trigger another reconnect attempt
      fakeSocket.emitDisconnected();

      await Future<void>.delayed(Duration(milliseconds: 20));
      // Should have connected and stopped reconnection
      expect(reconnector.state.isRunning, isFalse);

      reconnector.dispose();
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}
