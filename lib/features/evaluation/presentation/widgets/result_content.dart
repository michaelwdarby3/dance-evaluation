import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

/// Shared widget that renders evaluation result content.
/// Used by both EvaluationResultScreen and HistoryDetailScreen.
class ResultContent extends StatelessWidget {
  const ResultContent({
    super.key,
    required this.result,
    this.trailing,
  });

  final EvaluationResult result;

  /// Optional trailing widget rendered after all result content.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Overall score
        ScoreIndicator(score: result.overallScore),
        const SizedBox(height: 8),
        Text(
          result.style.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
        if (result.referenceName != null) ...[
          const SizedBox(height: 4),
          Text(
            result.referenceName!,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
        const SizedBox(height: 32),

        // Dimension scores
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Dimensions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...result.dimensions.map(
          (d) => DimensionBar(dimension: d.dimension, score: d.score),
        ),
        const SizedBox(height: 8),
        ...result.dimensions.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              d.summary,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Coaching summary
        if (result.coachingSummary != null &&
            result.coachingSummary!.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Coaching',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              result.coachingSummary!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Timing insights
        if (result.timingInsights.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Timing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...result.timingInsights.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Body-specific insights
        if (result.jointInsights.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Body Feedback',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...result.jointInsights.map(
            (j) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.accessibility_new,
                      size: 14,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      j,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Joint feedback (detailed)
        if (result.jointFeedback.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Joint Feedback',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...result.jointFeedback.map(_buildJointCard),
          const SizedBox(height: 16),
        ],

        // Drill recommendations
        if (result.drills.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recommended Drills',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...result.drills.map(_buildDrillCard),
          const SizedBox(height: 16),
        ],

        if (trailing != null) trailing!,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildJointCard(JointFeedback jf) {
    final color = jf.score >= 70
        ? const Color(0xFF4CAF50)
        : jf.score >= 40
            ? const Color(0xFFFFC107)
            : const Color(0xFFF44336);

    return Card(
      color: const Color(0xFF1E1E2C),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: color, size: 10),
                const SizedBox(width: 8),
                Text(
                  _readableJointName(jf.jointName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${jf.score.round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: jf.score / 100,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              jf.issue,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              jf.correction,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillCard(DrillRecommendation drill) {
    return Card(
      color: const Color(0xFF1E1E2C),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
          child: Text(
            '${drill.priority}',
            style: const TextStyle(
              color: Color(0xFF7C4DFF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          drill.name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: drill.description.isNotEmpty
            ? Text(
                drill.description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              )
            : null,
        trailing: Text(
          drill.targetDimension.name,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  String _readableJointName(String joint) {
    return joint
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
        )
        .replaceFirst(joint[0], joint[0].toUpperCase());
  }
}
