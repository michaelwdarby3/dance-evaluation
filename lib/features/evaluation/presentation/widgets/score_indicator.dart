import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular score indicator with animated arc and centered score text.
class ScoreIndicator extends StatelessWidget {
  const ScoreIndicator({
    super.key,
    required this.score,
    this.size = 160,
    this.strokeWidth = 12,
  });

  /// Score in the range [0, 100].
  final double score;

  /// Diameter of the indicator.
  final double size;

  /// Thickness of the arc stroke.
  final double strokeWidth;

  Color get _color {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreArcPainter(
          score: score,
          color: _color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.round().toString(),
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              Text(
                'SCORE',
                style: TextStyle(
                  fontSize: size * 0.09,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  _ScoreArcPainter({
    required this.score,
    required this.color,
    required this.strokeWidth,
  });

  final double score;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Background track.
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Score arc.
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // 12 o'clock
    final sweepAngle = 2 * math.pi * (score / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.score != score || old.color != color;
}
