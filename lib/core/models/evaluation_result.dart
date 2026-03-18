import '../constants/style_constants.dart';

/// Score for a single evaluation dimension.
class DimensionScore {
  const DimensionScore({
    required this.dimension,
    required this.score,
    required this.summary,
  });

  final EvalDimension dimension;

  /// Score in the range [0, 100].
  final double score;

  /// Human-readable explanation of the score.
  final String summary;

  @override
  String toString() =>
      'DimensionScore(${dimension.name}: $score - $summary)';
}

/// Feedback for a specific joint across the evaluated sequence.
class JointFeedback {
  const JointFeedback({
    required this.jointName,
    required this.landmarkIndices,
    required this.score,
    required this.issue,
    required this.correction,
  });

  /// Human-readable joint name (e.g. "leftElbow").
  final String jointName;

  /// The three landmark indices that define this joint angle.
  final List<int> landmarkIndices;

  /// Score in the range [0, 100].
  final double score;

  /// Description of the detected issue.
  final String issue;

  /// Suggested correction.
  final String correction;

  @override
  String toString() => 'JointFeedback($jointName: $score)';
}

/// A recommended drill to improve a weak area.
class DrillRecommendation {
  const DrillRecommendation({
    required this.drillId,
    required this.name,
    required this.targetJoint,
    required this.targetDimension,
    required this.priority,
  });

  final String drillId;
  final String name;
  final String targetJoint;
  final EvalDimension targetDimension;

  /// Lower number = higher priority.
  final int priority;

  @override
  String toString() => 'DrillRecommendation($name, priority: $priority)';
}

/// Complete evaluation result for a dance performance.
class EvaluationResult {
  const EvaluationResult({
    required this.id,
    required this.overallScore,
    required this.dimensions,
    required this.jointFeedback,
    required this.drills,
    required this.createdAt,
    required this.style,
  });

  final String id;

  /// Weighted overall score in the range [0, 100].
  final double overallScore;

  /// Per-dimension scores.
  final List<DimensionScore> dimensions;

  /// Per-joint feedback items.
  final List<JointFeedback> jointFeedback;

  /// Recommended drills sorted by priority.
  final List<DrillRecommendation> drills;

  final DateTime createdAt;
  final DanceStyle style;

  @override
  String toString() =>
      'EvaluationResult(id: $id, overall: $overallScore, style: ${style.name})';
}
