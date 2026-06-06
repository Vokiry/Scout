import 'dart:async';

import '../connection/server_connection.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';

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

class SearchService {
  final ServerTransport _server;
  final _resultsController = StreamController<SearchResult>.broadcast();
  int _nextTicket = 1;

  late final StreamSubscription _messageSub;

  SearchService({required ServerTransport server}) : _server = server;

  Stream<SearchResult> get results => _resultsController.stream;

  void init() {
    _messageSub = _server.messages.listen(_onMessage);
  }

  int search(String query) {
    final ticket = _nextTicket++;
    _server.sendMessage(SoulseekMessage(
      ServerCode.searchRequest,
      SearchRequest(query: query, ticket: ticket).serialize().toBytes(),
    ));
    return ticket;
  }

  void _onMessage(SoulseekMessage message) {
    if (message.code != ServerCode.searchResponse &&
        message.code != ServerCode.userSearchResponse) {
      return;
    }

    try {
      final buffer = ReadBuffer(message.payload);
      SearchResponseData response;
      try {
        response = SearchResponseData.parse(buffer);
      } catch (_) {
        response = SearchResponseData.parseOld(ReadBuffer(message.payload));
      }

      _resultsController.add(SearchResult(
        username: response.username,
        ticket: response.ticket,
        freeUploadSlots: response.freeUploadSlots,
        uploadSpeed: response.uploadSpeed,
        queueLength: response.queueLength,
        files: response.files,
      ));
    } catch (_) {
      // Skip malformed search responses
    }
  }

  void dispose() {
    _messageSub.cancel();
    _resultsController.close();
  }
}
