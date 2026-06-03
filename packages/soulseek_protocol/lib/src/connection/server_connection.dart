import 'dart:async';
import 'dart:typed_data';

import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';
import 'reconnection_manager.dart';
import 'socket_manager.dart';

enum ServerConnectionState { disconnected, connecting, connected, reconnecting }
class ServerConnection {
  late final SocketManager _socket;
  late final ReconnectionManager _reconnector;

  bool _authenticated = false;
  String? _username;
  String _serverHost = 'server.slsknet.org';
  int _serverPort = 2244;

  final _stateController = StreamController<ServerConnectionState>.broadcast();
  final _messageController = StreamController<SoulseekMessage>.broadcast();
  final _connectionInfoController = StreamController<ConnectionInfo>.broadcast();
  StreamSubscription? _socketStateSub;
  StreamSubscription? _socketMessageSub;
  StreamSubscription? _reconnectSub;

  ServerConnectionState _state = ServerConnectionState.disconnected;

  ServerConnection() {
    _socket = SocketManager();
    _reconnector = ReconnectionManager(_socket);
  }
  void initialize() {
    _socket = SocketManager();
    // _reconnector needs _socket, created in init
  }

  Stream<ServerConnectionState> get stateChanges => _stateController.stream;
  Stream<SoulseekMessage> get messages => _messageController.stream;
  Stream<ConnectionInfo> get connectionInfo => _connectionInfoController.stream;
  ServerConnectionState get state => _state;
  bool get authenticated => _authenticated;
  String? get username => _username;

  void init() {
    _socketStateSub = _socket.stateChanges.listen(_onSocketStateChange);
    _socketMessageSub = _socket.messages.listen(_onMessage);
    _reconnectSub = _reconnector.stateChanges.listen((_) {});
  }

  void setServer(String host, int port) {
    _serverHost = host;
    _serverPort = port;
  }

  Future<void> connect(String username, String password) async {
    _username = username;
    _setState(ServerConnectionState.connecting);
    _reconnector.start(_serverHost, _serverPort);

    await _socket.connect(_serverHost, _serverPort);
    _sendLogin(username, password);
  }

  void _sendLogin(String username, String password) {
    final login = LoginRequest(username: username, password: password, minorVersion: 17, majorVersion: 1);
    _socket.sendMessage(SoulseekMessage(login.code, login.serialize().toBytes()));
  }

  Future<void> disconnect() async {
    _reconnector.stop();
    await _socket.disconnect();
    _authenticated = false;
    _setState(ServerConnectionState.disconnected);
  }

  void sendMessage(SoulseekMessage message) {
    _socket.sendMessage(message);
  }

  void sendRaw(int code, Uint8List payload) {
    _socket.sendRaw(code, payload);
  }

  void _onSocketStateChange(SocketStateChanged event) {
    switch (event.state) {
      case SocketState.disconnected:
        _authenticated = false;
        if (_reconnector.state.isRunning) {
          _setState(ServerConnectionState.reconnecting);
        } else {
          _setState(ServerConnectionState.disconnected);
        }
        break;
      case SocketState.connecting:
        _setState(ServerConnectionState.connecting);
        break;
      case SocketState.connected:
        _setState(ServerConnectionState.connected);
        break;
    }
  }

  void _onMessage(SoulseekMessage message) {
    switch (message.code) {
      case ServerCode.loginResponse:
        _handleLoginResponse(message);
        break;
      case ServerCode.serverShuttingDown:
        _handleServerShutdown(message);
        break;
      case ServerCode.ping:
        _respondPing();
        break;
      default:
        _messageController.add(message);
        break;
    }
  }

  void _handleLoginResponse(SoulseekMessage message) {
    final buffer = ReadBuffer(message.payload);
    final response = LoginResponse.parse(buffer);
    _authenticated = response.success;
    _connectionInfoController.add(ConnectionInfo(
      authenticated: response.success,
      localIp: response.ip,
      localPort: response.port,
      obfuscated: response.obfuscated,
    ));
  }

  void _handleServerShutdown(SoulseekMessage message) {
    _connectionInfoController.add(ConnectionInfo(
      authenticated: _authenticated,
      serverShuttingDown: true,
      message: ReadBuffer(message.payload).readString(),
    ));
  }

  void _respondPing() {
    sendMessage(SoulseekMessage(ServerCode.pong, WriteBuffer().toBytes()));
  }

  void _setState(ServerConnectionState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }

  void dispose() {
    _socketStateSub?.cancel();
    _socketMessageSub?.cancel();
    _reconnectSub?.cancel();
    _reconnector.dispose();
    _socket.dispose();
    _stateController.close();
    _messageController.close();
    _connectionInfoController.close();
  }
}

class ConnectionInfo {
  final bool authenticated;
  final int? localIp;
  final int? localPort;
  final bool obfuscated;
  final bool serverShuttingDown;
  final String? message;

  const ConnectionInfo({
    this.authenticated = false,
    this.localIp,
    this.localPort,
    this.obfuscated = false,
    this.serverShuttingDown = false,
    this.message,
  });
}
