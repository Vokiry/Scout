import 'package:flutter/material.dart';
import 'package:soulseek_protocol/soulseek_protocol.dart';

class ResultCard extends StatelessWidget {
  final SearchResult result;
  final void Function(SearchResultFile file)? onDownload;
  final VoidCallback? onBrowse;

  const ResultCard({
    super.key,
    required this.result,
    this.onDownload,
    this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: _buildFileTypeIcon(colorScheme),
        title: Text(
          result.username,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            _buildSpeedChip(context),
            const SizedBox(width: 8),
            _buildSlotsChip(context),
            const SizedBox(width: 8),
            Text(
              '${result.files.length} files',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          ...result.files.take(10).map((file) => _buildFileRow(context, file)),
          if (result.files.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '+ ${result.files.length - 10} more files...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileRow(BuildContext context, SearchResultFile file) {
    final colorScheme = Theme.of(context).colorScheme;
    final filename = file.filename.split(RegExp(r'[/\\]')).last;

    return ListTile(
      dense: true,
      title: Text(
        filename,
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatSize(file.size)}  ·  ${file.bitrate}kbps  ·  ${_formatDuration(file.duration)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'download' && onDownload != null) {
            onDownload!(file);
          } else if (value == 'browse') {
            onBrowse?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'download', child: Text('Download')),
          const PopupMenuItem(value: 'browse', child: Text('Browse User')),
          const PopupMenuItem(value: 'view', child: Text('Properties')),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(BuildContext context) {
    final speed = result.uploadSpeed;
    final label = speed >= 1000
        ? '${(speed / 1000).toStringAsFixed(0)} MB/s'
        : '$speed KB/s';

    return _chip(context, label, Colors.green);
  }

  Widget _buildSlotsChip(BuildContext context) {
    if (result.freeUploadSlots > 0) {
      return _chip(context, 'Free', Colors.green);
    }
    return _chip(context, 'Queue: ${result.queueLength}', Colors.orange);
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFileTypeIcon(ColorScheme colorScheme) {
    // Check if any files are lossless
    final hasFlac = result.files.any((f) => f.extension.toLowerCase() == 'flac');
    final hasMp3 = result.files.any((f) => f.extension.toLowerCase() == 'mp3');

    if (hasFlac) {
      return Icon(Icons.audio_file, color: colorScheme.primary);
    }
    if (hasMp3) {
      return Icon(Icons.music_note, color: colorScheme.secondary);
    }
    return Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant);
  }

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
