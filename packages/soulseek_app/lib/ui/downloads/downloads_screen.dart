import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulseek_protocol/soulseek_protocol.dart';

import '../../core/di.dart';
import '../widgets/waveform_progress.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final downloadsAsync = ref.watch(downloadProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Queued'),
              Tab(text: 'Done'),
              Tab(text: 'Failed'),
            ],
            onTap: (index) => setState(() => _tabIndex = index),
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: downloadsAsync.when(
              data: (progressMap) {
                final downloads = progressMap.values.toList();
                if (downloads.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_outlined, size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No downloads', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                final filtered = _filterByTab(downloads);
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final download = filtered[index];
                    return _DownloadCard(download: download);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  List<DownloadProgress> _filterByTab(List<DownloadProgress> all) {
    switch (_tabIndex) {
      case 0:
        return all.where((d) => d.state == DownloadState.downloading).toList();
      case 1:
        return all.where((d) => d.state == DownloadState.queued).toList();
      case 2:
        return all.where((d) => d.state == DownloadState.completed).toList();
      case 3:
        return all.where((d) => d.state == DownloadState.failed).toList();
      default:
        return all;
    }
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadProgress download;

  const _DownloadCard({required this.download});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final filename = download.filename.split(RegExp(r'[/\\]')).last;
    final stateLabel = _stateLabel(download.state);
    final stateColor = _stateColor(download.state, colorScheme);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    filename,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: stateColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (download.state == DownloadState.downloading) ...[
              WaveformProgress(percentage: download.percentage),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatSize(download.downloadedBytes)} / ${_formatSize(download.totalSize)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    download.speed != null ? '${download.speed!.toStringAsFixed(0)} KB/s' : '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stateLabel(DownloadState state) {
    switch (state) {
      case DownloadState.queued: return 'Queued';
      case DownloadState.requesting: return 'Requesting';
      case DownloadState.downloading: return 'Downloading';
      case DownloadState.paused: return 'Paused';
      case DownloadState.completed: return 'Complete';
      case DownloadState.failed: return 'Failed';
      case DownloadState.cancelled: return 'Cancelled';
    }
  }

  Color _stateColor(DownloadState state, ColorScheme colors) {
    switch (state) {
      case DownloadState.downloading: return colors.primary;
      case DownloadState.completed: return Colors.green;
      case DownloadState.failed: return colors.error;
      case DownloadState.paused: return Colors.orange;
      default: return colors.onSurfaceVariant;
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
