import 'dart:async';
import 'dart:typed_data';

import '../connection/socket_manager.dart';
import '../messages/buffer.dart';

enum PeerConnectionState { disconnected, connecting, connected, obfuscating }

enum PeerConnectionType { incoming, outgoing }

abstract class TransferConnection {
  String get username;
  Stream<SoulseekMessage> get messages;
  void sendMessage(SoulseekMessage message);
  void sendRaw(int code, Uint8List payload);
}

class PeerConnection implements TransferConnection {
  final String username;
  final int ip;
  final int port;
  final PeerConnectionType type;
  final SocketManager _socketManager;

  PeerConnectionState _state = PeerConnectionState.disconnected;
  StreamSubscription? _subscription;

  final _stateController = StreamController<PeerConnectionState>.broadcast();
  final _messagesController = StreamController<SoulseekMessage>.broadcast();

  PeerConnection({
    required this.username,
    required this.ip,
    required this.port,
    required this.type,
    required this._socketManager,
  });

  PeerConnectionState get state => _state;
  Stream<PeerConnectionState> get stateChanges => _stateController.stream;
  Stream<SoulseekMessage> get messages => _messagesController.stream;

  String _intToIp(int value) {
    return '${(value >> 24) & 0xFF}.${(value >> 16) & 0xFF}.${(value >> 8) & 0xFF}.${value & 0xFF}';
  }

  Future<void> connect() async {
    _setState(PeerConnectionState.connecting);
    try {
      await _socketManager.connect(
        _intToIp(ip),
        port,
      );
      _setState(PeerConnectionState.connected);
      _subscription = _socketManager.messages.listen(_onMessage);
    } catch (e) {
      _setState(PeerConnectionState.disconnected);
    }
  }

  void _onMessage(SoulseekMessage message) {
    _messagesController.add(message);
  }

  void sendMessage(SoulseekMessage message) {
    _socketManager.sendMessage(message);
  }

  void sendRaw(int code, Uint8List payload) {
    _socketManager.sendRaw(code, payload);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _socketManager.disconnect();
    _setState(PeerConnectionState.disconnected);
  }

  void _setState(PeerConnectionState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }

  void dispose() {
    _subscription?.cancel();
    _socketManager.dispose();
    _stateController.close();
    _messagesController.close();
  }
}
