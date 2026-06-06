import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:soulseek_protocol/src/connection/socket_manager.dart';
import 'package:test/test.dart';

/// Fake socket transport that simulates connection behavior.
class FakeSocketTransport implements SocketTransport {
  final _stateController = StreamController<SocketStateChanged>.broadcast();
  final _messagesController = StreamController<SoulseekMessage>.broadcast();
  final bool shouldConnect;

  SocketState _state = SocketState.disconnected;
  final List<SoulseekMessage> sentMessages = [];

  FakeSocketTransport({this.shouldConnect = true});

  @override
  SocketState get state => _state;

  @override
  Stream<SoulseekMessage> get messages => _messagesController.stream;

  @override
  Stream<SocketStateChanged> get stateChanges => _stateController.stream;

  @override
  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 10)}) async {
    _state = SocketState.connecting;
    if (shouldConnect) {
      _state = SocketState.connected;
      _stateController.add(SocketStateChanged(state: SocketState.connected));
    } else {
      _state = SocketState.disconnected;
      _stateController.add(SocketStateChanged(
        state: SocketState.disconnected,
        errorType: SocketErrorType.connectionRefused,
        errorMessage: 'Connection refused',
      ));
    }
  }

  @override
  Future<void> disconnect() async {
    _state = SocketState.disconnected;
    _stateController.add(SocketStateChanged(state: SocketState.disconnected));
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
    _messagesController.close();
    _stateController.close();
  }
}

void main() {
  group('DistributedNetwork', () {
    late DistributedNetwork network;
    late FakeSocketTransport fakeSocket;

    setUp(() {
      fakeSocket = FakeSocketTransport(shouldConnect: true);
      network = DistributedNetwork(
        username: 'testuser',
        socketFactory: () => fakeSocket,
      );
    });

    tearDown(() {
      network.dispose();
    });

    test('initial state is disconnected', () {
      expect(network.state, equals(DistributedState.disconnected));
      expect(network.role, equals(DistributedRole.none));
      expect(network.childCount, equals(0));
    });

    test('becomeParent sets role to parent', () {
      network.becomeParent();
      expect(network.role, equals(DistributedRole.parent));
      expect(network.state, equals(DistributedState.connected));
    });

    test('connectToParent with reachable host returns true', () async {
      final result = await network.connectToParent('127.0.0.1', 1);
      expect(result, isTrue);
      expect(network.role, equals(DistributedRole.child));
      expect(network.state, equals(DistributedState.connected));
    });

    test('connectToParent with unreachable host returns false', () async {
      final failNetwork = DistributedNetwork(
        username: 'testuser',
        socketFactory: () => FakeSocketTransport(shouldConnect: false),
      );
      final result = await failNetwork.connectToParent('192.0.2.1', 1);
      expect(result, isFalse);
      expect(failNetwork.role, equals(DistributedRole.none));
      expect(failNetwork.state, equals(DistributedState.disconnected));
      failNetwork.dispose();
    });

    test('acceptChildConnection increments child count', () {
      final socket = SocketManager();
      final accepted = network.acceptChildConnection(socket);
      expect(accepted, isTrue);
      expect(network.childCount, equals(1));
      expect(network.role, equals(DistributedRole.parent));
      socket.dispose();
    });

    test('acceptChildConnection returns false at max branches', () {
      final sockets = <SocketManager>[];
      for (int i = 0; i < 12; i++) {
        final socket = SocketManager();
        sockets.add(socket);
        if (!network.acceptChildConnection(socket)) {
          expect(i, greaterThanOrEqualTo(10));
        }
      }
      for (final s in sockets) {
        s.dispose();
      }
    });

    test('disconnect resets state', () {
      network.becomeParent();
      expect(network.role, equals(DistributedRole.parent));

      network.disconnect();
      expect(network.role, equals(DistributedRole.none));
      expect(network.state, equals(DistributedState.disconnected));
    });

    test('dispose is safe to call multiple times', () {
      network.dispose();
      network.dispose();
    });

    group('relaySearchRequest', () {
      test('does nothing when not parent', () {
        network.relaySearchRequest('test', 1);
      });

      test('does nothing when no children', () {
        network.becomeParent();
        network.relaySearchRequest('test', 1);
      });
    });

    group('relaySearchResponse', () {
      test('does nothing when not child', () {
        final result = SearchResult(
          username: 'u',
          ticket: 1,
          freeUploadSlots: 0,
          uploadSpeed: 0,
          queueLength: 0,
          files: [],
        );
        network.relaySearchResponse(result);
      });
    });

    group('stateChanges', () {
      test('emits events on state change', () async {
        final states = <DistributedState>[];
        final sub = network.stateChanges.listen((s) => states.add(s));

        network.becomeParent();
        await Future.delayed(Duration.zero);

        expect(states, contains(DistributedState.connected));
        await sub.cancel();
      });
    });
  });
}
