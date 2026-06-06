import 'dart:async';

import '../messages/buffer.dart';
import '../messages/codes.dart';
import '../messages/message.dart';
import '../peer/peer_connection.dart';

class BrowseService {
  BrowseService();

  Future<FolderContentsReply> browseUser({
    required TransferConnection connection,
    String directory = '',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    connection.sendMessage(
      SoulseekMessage(
        PeerCode.folderContents,
        FolderContentsRequest(directory).serialize().toBytes(),
      ),
    );

    final completer = Completer<FolderContentsReply>();
    StreamSubscription? sub;
    Timer? timer;

    sub = connection.messages.listen((message) {
      if (message.code != PeerCode.folderContentsReply) return;
      try {
        final reply = FolderContentsReply.parse(ReadBuffer(message.payload));
        if (!completer.isCompleted) {
          completer.complete(reply);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Browse request timed out after $timeout'),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      await sub.cancel();
      timer.cancel();
    }
  }

  void dispose() {}
}
