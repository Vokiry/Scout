import 'dart:async';

import '../connection/server_connection.dart';
import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';

class WishlistService {
  final ServerTransport _server;
  final _resultsController = StreamController<WishlistReply>.broadcast();
  int _nextTicket = 1;

  late final StreamSubscription _messageSub;

  WishlistService({required ServerTransport server}) : _server = server;

  Stream<WishlistReply> get wishlistResults => _resultsController.stream;

  void init() {
    _messageSub = _server.messages.listen(_onMessage);
  }

  int wishlistSearch(String query) {
    final ticket = _nextTicket++;
    _server.sendMessage(SoulseekMessage(
      ServerCode.wishes,
      WishlistSearchRequest(ticket: ticket, query: query).serialize().toBytes(),
    ));
    return ticket;
  }

  void addWishlistItem(String phrase) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.wishlistInclusion,
      WishlistInclusion(add: true, phrase: phrase).serialize().toBytes(),
    ));
  }

  void removeWishlistItem(String phrase) {
    _server.sendMessage(SoulseekMessage(
      ServerCode.wishlistInclusion,
      WishlistInclusion(add: false, phrase: phrase).serialize().toBytes(),
    ));
  }

  void _onMessage(SoulseekMessage message) {
    if (message.code != ServerCode.wishReply) return;

    try {
      final reply = WishlistReply.parse(ReadBuffer(message.payload));
      _resultsController.add(reply);
    } catch (_) {
      // Skip malformed wishlist replies
    }
  }

  void dispose() {
    _messageSub.cancel();
    _resultsController.close();
  }
}
