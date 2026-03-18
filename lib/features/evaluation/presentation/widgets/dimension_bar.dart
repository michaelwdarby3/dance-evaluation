import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';

/// Horizontal bar showing the score for a single evaluation dimension.
class DimensionBar extends StatelessWidget {
  const DimensionBar({
    super.key,
    required this.dimension,
    required this.score,
  });

  final EvalDimension dimension;

  /// Score in the range [0, 100].
  final double score;

  String get _label => switch (dimension) {
        EvalDimension.timing => 'Timing',
        EvalDimension.technique => 'Technique',
        EvalDimension.expression => 'Expression',
        EvalDimension.spatialAwareness => 'Spatial',
      };

  IconData get _icon => switch (dimension) {
        EvalDimension.timing => Icons.timer_outlined,
        EvalDimension.technique => Icons.precision_manufacturing_outlined,
        EvalDimension.expression => Icons.emoji_emotions_outlined,
        EvalDimension.spatialAwareness => Icons.open_with_outlined,
      };

  Color get _color {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_icon, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              _label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 10,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(_color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              score.round().toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
