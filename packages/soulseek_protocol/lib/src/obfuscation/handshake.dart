import 'dart:math';
import 'dart:typed_data';

/// Soulseek obfuscation handshake implementation.
///
/// The obfuscated handshake uses XOR with a Pi digit shuffle.
/// Steps:
/// 1. Both sides exchange 4-byte random tokens.
/// 2. Each side computes a shared obfuscation key using their token
///    and the peer's token, combined with Pi digits.
/// 3. Subsequent messages are XOR-obfuscated using this key.
class ObfuscationHandshake {
  static final Uint8List _piDigits = _generatePiDigits(1024);

  final int _ourToken;
  final int _peerToken;

  ObfuscationHandshake._(this._ourToken, this._peerToken);

  int get ourToken => _ourToken;

  /// Generate a random 4-byte token for the initial exchange.
  static int generateToken() {
    final random = Random.secure();
    return random.nextInt(0xFFFFFFFF);
  }

  /// Create a responder (server-side) handshake.
  static ObfuscationHandshake respond(int peerToken) {
    final ourToken = generateToken();
    return ObfuscationHandshake._(ourToken, peerToken);
  }

  /// Create an initiator (client-side) handshake.
  static ObfuscationHandshake initiate(int peerToken) {
    final ourToken = generateToken();
    return ObfuscationHandshake._(ourToken, peerToken);
  }

  /// Compute the obfuscation key.
  /// Uses the XOR of both tokens combined with Pi digits.
  Uint8List computeKey() {
    final combined = _ourToken ^ _peerToken;
    final key = ByteData(256);

    for (int i = 0; i < 256; i++) {
      final piIndex = (combined + i) % _piDigits.length;
      key.setUint8(i, _piDigits[piIndex] ^ (combined >> (i % 4) * 8 & 0xFF));
    }

    return key.buffer.asUint8List();
  }

  /// Encode a message using the obfuscation key.
  Uint8List encode(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Decode a message (same as encode for XOR).
  Uint8List decode(Uint8List data, Uint8List key) => encode(data, key);

  /// Generate Pi digits for the obfuscation shuffle.
  static Uint8List _generatePiDigits(int count) {
    // Generate Pi using Machin-like formula for approximation
    // Simplified: use pre-computed Pi digits
    const piHex = '243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89'
        '452821E638D01377BE5466CF34E90C6CC0AC29B7C97C50DD3F84D5B5B5470917'
        '9216D5D98979FB1BD1310BA698DFB5AC2FFD72DBD01ADFB7B8E1AFED6A267E96'
        'BA7C9045F12C7F9924A19947B3916CF70801F2E2858EFC16636920D871574E69';

    final digits = Uint8List(count);
    for (int i = 0; i < count && i < piHex.length ~/ 2; i++) {
      digits[i] = int.parse(piHex.substring(i * 2, (i + 1) * 2), radix: 16);
    }
    return digits;
  }
}
