import 'dart:convert';
import 'dart:typed_data';

class ReadBuffer {
  final ByteData _data;
  int _offset = 0;

  ReadBuffer(Uint8List bytes) : _data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  int get offset => _offset;
  int get remaining => _data.lengthInBytes - _offset;
  int get length => _data.lengthInBytes;
  bool get isEof => _offset >= _data.lengthInBytes;

  int readUint8() {
    if (remaining < 1) throw BufferException('EOF while reading uint8');
    return _data.getUint8(_offset++);
  }

  int readUint16() {
    if (remaining < 2) throw BufferException('EOF while reading uint16');
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int readUint32() {
    if (remaining < 4) throw BufferException('EOF while reading uint32');
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readUint64() {
    if (remaining < 8) throw BufferException('EOF while reading uint64');
    final value = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  int readInt32() {
    if (remaining < 4) throw BufferException('EOF while reading int32');
    final value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length) {
    if (remaining < length) throw BufferException('EOF while reading bytes');
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, length);
    _offset += length;
    return bytes;
  }

  String readString() {
    final length = readUint32();
    if (length == 0) return '';
    final bytes = readBytes(length);
    return utf8.decode(bytes);
  }

  Uint8List readRemaining() {
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, remaining);
    _offset = _data.lengthInBytes;
    return bytes;
  }

  int readInt32Le() => readInt32();

  int readByte() => readUint8();
}

class WriteBuffer {
  final List<int> _bytes = [];

  void writeUint8(int value) {
    _bytes.add(value & 0xFF);
  }

  void writeUint16(int value) {
    _bytes.add(value & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
  }

  void writeUint32(int value) {
    _bytes.add(value & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add((value >> 16) & 0xFF);
    _bytes.add((value >> 24) & 0xFF);
  }

  void writeUint64(BigInt value) {
    final mask = BigInt.from(0xFF);
    for (int i = 0; i < 8; i++) {
      _bytes.add((value & mask).toInt());
      value = value >> 8;
    }
  }

  void writeInt32(int value) {
    _bytes.add(value & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add((value >> 16) & 0xFF);
    _bytes.add((value >> 24) & 0xFF);
  }

  void writeBytes(Uint8List bytes) {
    _bytes.addAll(bytes);
  }

  void writeString(String value) {
    final encoded = utf8.encode(value);
    writeUint32(encoded.length);
    _bytes.addAll(encoded);
  }

  void writeInt32Le(int value) => writeInt32(value);

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

class SoulseekMessage {
  final int code;
  final Uint8List payload;

  SoulseekMessage(this.code, this.payload);

  static SoulseekMessage parse(Uint8List data) {
    final buffer = ReadBuffer(data);
    final length = buffer.readUint32();
    final code = buffer.readUint32();
    final payload = buffer.readBytes(length - 4);
    return SoulseekMessage(code, payload);
  }

  static Uint8List encode(int code, Uint8List payload) {
    final totalLength = 4 + payload.length; // code + payload
    final buffer = WriteBuffer();
    buffer.writeUint32(totalLength);
    buffer.writeUint32(code);
    buffer.writeBytes(payload);
    return buffer.toBytes();
  }

  static Uint8List encodeWithBuffer(int code, WriteBuffer payload) {
    return encode(code, payload.toBytes());
  }
}

class BufferException implements Exception {
  final String message;
  BufferException(this.message);

  @override
  String toString() => 'BufferException: $message';
}
