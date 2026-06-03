import 'dart:math';
import 'package:flutter/material.dart';

class WaveformProgress extends StatefulWidget {
  final double percentage;

  const WaveformProgress({super.key, required this.percentage});

  @override
  State<WaveformProgress> createState() => _WaveformProgressState();
}

class _WaveformProgressState extends State<WaveformProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 32),
          painter: _WaveformPainter(
            percentage: widget.percentage,
            animationValue: _controller.value,
            fillColor: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double percentage;
  final double animationValue;
  final Color fillColor;
  final Color backgroundColor;

  _WaveformPainter({
    required this.percentage,
    required this.animationValue,
    required this.fillColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = 4.0;
    final spacing = 3.0;
    final bars = (size.width / (barWidth + spacing)).floor();
    final fullBars = (bars * percentage).round();
    final height = size.height;

    for (int i = 0; i < bars; i++) {
      final isFilled = i < fullBars;
      final x = i * (barWidth + spacing);

      final phase = (i / bars) * pi * 4 + animationValue * pi * 2;
      final barHeight = 8.0 + (sin(phase).abs() * (height - 8)).clamp(4.0, height);
      final y = height - barHeight;

      final paint = Paint()
        ..color = isFilled ? fillColor : backgroundColor
        ..style = PaintingStyle.fill;

      if (isFilled && i == fullBars - 1 && percentage < 1.0) {
        paint.color = fillColor.withValues(alpha: 0.5 + sin(animationValue * pi).abs() * 0.5);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.animationValue != animationValue;
}
