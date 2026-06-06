import '../connection/server_connection.dart';

class AuthService {
  final ServerTransport _server;

  AuthService({required ServerTransport server}) : _server = server;

  Stream<ServerConnectionState> get connectionState => _server.stateChanges;
  Stream<ConnectionInfo> get connectionInfo => _server.connectionInfo;
  ServerConnectionState get state => _server.state;
  bool get authenticated => _server.authenticated;
  String? get username => _server.username;

  void init() {
    _server.init();
  }

  Future<void> connect(String username, String password) async {
    await _server.connect(username, password);
  }

  Future<void> disconnect() async {
    await _server.disconnect();
  }

  void dispose() {
    _server.dispose();
  }
}
