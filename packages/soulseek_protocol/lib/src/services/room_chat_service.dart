import 'dart:async';

import '../connection/server_connection.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';

class RoomChatService {
  final ServerTransport _server;
  final _roomMessagesController = StreamController<RoomMessage>.broadcast();
  final _userJoinedController = StreamController<UserJoinedRoom>.broadcast();
  final _userLeftController = StreamController<UserLeftRoom>.broadcast();
  final _roomListController = StreamController<RoomList>.broadcast();

  late final StreamSubscription _messageSub;

  RoomChatService({required ServerTransport server}) : _server = server;

  Stream<RoomMessage> get roomMessages => _roomMessagesController.stream;
  Stream<UserJoinedRoom> get userJoined => _userJoinedController.stream;
  Stream<UserLeftRoom> get userLeft => _userLeftController.stream;
  Stream<RoomList> get roomList => _roomListController.stream;

  void init() {
    _messageSub = _server.messages.listen(_onMessage);
  }

  void joinRoom(String roomName) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.joinRoom,
      JoinRoom(roomName).serialize().toBytes(),
    ));
  }

  void leaveRoom(String roomName) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.leaveRoom,
      LeaveRoom(roomName).serialize().toBytes(),
    ));
  }

  void sendMessage(String roomName, String message) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.roomMessage,
      SendRoomMessage(roomName: roomName, message: message).serialize().toBytes(),
    ));
  }

  void requestRoomList() {
    _server.sendMessage(SoulseekMessage(
      ServerCode.roomList,
      WriteBuffer().toBytes(),
    ));
  }

  void setRoomTicker(String roomName, String ticker) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.roomTickerSet,
      RoomTickerSet(roomName: roomName, ticker: ticker).serialize().toBytes(),
    ));
  }

  void removeRoomTicker(String roomName) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.roomTickerRemove,
      RoomTickerRemove(roomName).serialize().toBytes(),
    ));
  }

  void _onMessage(SoulseekMessage message) {
    try {
      switch (message.code) {
        case ServerCode.roomMessage:
          final msg = RoomMessage.parse(ReadBuffer(message.payload));
          _roomMessagesController.add(msg);
          break;
        case ServerCode.userJoinedRoom:
          final joined = UserJoinedRoom.parse(ReadBuffer(message.payload));
          _userJoinedController.add(joined);
          break;
        case ServerCode.userLeftRoom:
          final left = UserLeftRoom.parse(ReadBuffer(message.payload));
          _userLeftController.add(left);
          break;
        case ServerCode.roomList:
          final list = RoomList.parse(ReadBuffer(message.payload));
          _roomListController.add(list);
          break;
      }
    } catch (_) {
      // Skip malformed room messages
    }
  }

  void dispose() {
    _messageSub.cancel();
    _roomMessagesController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _roomListController.close();
  }
}
