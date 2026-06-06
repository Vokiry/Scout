import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

/// Helper: starts a raw TCP server that sends a SoulseekMessage frame.
Future<ServerSocket> _startEchoServer(int port) async {
  final server = await ServerSocket.bind('127.0.0.1', port);
  server.listen((socket) {
    socket.add(SoulseekMessage.encode(1, Uint8List.fromList([0x01, 0x02, 0x03])));
    socket.close();
  });
  return server;
}

/// Helper: starts a raw TCP server that sends specific bytes.
Future<ServerSocket> _startRawServer(int port, List<int> bytes) async {
  final server = await ServerSocket.bind('127.0.0.1', port);
  server.listen((socket) {
    socket.add(bytes);
    socket.close();
  });
  return server;
}

void main() {
  group('SocketManager', () {
    test('initial state is disconnected', () {
      final sm = SocketManager();
      expect(sm.state, equals(SocketState.disconnected));
      sm.dispose();
    });

    test('connect and receive message', () async {
      final server = await _startEchoServer(0);
      final port = server.port;

      final sm = SocketManager();
      final messages = <SoulseekMessage>[];
      final sub = sm.messages.listen((msg) => messages.add(msg));

      await sm.connect('127.0.0.1', port);
      expect(sm.state, equals(SocketState.connected));

      // Wait for message to arrive
      await Future.delayed(Duration(milliseconds: 200));
      expect(messages.length, greaterThan(0));
      expect(messages[0].code, equals(1));
      expect(messages[0].payload, equals([0x01, 0x02, 0x03]));

      await sub.cancel();
      await sm.disconnect();
      await server.close();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('state changes: disconnected -> connecting -> connected', () async {
      final server = await _startEchoServer(0);
      final port = server.port;

      final sm = SocketManager();
      final states = <SocketState>[];
      final sub = sm.stateChanges.listen((change) => states.add(change.state));

      await sm.connect('127.0.0.1', port);
      await Future.delayed(Duration.zero); // let stream events deliver

      expect(states, contains(SocketState.connecting));
      expect(states, contains(SocketState.connected));

      await sub.cancel();
      await sm.disconnect();
      await server.close();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('disconnect changes state to disconnected', () async {
      final server = await _startEchoServer(0);
      final port = server.port;

      final sm = SocketManager();
      await sm.connect('127.0.0.1', port);
      await sm.disconnect();

      expect(sm.state, equals(SocketState.disconnected));

      await server.close();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('sendMessage sends framed data', () async {
      final completer = Completer<List<int>>();
      final server = await ServerSocket.bind('127.0.0.1', 0);
      server.listen((socket) {
        socket.listen((data) {
          if (!completer.isCompleted) completer.complete(data.toList());
          socket.close();
          server.close();
        });
      });

      final sm = SocketManager();
      await sm.connect('127.0.0.1', server.port);

      sm.sendMessage(SoulseekMessage(42, Uint8List.fromList([0xFF])));
      final received = await completer.future.timeout(Duration(seconds: 3));

      // Verify framing: [length: u32][code: u32][payload]
      expect(received.length, greaterThanOrEqualTo(9));
      expect(received.sublist(4, 8), equals([42, 0, 0, 0])); // code = 42 LE
      expect(received.last, equals(0xFF)); // payload

      await sm.disconnect();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('connect to unreachable host returns disconnected', () async {
      final sm = SocketManager();
      await sm.connect('127.0.0.1', 1);
      expect(sm.state, equals(SocketState.disconnected));
      sm.dispose();
    }, timeout: Timeout(Duration(seconds: 15)));

    test('sendRaw throws when not connected', () {
      final sm = SocketManager();
      expect(
        () => sm.sendRaw(1, Uint8List(0)),
        throwsA(isA<SocketManagerException>()),
      );
      sm.dispose();
    });

    test('sendMessage throws when not connected', () {
      final sm = SocketManager();
      expect(
        () => sm.sendMessage(SoulseekMessage(1, Uint8List(0))),
        throwsA(isA<SocketManagerException>()),
      );
      sm.dispose();
    });

    test('message framing with multiple messages in one packet', () async {
      final frame1 = SoulseekMessage.encode(1, Uint8List.fromList([0x0A]));
      final frame2 = SoulseekMessage.encode(2, Uint8List.fromList([0x0B, 0x0C]));
      final combined = Uint8List.fromList([...frame1, ...frame2]);

      final server = await _startRawServer(0, combined);
      final port = server.port;

      final sm = SocketManager();
      final messages = <SoulseekMessage>[];
      final sub = sm.messages.listen((msg) => messages.add(msg));

      await sm.connect('127.0.0.1', port);
      await Future.delayed(Duration(milliseconds: 200));

      expect(messages.length, equals(2));
      expect(messages[0].code, equals(1));
      expect(messages[1].code, equals(2));

      await sub.cancel();
      await sm.disconnect();
      await server.close();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('dispose closes streams', () {
      final sm = SocketManager();
      sm.dispose();
      sm.dispose(); // safe to call twice
    });

    test('connect with invalid host returns disconnected', () async {
      final sm = SocketManager();
      await sm.connect('', 0);
      expect(sm.state, equals(SocketState.disconnected));
      sm.dispose();
    }, timeout: Timeout(Duration(seconds: 5)));

    test('disconnect while disconnected is safe', () async {
      final sm = SocketManager();
      await sm.disconnect();
      expect(sm.state, equals(SocketState.disconnected));
      sm.dispose();
    });

    test('sendRaw after disconnect throws', () async {
      final sm = SocketManager();
      sm.dispose();
      expect(
        () => sm.sendRaw(1, Uint8List(0)),
        throwsA(isA<SocketManagerException>()),
      );
    });

    test('multiple connect calls are safe', () async {
      final sm = SocketManager();
      await sm.connect('127.0.0.1', 1); // will fail, but should not crash
      await sm.connect('127.0.0.1', 1); // second call is safe
      sm.dispose();
    }, timeout: Timeout(Duration(seconds: 15)));
  });
}
