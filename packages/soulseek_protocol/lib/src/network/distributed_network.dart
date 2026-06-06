import 'dart:async';

import '../connection/socket_manager.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../services/search_service.dart';

enum DistributedState { disconnected, connecting, connected, disconnecting }

enum DistributedRole { none, parent, child }

class DistributedNetwork {
  SocketTransport? _parentSocket;
  DistributedState _state = DistributedState.disconnected;
  DistributedRole _role = DistributedRole.none;
  final _searchRequestsController = StreamController<DistributedSearchRequest>.broadcast();
  final _stateController = StreamController<DistributedState>.broadcast();
  StreamSubscription? _parentMessageSub;

  final String username;
  final int _maxChildBranches = 10;
  final List<SocketTransport> _childConnections = [];
  final SocketTransport Function() _socketFactory;

  DistributedNetwork({required this.username, SocketTransport Function()? socketFactory})
      : _socketFactory = socketFactory ?? (() => SocketManager());

  Stream<DistributedState> get stateChanges => _stateController.stream;
  Stream<DistributedSearchRequest> get searchRequests => _searchRequestsController.stream;
  DistributedState get state => _state;
  DistributedRole get role => _role;
  int get childCount => _childConnections.length;

  Future<bool> connectToParent(String host, int port) async {
    _setState(DistributedState.connecting);
    final socket = _socketFactory();
    try {
      await socket.connect(host, port);
      if (socket.state != SocketState.connected) {
        socket.dispose();
        _setState(DistributedState.disconnected);
        return false;
      }
      _parentSocket = socket;
      _role = DistributedRole.child;
      _parentMessageSub = socket.messages.listen(_onParentMessage);
      _setState(DistributedState.connected);
      return true;
    } catch (_) {
      socket.dispose();
      _setState(DistributedState.disconnected);
      return false;
    }
  }

  void becomeParent() {
    _role = DistributedRole.parent;
    _setState(DistributedState.connected);
  }

  bool acceptChildConnection(SocketTransport socket) {
    if (_childConnections.length >= _maxChildBranches) return false;
    _childConnections.add(socket);
    if (_role == DistributedRole.none) {
      _role = DistributedRole.parent;
    }
    return true;
  }

  void relaySearchRequest(String query, int ticket, {SocketTransport? exclude}) {
    if (_role != DistributedRole.parent) return;

    final w = WriteBuffer();
    w.writeString(username);
    w.writeInt32(ticket);
    w.writeString(query);

    for (final child in _childConnections) {
      if (child == exclude) continue;
      child.sendMessage(SoulseekMessage(DistantCode.fileSearch, w.toBytes()));
    }
  }

  void relaySearchResponse(SearchResult result, {SocketTransport? exclude}) {
    if (_role != DistributedRole.child || _parentSocket == null) return;

    final w = WriteBuffer();
    w.writeString(result.username);
    w.writeInt32(result.ticket);
    w.writeInt32(result.freeUploadSlots);
    w.writeInt32(result.uploadSpeed);
    w.writeInt32(result.queueLength);
    w.writeInt32(result.files.length);

    for (final file in result.files) {
      w.writeInt32(file.code);
      w.writeString(file.filename);
      w.writeInt32(file.size);
      w.writeString(file.extension);
      w.writeInt32(file.attributeCount);
      w.writeInt32(0); w.writeInt32(file.bitrate);
      w.writeInt32(1); w.writeInt32(file.duration);
      w.writeInt32(2); w.writeInt32(file.sampleRate);
    }

    _parentSocket!.sendMessage(SoulseekMessage(DistantCode.fileSearchReply, w.toBytes()));
  }

  void _onParentMessage(SoulseekMessage message) {
    if (message.code != DistantCode.fileSearch) return;

    try {
      final buffer = ReadBuffer(message.payload);
      final remoteUsername = buffer.readString();
      final ticket = buffer.readInt32();
      final query = buffer.readString();

      _searchRequestsController.add(DistributedSearchRequest(
        username: remoteUsername,
        ticket: ticket,
        query: query,
      ));
    } catch (_) {
      // Skip malformed messages
    }
  }

  void _setState(DistributedState state) {
    if (_state == state) return;
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void disconnect() {
    _setState(DistributedState.disconnecting);
    _parentMessageSub?.cancel();
    _parentSocket?.disconnect();
    _parentSocket?.dispose();
    for (final child in _childConnections) {
      child.disconnect();
      child.dispose();
    }
    _childConnections.clear();
    _parentSocket = null;
    _role = DistributedRole.none;
    _setState(DistributedState.disconnected);
  }

  void dispose() {
    disconnect();
    if (!_searchRequestsController.isClosed) {
      _searchRequestsController.close();
    }
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}

class DistributedSearchRequest {
  final String username;
  final int ticket;
  final String query;

  const DistributedSearchRequest({
    required this.username,
    required this.ticket,
    required this.query,
  });
}
