import 'dart:convert';
import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('WriteBuffer', () {
    test('writeUint8', () {
      final w = WriteBuffer();
      w.writeUint8(0xAB);
      expect(w.toBytes(), equals([0xAB]));
    });

    test('writeUint16 little-endian', () {
      final w = WriteBuffer();
      w.writeUint16(0x1234);
      expect(w.toBytes(), equals([0x34, 0x12]));
    });

    test('writeUint32 little-endian', () {
      final w = WriteBuffer();
      w.writeUint32(0xDEADBEEF);
      expect(w.toBytes(), equals([0xEF, 0xBE, 0xAD, 0xDE]));
    });

    test('writeUint64 little-endian', () {
      final w = WriteBuffer();
      w.writeUint64(BigInt.from(0x0102030405060708));
      expect(w.toBytes(), equals([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]));
    });

    test('writeInt32 little-endian negative', () {
      final w = WriteBuffer();
      w.writeInt32(-1);
      expect(w.toBytes(), equals([0xFF, 0xFF, 0xFF, 0xFF]));
    });

    test('writeString with length prefix', () {
      final w = WriteBuffer();
      w.writeString('abc');
      final bytes = w.toBytes();
      expect(bytes.length, equals(7));
      expect(bytes[0], equals(3)); // length = 3
      expect(bytes[1], equals(0));
      expect(bytes[2], equals(0));
      expect(bytes[3], equals(0));
      expect(utf8.decode(bytes.sublist(4)), equals('abc'));
    });

    test('writeString empty', () {
      final w = WriteBuffer();
      w.writeString('');
      final bytes = w.toBytes();
      expect(bytes, equals([0, 0, 0, 0]));
    });

    test('writeBytes', () {
      final w = WriteBuffer();
      w.writeBytes(Uint8List.fromList([1, 2, 3]));
      expect(w.toBytes(), equals([1, 2, 3]));
    });

    test('writeInt32Le alias', () {
      final w = WriteBuffer();
      w.writeInt32Le(0x12345678);
      expect(w.toBytes(), equals([0x78, 0x56, 0x34, 0x12]));
    });

    test('chained writes', () {
      final w = WriteBuffer();
      w.writeUint8(1);
      w.writeUint16(0x0203);
      w.writeUint32(0x04050607);
      expect(w.toBytes(), equals([1, 0x03, 0x02, 0x07, 0x06, 0x05, 0x04]));
    });
  });

  group('ReadBuffer', () {
    test('readUint8', () {
      final r = ReadBuffer(Uint8List.fromList([0x42]));
      expect(r.readUint8(), equals(0x42));
      expect(r.isEof, isTrue);
    });

    test('readUint16 little-endian', () {
      final r = ReadBuffer(Uint8List.fromList([0x34, 0x12]));
      expect(r.readUint16(), equals(0x1234));
    });

    test('readUint32 little-endian', () {
      final r = ReadBuffer(Uint8List.fromList([0xEF, 0xBE, 0xAD, 0xDE]));
      expect(r.readUint32(), equals(0xDEADBEEF));
    });

    test('readUint64 little-endian', () {
      final r = ReadBuffer(Uint8List.fromList([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]));
      expect(r.readUint64(), equals(0x0102030405060708));
    });

    test('readInt32 negative', () {
      final r = ReadBuffer(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
      expect(r.readInt32(), equals(-1));
    });

    test('readString', () {
      final data = [4, 0, 0, 0, 0x74, 0x65, 0x73, 0x74]; // "test"
      final r = ReadBuffer(Uint8List.fromList(data));
      expect(r.readString(), equals('test'));
    });

    test('readString empty', () {
      final r = ReadBuffer(Uint8List.fromList([0, 0, 0, 0]));
      expect(r.readString(), equals(''));
    });

    test('readBytes', () {
      final r = ReadBuffer(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(r.readBytes(3), equals([1, 2, 3]));
      expect(r.offset, equals(3));
    });

    test('readRemaining', () {
      final r = ReadBuffer(Uint8List.fromList([10, 20, 30]));
      r.readUint8(); // skip one
      expect(r.readRemaining(), equals([20, 30]));
      expect(r.isEof, isTrue);
    });

    test('offset and remaining track correctly', () {
      final r = ReadBuffer(Uint8List.fromList([1, 2, 3, 4]));
      expect(r.offset, equals(0));
      expect(r.remaining, equals(4));
      r.readUint8();
      expect(r.offset, equals(1));
      expect(r.remaining, equals(3));
    });

    group('EOF exceptions', () {
      test('readUint8 throws on empty', () {
        final r = ReadBuffer(Uint8List.fromList([]));
        expect(() => r.readUint8(), throwsA(isA<BufferException>()));
      });

      test('readUint16 throws on single byte', () {
        final r = ReadBuffer(Uint8List.fromList([1]));
        expect(() => r.readUint16(), throwsA(isA<BufferException>()));
      });

      test('readString throws on truncated', () {
        final r = ReadBuffer(Uint8List.fromList([5, 0, 0, 0, 0x68])); // says length 5 but only 1 byte
        expect(() => r.readString(), throwsA(isA<BufferException>()));
      });
    });
  });

  group('SoulseekMessage', () {
    test('encode and parse round-trip', () {
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
      final encoded = SoulseekMessage.encode(42, payload);
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(42));
      expect(parsed.payload, equals([0x01, 0x02, 0x03]));
    });

    test('encode with empty payload', () {
      final encoded = SoulseekMessage.encode(0, Uint8List(0));
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(0));
      expect(parsed.payload, isEmpty);
    });

    test('encode and parse large code', () {
      final encoded = SoulseekMessage.encode(0xFFFFFFFF, Uint8List(0));
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(0xFFFFFFFF));
    });

    test('encodeWithBuffer', () {
      final w = WriteBuffer();
      w.writeUint32(0x12345678);
      final encoded = SoulseekMessage.encodeWithBuffer(7, w);
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(7));
      expect(ReadBuffer(parsed.payload).readUint32(), equals(0x12345678));
    });

    test('parse rejects truncated data', () {
      final tooShort = Uint8List.fromList([0, 0, 0]); // need at least 8 bytes
      expect(() => SoulseekMessage.parse(tooShort), throwsA(isA<BufferException>()));
    });

    test('parse code-only message (no payload)', () {
      // length=4 (includes 4-byte code), code=0, payload empty
      final header = Uint8List.fromList([4, 0, 0, 0, 0, 0, 0, 0]);
      final parsed = SoulseekMessage.parse(header);
      expect(parsed.code, equals(0));
      expect(parsed.payload, isEmpty);
    });

    test('parse with large payload', () {
      final payload = Uint8List(65536);
      for (int i = 0; i < payload.length; i++) payload[i] = i & 0xFF;
      final encoded = SoulseekMessage.encode(42, payload);
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(42));
      expect(parsed.payload.length, equals(65536));
    });

    test('encode with max uint32 code wraps correctly', () {
      final encoded = SoulseekMessage.encode(0xFFFFFFFF, Uint8List(0));
      final parsed = SoulseekMessage.parse(encoded);
      expect(parsed.code, equals(0xFFFFFFFF));
    });
  });
}
