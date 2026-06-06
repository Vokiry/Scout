import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../connection/socket_manager.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';
import '../peer/peer_connection.dart';
import '../transfer/upload_manager.dart';

class IncomingConnection implements TransferConnection {
  final SocketManager _socketManager;
  String _username;

  IncomingConnection(this._socketManager, {String username = ''})
      : _username = username;

  @override
  String get username => _username;

  set username(String value) => _username = value;

  @override
  Stream<SoulseekMessage> get messages => _socketManager.messages;

  @override
  void sendMessage(SoulseekMessage message) => _socketManager.sendMessage(message);

  @override
  void sendRaw(int code, Uint8List payload) => _socketManager.sendRaw(code, payload);

  void dispose() => _socketManager.dispose();
}

class PeerListener {
  ServerSocket? _serverSocket;
  final List<IncomingConnection> _connections = [];
  StreamSubscription? _acceptSub;

  final UploadManager uploadManager;

  PeerListener({required this.uploadManager});

  Future<void> start(int port) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _acceptSub = _serverSocket!.listen(_onConnection);
  }

  int get port => _serverSocket?.port ?? 0;
  bool get isListening => _serverSocket != null;
  int get connectionCount => _connections.length;

  void _onConnection(Socket socket) {
    final socketManager = SocketManager();
    socketManager.accept(socket);
    final connection = IncomingConnection(socketManager);
    _connections.add(connection);

    socketManager.messages.listen((message) {
      if (message.code == PeerCode.transferRequest) {
        _handleTransferRequest(message, connection);
      }
    });
  }

  void _handleTransferRequest(SoulseekMessage message, IncomingConnection connection) {
    try {
      final buffer = ReadBuffer(message.payload);
      final direction = buffer.readInt32();
      final fileCode = buffer.readInt32();
      final filename = buffer.readString();
      final fileSize = buffer.readInt32();

      final request = TransferRequest(
        direction: direction,
        fileCode: fileCode,
        filename: filename,
        fileSize: fileSize,
      );

      uploadManager.handleTransferRequest(
        request,
        connection,
      );
    } catch (_) {
      // Skip malformed transfer requests
    }
  }

  Future<void> stop() async {
    await _acceptSub?.cancel();
    _acceptSub = null;
    await _serverSocket?.close();
    _serverSocket = null;
    for (final conn in _connections) {
      conn.dispose();
    }
    _connections.clear();
  }

  void dispose() {
    stop();
  }
}
