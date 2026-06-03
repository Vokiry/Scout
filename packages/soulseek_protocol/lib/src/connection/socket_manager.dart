import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../messages/buffer.dart';

enum SocketState { disconnected, connecting, connected }

enum SocketErrorType {
  none,
  connectionRefused,
  dnsFailure,
  timeout,
  tlsError,
  networkUnreachable,
  connectionReset,
  unknown,
}

class SocketStateChanged {
  final SocketState state;
  final SocketErrorType errorType;
  final String? errorMessage;

  SocketStateChanged({
    required this.state,
    this.errorType = SocketErrorType.none,
    this.errorMessage,
  });
}

class MessageReceived {
  final SoulseekMessage message;
  MessageReceived(this.message);
}

class SocketManager {
  Socket? _socket;
  SocketState _state = SocketState.disconnected;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _doneSubscription;

  final _messageController = StreamController<SoulseekMessage>.broadcast();
  final _stateController = StreamController<SocketStateChanged>.broadcast();

  final List<int> _buffer = [];
  static const int _headerSize = 8;
  Timer? _connectTimeout;

  SocketState get state => _state;
  Stream<SoulseekMessage> get messages => _messageController.stream;
  Stream<SocketStateChanged> get stateChanges => _stateController.stream;

  void dispose() {
    _messageController.close();
    _stateController.close();
    _cleanup();
  }

  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == SocketState.connecting || _state == SocketState.connected) {
      await disconnect();
    }

    _setState(SocketState.connecting);

    try {
      final addresses = await _resolveHost(host);
      if (addresses.isEmpty) {
        _setState(SocketState.disconnected, SocketErrorType.dnsFailure, 'Could not resolve host: $host');
        return;
      }

      _socket = await Socket.connect(
        addresses.first,
        port,
        timeout: timeout,
      );

      _socket!.setOption(SocketOption.tcpNoDelay, true);

      _dataSubscription = _socket!.listen(
        _onData,
        onError: (error) => _onError(error, StackTrace.current),
        onDone: _onDone,
        cancelOnError: false,
      );

      _setState(SocketState.connected);
    } on SocketException catch (e) {
      _setState(SocketState.disconnected, _classifySocketError(e), e.message);
    } on TimeoutException {
      _setState(SocketState.disconnected, SocketErrorType.timeout, 'Connection timed out after $timeout');
    } catch (e) {
      _setState(SocketState.disconnected, SocketErrorType.unknown, e.toString());
    }
  }

  Future<List<InternetAddress>> _resolveHost(String host) async {
    try {
      final results = await InternetAddress.lookup(host, type: InternetAddressType.any);
      // Filter IPv4 first, fall back to IPv6
      final ipv4 = results.where((a) => a.type == InternetAddressType.IPv4).toList();
      final ipv6 = results.where((a) => a.type == InternetAddressType.IPv6).toList();

      if (ipv4.isNotEmpty) return ipv4;
      if (ipv6.isNotEmpty) return ipv6;
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> disconnect() async {
    _connectTimeout?.cancel();
    _connectTimeout = null;
    _buffer.clear();
    await _dataSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _doneSubscription?.cancel();
    _dataSubscription = null;
    _errorSubscription = null;
    _doneSubscription = null;
    await _socket?.close();
    _socket = null;
    _setState(SocketState.disconnected);
  }

  void sendMessage(SoulseekMessage message) {
    sendRaw(message.code, message.payload);
  }

  void sendRaw(int code, Uint8List payload) {
    if (_socket == null || _state != SocketState.connected) {
      throw SocketManagerException('Not connected');
    }
    final data = SoulseekMessage.encode(code, payload);
    _socket!.add(data);
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    _tryParseMessages();
  }

  void _tryParseMessages() {
    while (true) {
      if (_buffer.length < _headerSize) break;

      final lengthBytes = Uint8List.sublistView(Uint8List.fromList(_buffer.sublist(0, 4)));
      final totalLength = ByteData.view(lengthBytes.buffer).getUint32(0, Endian.little);

      final frameSize = 4 + totalLength; // length field + message
      if (_buffer.length < frameSize) break;

      final frame = Uint8List.fromList(_buffer.sublist(0, frameSize));
      _buffer.removeRange(0, frameSize);

      try {
        final message = SoulseekMessage.parse(frame);
        _messageController.add(message);
      } catch (e) {
        // Skip malformed frames
        continue;
      }
    }
  }

  void _onError(Object error, StackTrace stack) {
    _setState(SocketState.disconnected, SocketErrorType.connectionReset, error.toString());
  }

  void _onDone() {
    _setState(SocketState.disconnected, SocketErrorType.connectionReset, 'Connection closed');
    _cleanup();
  }

  void _cleanup() {
    _buffer.clear();
    _dataSubscription?.cancel();
    _errorSubscription?.cancel();
    _doneSubscription?.cancel();
    _dataSubscription = null;
    _errorSubscription = null;
    _doneSubscription = null;
    _socket = null;
  }

  void _setState(SocketState state, [SocketErrorType errorType = SocketErrorType.none, String? message]) {
    if (_state == state) return;
    _state = state;
    _stateController.add(SocketStateChanged(state: state, errorType: errorType, errorMessage: message));
  }

  SocketErrorType _classifySocketError(SocketException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('refused') || msg.contains('111')) return SocketErrorType.connectionRefused;
    if (msg.contains('timeout') || msg.contains('110')) return SocketErrorType.timeout;
    if (msg.contains('unreachable') || msg.contains('101') || msg.contains('network')) {
      return SocketErrorType.networkUnreachable;
    }
    if (msg.contains('reset') || msg.contains('104')) return SocketErrorType.connectionReset;
    if (msg.contains('tls') || msg.contains('ssl')) return SocketErrorType.tlsError;
    return SocketErrorType.unknown;
  }
}

class SocketManagerException implements Exception {
  final String message;
  SocketManagerException(this.message);

  @override
  String toString() => 'SocketManagerException: $message';
}
