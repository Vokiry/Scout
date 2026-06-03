import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:soulseek_protocol/soulseek_protocol.dart';

import '../../core/di.dart';
import '../widgets/result_card.dart';
import '../widgets/filter_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _results = <SearchResult>[];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    ref.listen(searchResultsProvider, (prev, next) {
      next.whenData((result) {
        setState(() {
          // Deduplicate by (username, filename) 
          _results.removeWhere((r) => r.username == result.username);
          _results.add(result);
          _isSearching = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _results.clear();
      _isSearching = true;
    });

    ref.read(soulseekClientProvider).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for music...',
            filled: false,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _results.clear());
                    },
                  )
                : null,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FilterBar(),
          if (_isSearching)
            const LinearProgressIndicator(),
          if (_isSearching && _results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_tethering, size: 48, color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Searching...', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for results from peers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('Search for music', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Find tracks shared by other users',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ResultCard(
                    result: result,
                    onDownload: (file) {
                      _requestDownload(file, result);
                    },
                    onBrowse: () {
                      _browseUser(result.username);
                    },
                  ).animate().fadeIn(
                    duration: 400.ms,
                    delay: (index * 50).ms,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _requestDownload(SearchResultFile file, SearchResult result) {
    final client = ref.read(soulseekClientProvider);
    client.enqueueDownload(
      filename: file.filename,
      size: file.size,
      username: result.username,
      fileCode: file.code,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to queue: ${file.filename.split(RegExp(r'[/\\]')).last}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _browseUser(String username) {
    // TODO: navigate to user browse
  }
}
