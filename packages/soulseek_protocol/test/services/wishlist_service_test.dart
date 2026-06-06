import 'dart:async';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

/// Mock server transport for testing WishlistService.
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
  group('WishlistService', () {
    late WishlistService service;
    late MockServerTransport mockServer;

    setUp(() {
      mockServer = MockServerTransport();
      service = WishlistService(server: mockServer);
      service.init();
    });

    tearDown(() {
      service.dispose();
      mockServer.dispose();
    });

    test('wishlistSearch sends wishes message', () {
      final ticket = service.wishlistSearch('flac');
      expect(ticket, equals(1));
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.wishes));
    });

    test('wishlistSearch increments ticket', () {
      expect(service.wishlistSearch('a'), equals(1));
      expect(service.wishlistSearch('b'), equals(2));
    });

    test('addWishlistItem sends wishlistInclusion with add=true', () {
      service.addWishlistItem('flac');
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.wishlistInclusion));
      final r = ReadBuffer(msg.payload);
      expect(r.readInt32(), equals(1)); // add
      expect(r.readString(), equals('flac'));
    });

    test('removeWishlistItem sends wishlistInclusion with add=false', () {
      service.removeWishlistItem('mp3');
      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages.first;
      expect(msg.code, equals(ServerCode.wishlistInclusion));
      final r = ReadBuffer(msg.payload);
      expect(r.readInt32(), equals(0)); // remove
      expect(r.readString(), equals('mp3'));
    });

    test('wishlistResults emits on wishReply message', () async {
      final results = <WishlistReply>[];
      final sub = service.wishlistResults.listen((r) => results.add(r));

      final w = WriteBuffer();
      w.writeString('alice');
      w.writeInt32(1);
      w.writeInt32(3);
      w.writeInt32(1000);
      w.writeInt32(0);
      w.writeInt32(1);
      w.writeInt32(0);
      w.writeString('song.flac');
      w.writeInt32(5000);
      w.writeString('flac');
      w.writeInt32(0);

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.wishReply, w.toBytes()),
      );

      await Future.delayed(Duration.zero);
      expect(results.length, equals(1));
      expect(results.first.username, equals('alice'));

      await sub.cancel();
    });

    test('wishlistResults ignores non-wishReply messages', () async {
      final results = <WishlistReply>[];
      final sub = service.wishlistResults.listen((r) => results.add(r));

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.searchResponse, Uint8List(0)),
      );

      await Future.delayed(Duration.zero);
      expect(results, isEmpty);

      await sub.cancel();
    });

    test('malformed wishReply does not crash', () async {
      final results = <WishlistReply>[];
      final sub = service.wishlistResults.listen((r) => results.add(r));

      mockServer.injectMessage(
        SoulseekMessage(ServerCode.wishReply, Uint8List(0)),
      );

      await Future.delayed(Duration.zero);
      expect(results, isEmpty);

      await sub.cancel();
    });
  });
}
