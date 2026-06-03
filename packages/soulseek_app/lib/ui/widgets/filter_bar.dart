import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(context, 'All', true),
            const SizedBox(width: 8),
            _buildChip(context, 'Lossless', false),
            const SizedBox(width: 8),
            _buildChip(context, 'MP3', false),
            const SizedBox(width: 8),
            _buildChip(context, 'Video', false),
            const SizedBox(width: 8),
            _buildChip(context, 'Free Slot', false),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, bool selected) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      visualDensity: VisualDensity.compact,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
}
