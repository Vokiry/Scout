import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulseek_protocol/soulseek_protocol.dart';

final soulseekClientProvider = Provider<SoulseekClient>((ref) {
  final client = SoulseekClient();
  client.init();
  ref.onDispose(() => client.dispose());
  return client;
});

final connectionStateProvider = StreamProvider<ServerConnectionState>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.connectionState;
});

final connectionInfoProvider = StreamProvider<ConnectionInfo>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.connectionInfo;
});

final searchResultsProvider = StreamProvider<SearchResult>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.searchResults;
});

final downloadProgressProvider = StreamProvider<Map<String, DownloadProgress>>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.downloadProgress;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.authenticated;
});

final usernameProvider = Provider<String?>((ref) {
  final client = ref.watch(soulseekClientProvider);
  return client.username;
});
