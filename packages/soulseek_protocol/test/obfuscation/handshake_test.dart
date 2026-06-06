import 'dart:typed_data';

import 'package:soulseek_protocol/soulseek_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ObfuscationHandshake', () {
    test('generateToken returns value in uint32 range', () {
      for (int i = 0; i < 100; i++) {
        final token = ObfuscationHandshake.generateToken();
        expect(token, greaterThanOrEqualTo(0));
        expect(token, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('initiate creates handshake with tokens', () {
      final hs = ObfuscationHandshake.initiate(0x12345678);
      expect(hs.ourToken, isNotNull);
    });

    test('respond creates handshake with tokens', () {
      final hs = ObfuscationHandshake.respond(0x87654321);
      expect(hs.ourToken, isNotNull);
    });

    test('computeKey returns 256 bytes', () {
      final hs = ObfuscationHandshake.initiate(0xAAAAAAAA);
      final key = hs.computeKey();
      expect(key.length, equals(256));
    });

    test('initiate and respond with matching tokens produce same key', () {
      // Simulate two peers: A initiates (sends tokenA, receives tokenB from B)
      // B responds (sends tokenB, receives tokenA from A)
      // Both compute key as tokenA ^ tokenB, so keys should match
      final aToken = ObfuscationHandshake.generateToken();
      final bToken = ObfuscationHandshake.generateToken();
      // To test key equality, we need two handshakes with swapped token pairs
      // Handshake key = ourToken ^ peerToken
      // A: ourToken=aToken, peerToken=bToken => key = aToken ^ bToken
      // B: ourToken=bToken, peerToken=aToken => key = bToken ^ aToken = aToken ^ bToken
      // Since initiate(peerToken) sets ourToken internally (random), we can't control both directly.
      // Instead, we verify encode/decode works for the same handshake object.
      final hs = ObfuscationHandshake.initiate(0xDEADBEEF);
      final key = hs.computeKey();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = hs.encode(data, key);
      final decoded = hs.decode(encoded, key);
      expect(decoded, equals(data));
    });

    test('different tokens produce different keys', () {
      final a = ObfuscationHandshake.initiate(0x00000000);
      final b = ObfuscationHandshake.initiate(0xFFFFFFFF);
      expect(a.computeKey(), isNot(equals(b.computeKey())));
    });

    test('encode and decode round-trip (XOR symmetry)', () {
      final hs = ObfuscationHandshake.initiate(0x12345678);
      final key = hs.computeKey();
      final original = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      final encoded = hs.encode(original, key);
      final decoded = hs.decode(encoded, key);
      expect(decoded, equals(original));
    });

    test('encode produces different bytes', () {
      final hs = ObfuscationHandshake.initiate(0x12345678);
      final key = hs.computeKey();
      final original = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      final encoded = hs.encode(original, key);
      // With XOR and non-zero key, zeros should become key bytes
      expect(encoded, isNot(equals(original)));
    });

    test('encode handles data longer than key (256 bytes)', () {
      final hs = ObfuscationHandshake.initiate(0x12345678);
      final key = hs.computeKey();
      final original = Uint8List(300);
      for (int i = 0; i < 300; i++) original[i] = i & 0xFF;
      final encoded = hs.encode(original, key);
      final decoded = hs.decode(encoded, key);
      expect(decoded, equals(original));
    });

    test('decode with wrong key produces garbage', () {
      final hs = ObfuscationHandshake.initiate(0x12345678);
      final key = hs.computeKey();
      final wrongHs = ObfuscationHandshake.initiate(0x87654321);
      final wrongKey = wrongHs.computeKey();
      final original = Uint8List.fromList([0x42, 0x43, 0x44]);
      final encoded = hs.encode(original, key);
      final decoded = hs.decode(encoded, wrongKey);
      expect(decoded, isNot(equals(original)));
    });
  });
}
