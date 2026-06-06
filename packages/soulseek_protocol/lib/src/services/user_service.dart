import 'dart:async';

import '../connection/server_connection.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';

class UserService {
  final ServerTransport _server;
  final _userStatusController = StreamController<UserStatus>.broadcast();

  late final StreamSubscription _messageSub;

  UserService({required ServerTransport server}) : _server = server;

  Stream<UserStatus> get userStatus => _userStatusController.stream;

  void init() {
    _messageSub = _server.messages.listen(_onMessage);
  }

  void addUser(String username) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.addUser,
      AddUser(username).serialize().toBytes(),
    ));
  }

  void getPeerAddress(String username) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.getPeerAddress,
      GetPeerAddress(username).serialize().toBytes(),
    ));
  }

  void _onMessage(SoulseekMessage message) {
    switch (message.code) {
      case ServerCode.statusResponse:
        _handleStatusResponse(message);
        break;
    }
  }

  void _handleStatusResponse(SoulseekMessage message) {
    try {
      final buffer = ReadBuffer(message.payload);
      final status = UserStatus.parse(buffer);
      _userStatusController.add(status);
    } catch (_) {
      // Skip malformed status
    }
  }

  void dispose() {
    _messageSub.cancel();
    _userStatusController.close();
  }
}
