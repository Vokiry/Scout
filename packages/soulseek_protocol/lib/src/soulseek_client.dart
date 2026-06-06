import 'dart:async';

import 'connection/server_connection.dart';
import 'connection/socket_manager.dart';
import 'messages/buffer.dart';
import 'messages/codes.dart';
import 'messages/message.dart';
import 'peer/peer_connection.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/search_service.dart';
import 'services/user_service.dart';
import 'transfer/download_manager.dart';

class SoulseekClient {
  final ServerTransport _server;
  final AuthService auth;
  final SearchService searchService;
  final ChatService chat;
  final UserService users;
  final DownloadManager _downloadManager;
  final Map<String, PeerConnection> _activePeers = {};

  SoulseekClient({
    ServerTransport? server,
    AuthService? auth,
    SearchService? searchService,
    ChatService? chat,
    UserService? users,
  }) : _server = server ?? ServerConnection(),
       auth = auth ?? AuthService(server: server ?? ServerConnection()),
       searchService = searchService ?? SearchService(server: server ?? ServerConnection()),
       chat = chat ?? ChatService(server: server ?? ServerConnection()),
       users = users ?? UserService(server: server ?? ServerConnection()),
       _downloadManager = DownloadManager();

  Stream<ServerConnectionState> get connectionState => auth.connectionState;
  Stream<SearchResult> get searchResults => searchService.results;
  Stream<PrivateMessage> get privateMessages => chat.privateMessages;
  Stream<UserStatus> get userStatus => users.userStatus;
  Stream<Map<String, DownloadProgress>> get downloadProgress => _downloadManager.allProgress;
  Stream<ConnectionInfo> get connectionInfo => auth.connectionInfo;
  bool get authenticated => auth.authenticated;
  String? get username => auth.username;
  DownloadManager get downloadManager => _downloadManager;

  void init() {
    auth.init();
    searchService.init();
    chat.init();
    users.init();
  }

  Future<void> connect(String username, String password) async {
    await auth.connect(username, password);
  }

  Future<void> disconnect() async {
    await auth.disconnect();
    for (final peer in _activePeers.values) {
      await peer.disconnect();
    }
    _activePeers.clear();
  }

  void setListenPort(int port) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.setListenPort,
      SetListenPort(port).serialize().toBytes(),
    ));
  }

  int search(String query) => searchService.search(query);

  void addUser(String username) => users.addUser(username);

  void getPeerAddress(String username) => users.getPeerAddress(username);

  void sendPrivateMessage(String username, String message) {
    chat.sendPrivateMessage(username, message);
  }

  void checkDownloadQueue(List<String> usernames) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.checkDownloadQueue,
      CheckDownloadQueue(usernames).serialize().toBytes(),
    ));
  }

  Future<PeerConnection?> connectToPeer(String username, int ip, int port) async {
    if (_activePeers.containsKey(username)) {
      await _activePeers[username]!.disconnect();
      _activePeers.remove(username);
    }

    final socketManager = SocketManager();
    final peer = PeerConnection(
      username: username,
      ip: ip,
      port: port,
      type: PeerConnectionType.outgoing,
      socketManager: socketManager,
    );

    await peer.connect();
    _activePeers[username] = peer;
    return peer;
  }

  void enqueueDownload({
    required String filename,
    required int size,
    required String username,
    required int fileCode,
    String? localPath,
  }) {
    _downloadManager.addDownload(
      filename: filename,
      size: size,
      username: username,
      fileCode: fileCode,
      localPath: localPath,
    );
  }

  Future<void> requestDownload({
    required String filename,
    required int size,
    required String username,
    required int fileCode,
    required PeerConnection connection,
  }) async {
    final download = _downloadManager.addDownload(
      filename: filename,
      size: size,
      username: username,
      fileCode: fileCode,
    );

    await _downloadManager.startDownload(download, connection);
  }

  void dispose() {
    searchService.dispose();
    chat.dispose();
    users.dispose();
    auth.dispose();
    _downloadManager.dispose();
    for (final peer in _activePeers.values) {
      peer.dispose();
    }
    _activePeers.clear();
  }
}
