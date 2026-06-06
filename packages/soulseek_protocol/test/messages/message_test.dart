import 'dart:convert';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('LoginRequest', () {
    test('serializes with defaults', () {
      final msg = LoginRequest(username: 'alice', password: 'secret');
      final buf = msg.serialize();
      final bytes = buf.toBytes();
      final r = ReadBuffer(Uint8List.fromList(bytes));
      expect(r.readString(), equals('alice'));
      expect(r.readString(), equals('secret'));
      expect(r.readInt32(), equals(17)); // minorVersion
      expect(r.readInt32(), equals(1));  // majorVersion
      expect(r.readInt32(), equals(0));  // buildVersion
    });

    test('code is 1', () {
      expect(LoginRequest(username: 'a', password: 'b').code, equals(1));
    });
  });

  group('LoginResponse', () {
    test('parses successful login', () {
      final w = WriteBuffer();
      w.writeInt32(1); // success
      w.writeInt32(0x7F000001); // ip 127.0.0.1
      w.writeInt32(2244); // port
      w.writeInt32(1); // obfuscated
      final r = ReadBuffer(w.toBytes());
      final resp = LoginResponse.parse(r);
      expect(resp.success, isTrue);
      expect(resp.ip, equals(0x7F000001));
      expect(resp.port, equals(2244));
      expect(resp.obfuscated, isTrue);
    });

    test('parses failed login without obfuscated flag', () {
      final w = WriteBuffer();
      w.writeInt32(0); // fail
      w.writeInt32(0);
      w.writeInt32(0);
      final r = ReadBuffer(w.toBytes());
      final resp = LoginResponse.parse(r);
      expect(resp.success, isFalse);
      expect(resp.obfuscated, isFalse);
    });
  });

  group('SetListenPort', () {
    test('serializes port', () {
      final msg = SetListenPort(1234);
      expect(msg.code, equals(2));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readInt32(), equals(1234));
    });
  });

  group('GetPeerAddress', () {
    test('serializes username', () {
      final msg = GetPeerAddress('bob');
      expect(msg.code, equals(3));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readString(), equals('bob'));
    });
  });

  group('PeerAddressResponse', () {
    test('parses', () {
      final w = WriteBuffer();
      w.writeString('bob');
      w.writeInt32(0x0A000001); // 10.0.0.1
      w.writeInt32(2234);
      final r = ReadBuffer(w.toBytes());
      final resp = PeerAddressResponse.parse(r);
      expect(resp.username, equals('bob'));
      expect(resp.ip, equals(0x0A000001));
      expect(resp.port, equals(2234));
    });
  });

  group('AddUser', () {
    test('serializes', () {
      final msg = AddUser('carol');
      expect(msg.code, equals(5));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readString(), equals('carol'));
    });
  });

  group('AddUserResponse', () {
    test('parses existing user', () {
      final w = WriteBuffer();
      w.writeString('carol');
      w.writeInt32(1); // exists
      w.writeInt32(2); // status = away
      final r = ReadBuffer(w.toBytes());
      final resp = AddUserResponse.parse(r);
      expect(resp.username, equals('carol'));
      expect(resp.exists, isTrue);
      expect(resp.status, equals(2));
    });
  });

  group('UserStatus', () {
    test('parses', () {
      final w = WriteBuffer();
      w.writeString('dave');
      w.writeInt32(1); // online
      final r = ReadBuffer(w.toBytes());
      final status = UserStatus.parse(r);
      expect(status.username, equals('dave'));
      expect(status.status, equals(1));
    });
  });

  group('SearchRequest', () {
    test('serializes ticket and query', () {
      final msg = SearchRequest(query: 'flac daft punk', ticket: 42);
      expect(msg.code, equals(26));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readInt32(), equals(42));
      expect(r.readString(), equals('flac daft punk'));
    });
  });

  group('SearchResponseData', () {
    SearchResultFile _makeFile({int code = 0, String name = 'file.flac', int size = 1000, String ext = 'flac'}) {
      return SearchResultFile(
        code: code,
        filename: name,
        size: size,
        extension: ext,
        attributeCount: 3,
        bitrate: 320,
        duration: 300,
        sampleRate: 44100,
      );
    }

    test('parse modern format with attributes', () {
      final w = WriteBuffer();
      w.writeString('eve');
      w.writeInt32(1); // ticket
      w.writeInt32(10); // totalFileCount
      w.writeInt32(3); // freeUploadSlots
      w.writeInt32(1000000); // uploadSpeed
      w.writeInt32(0); // queueLength
      w.writeInt32(1); // fileCount

      // one file
      w.writeInt32(0); // code
      w.writeString('song.flac');
      w.writeInt32(5000); // size
      w.writeString('flac');
      w.writeInt32(3); // attributeCount
      w.writeInt32(0); w.writeInt32(320); // bitrate
      w.writeInt32(1); w.writeInt32(240); // duration
      w.writeInt32(2); w.writeInt32(44100); // sampleRate

      final r = ReadBuffer(w.toBytes());
      final resp = SearchResponseData.parse(r);
      expect(resp.username, equals('eve'));
      expect(resp.ticket, equals(1));
      expect(resp.totalFileCount, equals(10));
      expect(resp.freeUploadSlots, equals(3));
      expect(resp.uploadSpeed, equals(1000000));
      expect(resp.queueLength, equals(0));
      expect(resp.files.length, equals(1));
      expect(resp.files[0].filename, equals('song.flac'));
      expect(resp.files[0].bitrate, equals(320));
      expect(resp.files[0].duration, equals(240));
      expect(resp.files[0].sampleRate, equals(44100));
    });

    test('parse old format without free slots / speed / queue', () {
      final w = WriteBuffer();
      w.writeString('frank');
      w.writeInt32(2); // ticket
      w.writeInt32(1); // fileCount

      w.writeInt32(1); // code
      w.writeString('track.mp3');
      w.writeInt32(3000); // size
      w.writeString('mp3');
      w.writeInt32(3);
      w.writeInt32(0); w.writeInt32(256); // bitrate
      w.writeInt32(1); w.writeInt32(180); // duration
      w.writeInt32(2); w.writeInt32(44100); // sampleRate

      final r = ReadBuffer(w.toBytes());
      final resp = SearchResponseData.parseOld(r);
      expect(resp.username, equals('frank'));
      expect(resp.freeUploadSlots, equals(0));
      expect(resp.uploadSpeed, equals(0));
      expect(resp.queueLength, equals(0));
      expect(resp.files.length, equals(1));
    });

    test('parse fallback: new parse fails, old succeeds', () {
      // Write modern format but corrupt attribute count to force parse error
      final w = WriteBuffer();
      w.writeString('grace');
      w.writeInt32(3);
      w.writeInt32(5);
      w.writeInt32(1);
      w.writeInt32(1000);
      w.writeInt32(0);
      w.writeInt32(1);

      w.writeInt32(0);
      w.writeString('a.flac');
      w.writeInt32(100);
      w.writeString('flac');
      w.writeInt32(999); // impossibly high attribute count -> will fail

      final bytes = w.toBytes();
      // modern parse should throw
      expect(() => SearchResponseData.parse(ReadBuffer(Uint8List.fromList(bytes))),
          throwsA(isA<BufferException>()));
    });
  });

  group('SearchResultFile', () {
    test('parse old format without bitrateVbr', () {
      final w = WriteBuffer();
      w.writeInt32(0);
      w.writeString('test.flac');
      w.writeInt32(1000);
      w.writeString('flac');
      w.writeInt32(3);
      w.writeInt32(0); w.writeInt32(320);
      w.writeInt32(1); w.writeInt32(300);
      w.writeInt32(2); w.writeInt32(48000);

      final r = ReadBuffer(w.toBytes());
      final file = SearchResultFile.parse(r);
      expect(file.bitrate, equals(320));
      expect(file.duration, equals(300));
      expect(file.sampleRate, equals(48000));
      expect(file.bitrateVbr, isNull);
    });

    test('parse modern format with bitrateVbr', () {
      final w = WriteBuffer();
      w.writeInt32(0);
      w.writeString('test.flac');
      w.writeInt32(1000);
      w.writeString('flac');
      w.writeInt32(4);
      w.writeInt32(0); w.writeInt32(320);
      w.writeInt32(1); w.writeInt32(300);
      w.writeInt32(2); w.writeInt32(48000);
      w.writeInt32(3); w.writeInt32(1); // bitrateVbr

      final r = ReadBuffer(w.toBytes());
      final file = SearchResultFile.parse(r);
      expect(file.bitrateVbr, equals(1));
    });

    test('parseOld without bitrateVbr', () {
      final w = WriteBuffer();
      w.writeInt32(0);
      w.writeString('old.mp3');
      w.writeInt32(500);
      w.writeString('mp3');
      w.writeInt32(3);
      w.writeInt32(0); w.writeInt32(128);
      w.writeInt32(1); w.writeInt32(120);
      w.writeInt32(2); w.writeInt32(22050);

      final r = ReadBuffer(w.toBytes());
      final file = SearchResultFile.parseOld(r);
      expect(file.bitrate, equals(128));
      expect(file.duration, equals(120));
    });
  });

  group('PrivateMessage', () {
    test('serialize', () {
      final msg = PrivateMessage(username: 'bob', message: 'hello', timestamp: 1000);
      expect(msg.code, equals(51));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readString(), equals('bob'));
      expect(r.readString(), equals('hello'));
    });

    test('parse', () {
      final w = WriteBuffer();
      w.writeString('alice');
      w.writeString('hi');
      w.writeInt32(12345);
      final r = ReadBuffer(w.toBytes());
      final pm = PrivateMessage.parse(r);
      expect(pm.username, equals('alice'));
      expect(pm.message, equals('hi'));
      expect(pm.timestamp, equals(12345));
    });
  });

  group('Ping', () {
    test('code is 40', () {
      expect(Ping().code, equals(40));
    });

    test('serializes empty', () {
      expect(Ping().serialize().toBytes(), isEmpty);
    });
  });

  group('CheckDownloadQueue', () {
    test('serializes usernames', () {
      final msg = CheckDownloadQueue(['a', 'b']);
      expect(msg.code, equals(58));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readInt32(), equals(2)); // count
      expect(r.readString(), equals('a'));
      expect(r.readString(), equals('b'));
    });
  });

  group('FolderContentsRequest', () {
    test('serializes directory', () {
      final msg = FolderContentsRequest('/music');
      expect(msg.code, equals(131));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readString(), equals('/music'));
    });
  });

  group('UserInfoRequest', () {
    test('code is 133', () {
      expect(UserInfoRequest().code, equals(133));
    });

    test('serializes empty', () {
      expect(UserInfoRequest().serialize().toBytes(), isEmpty);
    });
  });

  group('TransferRequest', () {
    test('serializes all fields', () {
      final msg = TransferRequest(
        direction: 0,
        fileCode: 99,
        filename: 'song.flac',
        fileSize: 10000,
      );
      expect(msg.code, equals(135));
      final r = ReadBuffer(msg.serialize().toBytes());
      expect(r.readInt32(), equals(0)); // direction
      expect(r.readInt32(), equals(99)); // fileCode
      expect(r.readString(), equals('song.flac'));
      expect(r.readInt32(), equals(10000)); // fileSize
    });
  });
}
