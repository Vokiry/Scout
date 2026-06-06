import 'dart:async';

import '../connection/server_connection.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';

class ChatService {
  final ServerTransport _server;
  final _privateMessageController = StreamController<PrivateMessage>.broadcast();

  late final StreamSubscription _messageSub;

  ChatService({required ServerTransport server}) : _server = server;

  Stream<PrivateMessage> get privateMessages => _privateMessageController.stream;

  void init() {
    _messageSub = _server.messages.listen(_onMessage);
  }

  void sendPrivateMessage(String username, String message) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.privateMessage,
      PrivateMessage(
        username: username,
        message: message,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ).serialize().toBytes(),
    ));
  }

  void _onMessage(SoulseekMessage message) {
    switch (message.code) {
      case ServerCode.privateMessage:
        _handlePrivateMessage(message);
        break;
    }
  }

  void _handlePrivateMessage(SoulseekMessage message) {
    try {
      final buffer = ReadBuffer(message.payload);
      final pm = PrivateMessage.parse(buffer);
      _privateMessageController.add(pm);
    } catch (_) {
      // Skip malformed messages
    }
  }

  void dispose() {
    _messageSub.cancel();
    _privateMessageController.close();
  }
}
