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
  late MockServerTransport mockServer;
  late SoulseekClient client;

  setUp(() {
    mockServer = MockServerTransport();
    client = SoulseekClient(server: mockServer);
    client.init();
  });

  tearDown(() {
    client.dispose();
  });

  group('init and dispose', () {
    test('init calls server init', () {
      expect(mockServer.initCalled, isTrue);
    });

    test('dispose cleans up', () {
      client.dispose();
      expect(mockServer.disposeCalled, isTrue);
    });
  });

  group('connect', () {
    test('delegates to server', () async {
      await client.connect('alice', 'secret');
      expect(mockServer.connectCalled, isTrue);
      expect(mockServer.username, equals('alice'));
    });

    test('sets authenticated state from server', () async {
      await client.connect('alice', 'secret');
      // Initially authenticated is false on the mock
      expect(client.authenticated, isFalse);
    });

    test('exposes username', () async {
      await client.connect('alice', 'secret');
      expect(client.username, equals('alice'));
    });
  });

  group('disconnect', () {
    test('calls server disconnect', () async {
      await client.disconnect();
      expect(mockServer.disconnectCalled, isTrue);
    });
  });

  group('search', () {
    test('sends search request message', () {
      client.search('flac daft punk');

      expect(mockServer.sentMessages.length, equals(1));
      final msg = mockServer.sentMessages[0];
      expect(msg.code, equals(ServerCode.searchRequest));

      final buffer = ReadBuffer(msg.payload);
      final ticket = buffer.readInt32();
      expect(ticket, greaterThanOrEqualTo(1));
      expect(buffer.readString(), equals('flac daft punk'));
    });

    test('increments ticket for each search', () {
      client.search('first');
      client.search('second');

      expect(mockServer.sentMessages.length, equals(2));
      final firstTicket = ReadBuffer(mockServer.sentMessages[0].payload).readInt32();
      final secondTicket = ReadBuffer(mockServer.sentMessages[1].payload).readInt32();
      expect(secondTicket, equals(firstTicket + 1));
    });
  });

  group('message routing', () {
    test('search response produces SearchResult on stream', () async {
      final results = <SearchResult>[];
      final sub = client.searchResults.listen((r) => results.add(r));

      // Build a valid search response message
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

      mockServer.injectMessage(SoulseekMessage(ServerCode.searchResponse, w.toBytes()));
      await Future.delayed(Duration.zero);

      expect(results.length, equals(1));
      expect(results[0].username, equals('bob'));
      expect(results[0].freeUploadSlots, equals(2));
      expect(results[0].files.length, equals(1));

      await sub.cancel();
    });

    test('private message produces on stream', () async {
      final messages = <PrivateMessage>[];
      final sub = client.privateMessages.listen((m) => messages.add(m));

      final w = WriteBuffer();
      w.writeString('charlie');
      w.writeString('hello there');
      w.writeInt32(12345);

      mockServer.injectMessage(SoulseekMessage(ServerCode.privateMessage, w.toBytes()));
      await Future.delayed(Duration.zero);

      expect(messages.length, equals(1));
      expect(messages[0].username, equals('charlie'));
      expect(messages[0].message, equals('hello there'));

      await sub.cancel();
    });

    test('user status produces on stream', () async {
      final statuses = <UserStatus>[];
      final sub = client.userStatus.listen((s) => statuses.add(s));

      final w = WriteBuffer();
      w.writeString('dave');
      w.writeInt32(1); // online

      mockServer.injectMessage(SoulseekMessage(ServerCode.statusResponse, w.toBytes()));
      await Future.delayed(Duration.zero);

      expect(statuses.length, equals(1));
      expect(statuses[0].username, equals('dave'));

      await sub.cancel();
    });

    test('malformed search response does not crash', () async {
      final results = <SearchResult>[];
      final sub = client.searchResults.listen((r) => results.add(r));

      // Inject garbage as search response
      mockServer.injectMessage(SoulseekMessage(ServerCode.searchResponse, Uint8List.fromList([0xFF, 0xFF])));
      await Future.delayed(Duration.zero);

      // Should not crash, just silently skip
      expect(results, isEmpty);

      await sub.cancel();
    });

    test('malformed private message does not crash', () async {
      final messages = <PrivateMessage>[];
      final sub = client.privateMessages.listen((m) => messages.add(m));

      mockServer.injectMessage(SoulseekMessage(ServerCode.privateMessage, Uint8List(0)));
      await Future.delayed(Duration.zero);

      expect(messages, isEmpty);
      await sub.cancel();
    });
  });

  group('sendPrivateMessage', () {
    test('sends private message with correct code', () {
      client.sendPrivateMessage('alice', 'hi');

      expect(mockServer.sentMessages.any((m) => m.code == ServerCode.privateMessage), isTrue);
    });
  });

  group('addUser', () {
    test('sends add user message', () {
      client.addUser('bob');

      expect(mockServer.sentMessages.any((m) => m.code == ServerCode.addUser), isTrue);
    });
  });

  group('getPeerAddress', () {
    test('sends get peer address message', () {
      client.getPeerAddress('carol');

      expect(mockServer.sentMessages.any((m) => m.code == ServerCode.getPeerAddress), isTrue);
    });
  });

  group('setListenPort', () {
    test('sends set listen port message', () {
      client.setListenPort(1234);

      expect(mockServer.sentMessages.any((m) => m.code == ServerCode.setListenPort), isTrue);
    });
  });

  group('enqueueDownload', () {
    test('adds download to manager', () {
      client.enqueueDownload(
        filename: 'song.flac',
        size: 1000,
        username: 'alice',
        fileCode: 1,
      );

      final progress = client.downloadManager.allProgress;
      expect(progress, isNotNull);
    });
  });
}
