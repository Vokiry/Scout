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
  group('SearchService', () {
    late MockServerTransport mockServer;
    late SearchService search;

    setUp(() {
      mockServer = MockServerTransport();
      search = SearchService(server: mockServer);
      search.init();
    });

    tearDown(() {
      search.dispose();
    });

    group('search', () {
      test('sends search request with query', () {
        search.search('flac daft punk');

        expect(mockServer.sentMessages.length, equals(1));
        final msg = mockServer.sentMessages[0];
        expect(msg.code, equals(ServerCode.searchRequest));

        final buffer = ReadBuffer(msg.payload);
        final ticket = buffer.readInt32();
        expect(ticket, greaterThanOrEqualTo(1));
        expect(buffer.readString(), equals('flac daft punk'));
      });

      test('returns incrementing ticket numbers', () {
        final t1 = search.search('first');
        final t2 = search.search('second');

        expect(t2, equals(t1 + 1));
      });

      test('returns ticket starting at 1', () {
        final ticket = search.search('test');
        expect(ticket, equals(1));
      });
    });

    group('results stream', () {
      test('parses search response and emits result', () async {
        final results = <SearchResult>[];
        final sub = search.results.listen((r) => results.add(r));

        final w = WriteBuffer();
        w.writeString('bob');
        w.writeInt32(1); // ticket
        w.writeInt32(5); // totalFileCount
        w.writeInt32(2); // freeUploadSlots
        w.writeInt32(1000); // uploadSpeed
        w.writeInt32(0); // queueLength
        w.writeInt32(1); // fileCount

        w.writeInt32(0);
        w.writeString('file.flac');
        w.writeInt32(5000);
        w.writeString('flac');
        w.writeInt32(3);
        w.writeInt32(0); w.writeInt32(320);
        w.writeInt32(1); w.writeInt32(240);
        w.writeInt32(2); w.writeInt32(44100);

        mockServer.sentMessages.clear();
        mockServer._messageController.add(SoulseekMessage(ServerCode.searchResponse, w.toBytes()));
        await Future.delayed(Duration.zero);

        expect(results.length, equals(1));
        expect(results[0].username, equals('bob'));
        expect(results[0].freeUploadSlots, equals(2));
        expect(results[0].files.length, equals(1));

        await sub.cancel();
      });

      test('ignores non-search message codes', () async {
        final results = <SearchResult>[];
        final sub = search.results.listen((r) => results.add(r));

        mockServer._messageController.add(SoulseekMessage(ServerCode.ping, Uint8List(0)));
        await Future.delayed(Duration.zero);

        expect(results, isEmpty);
        await sub.cancel();
      });

      test('malformed search response does not crash', () async {
        final results = <SearchResult>[];
        final sub = search.results.listen((r) => results.add(r));

        mockServer._messageController.add(
          SoulseekMessage(ServerCode.searchResponse, Uint8List.fromList([0xFF, 0xFF])),
        );
        await Future.delayed(Duration.zero);

        expect(results, isEmpty);
        await sub.cancel();
      });

      test('handles old format search response', () async {
        final results = <SearchResult>[];
        final sub = search.results.listen((r) => results.add(r));

        final w = WriteBuffer();
        w.writeString('frank');
        w.writeInt32(2); // ticket
        w.writeInt32(1); // fileCount

        w.writeInt32(1);
        w.writeString('track.mp3');
        w.writeInt32(3000);
        w.writeString('mp3');
        w.writeInt32(3);
        w.writeInt32(0); w.writeInt32(256);
        w.writeInt32(1); w.writeInt32(180);
        w.writeInt32(2); w.writeInt32(44100);

        mockServer._messageController.add(SoulseekMessage(ServerCode.userSearchResponse, w.toBytes()));
        await Future.delayed(Duration.zero);

        expect(results.length, equals(1));
        expect(results[0].username, equals('frank'));
        expect(results[0].files.length, equals(1));

        await sub.cancel();
      });
    });

    test('dispose cancels subscription', () {
      search.dispose();
      // Should not throw on second dispose
      search.dispose();
    });
  });
}
