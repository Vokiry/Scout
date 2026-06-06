import 'dart:async';

import 'connection/server_connection.dart';
import 'connection/socket_manager.dart';
import 'messages/buffer.dart';
import 'messages/codes.dart';
import 'messages/message.dart';
import 'peer/peer_connection.dart';
import 'transfer/download_manager.dart';

/// High-level Soulseek client.
///
/// Provides a clean API for authentication, searching, downloading,
/// and managing peer connections. Runs protocol operations on a
/// dedicated isolate to prevent UI jank.
class SoulseekClient {
  final ServerTransport _server;
  final DownloadManager _downloadManager;
  final Map<String, PeerConnection> _activePeers = {};
  int _searchTicket = 1;

  StreamSubscription? _serverMessageSub;

  final _searchResultsController = StreamController<SearchResult>.broadcast();
  final _privateMessageController = StreamController<PrivateMessage>.broadcast();
  final _userStatusController = StreamController<UserStatus>.broadcast();

  SoulseekClient({ServerTransport? server})
      : _server = server ?? ServerConnection(),
        _downloadManager = DownloadManager();

  // --- Streams ---
  Stream<ServerConnectionState> get connectionState => _server.stateChanges;
  Stream<SearchResult> get searchResults => _searchResultsController.stream;
  Stream<PrivateMessage> get privateMessages => _privateMessageController.stream;
  Stream<UserStatus> get userStatus => _userStatusController.stream;
  Stream<Map<String, DownloadProgress>> get downloadProgress => _downloadManager.allProgress;
  Stream<ConnectionInfo> get connectionInfo => _server.connectionInfo;
  bool get authenticated => _server.authenticated;
  String? get username => _server.username;
  DownloadManager get downloadManager => _downloadManager;

  // --- Lifecycle ---
  void init() {
    _server.init();
    _serverMessageSub = _server.messages.listen(_onServerMessage);
  }

  Future<void> connect(String username, String password) async {
    await _server.connect(username, password);
  }

  Future<void> disconnect() async {
    await _server.disconnect();
    for (final peer in _activePeers.values) {
      await peer.disconnect();
    }
    _activePeers.clear();
  }

  // --- Server Interaction ---
  void setListenPort(int port) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.setListenPort,
      SetListenPort(port).serialize().toBytes(),
    ));
  }

  void search(String query) {
    final ticket = _searchTicket++;
    _server.sendMessage(SoulseekMessage(
      ServerCode.searchRequest,
      SearchRequest(query: query, ticket: ticket).serialize().toBytes(),
    ));
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

  void checkDownloadQueue(List<String> usernames) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.checkDownloadQueue,
      CheckDownloadQueue(usernames).serialize().toBytes(),
    ));
  }

  // --- Peer Connection ---
  Future<PeerConnection?> connectToPeer(String username, int ip, int port) async {
    if (_activePeers.containsKey(username)) {
      _activePeers[username]!.disconnect();
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

  // --- Downloads ---
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

  // --- Message Handlers ---
  void _onServerMessage(SoulseekMessage message) {
    switch (message.code) {
      case ServerCode.searchResponse:
      case ServerCode.userSearchResponse:
        _handleSearchResponse(message);
        break;
      case ServerCode.privateMessage:
        _handlePrivateMessage(message);
        break;
      case ServerCode.statusResponse:
        _handleStatusResponse(message);
        break;
      case ServerCode.roomMessage:
      case ServerCode.userJoinedRoom:
      case ServerCode.userLeftRoom:
        // Room events - handled by higher layer
        break;
    }
  }

  void _handleSearchResponse(SoulseekMessage message) {
    try {
      final buffer = ReadBuffer(message.payload);
      SearchResponseData response;
      try {
        response = SearchResponseData.parse(buffer);
      } catch (_) {
        // Fall back to old format
        response = SearchResponseData.parseOld(ReadBuffer(message.payload));
      }

      _searchResultsController.add(SearchResult(
        username: response.username,
        ticket: response.ticket,
        freeUploadSlots: response.freeUploadSlots,
        uploadSpeed: response.uploadSpeed,
        queueLength: response.queueLength,
        files: response.files,
      ));
    } catch (e) {
      // Skip malformed search responses
    }
  }

  void _handlePrivateMessage(SoulseekMessage message) {
    try {
      final buffer = ReadBuffer(message.payload);
      final pm = PrivateMessage.parse(buffer);
      _privateMessageController.add(pm);
    } catch (e) {
      // Skip malformed messages
    }
  }

  void _handleStatusResponse(SoulseekMessage message) {
    try {
      final buffer = ReadBuffer(message.payload);
      final status = UserStatus.parse(buffer);
      _userStatusController.add(status);
    } catch (e) {
      // Skip malformed status
    }
  }

  void dispose() {
    _serverMessageSub?.cancel();
    _server.dispose();
    _downloadManager.dispose();
    _searchResultsController.close();
    _privateMessageController.close();
    _userStatusController.close();
    for (final peer in _activePeers.values) {
      peer.dispose();
    }
    _activePeers.clear();
  }
}

class SearchResult {
  final String username;
  final int ticket;
  final int freeUploadSlots;
  final int uploadSpeed;
  final int queueLength;
  final List<SearchResultFile> files;

  const SearchResult({
    required this.username,
    required this.ticket,
    required this.freeUploadSlots,
    required this.uploadSpeed,
    required this.queueLength,
    required this.files,
  });
}
