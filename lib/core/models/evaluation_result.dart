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

  Map<String, dynamic> toJson() => {
        'dimension': dimension.name,
        'score': score,
        'summary': summary,
      };

  factory DimensionScore.fromJson(Map<String, dynamic> json) => DimensionScore(
        dimension: EvalDimension.values.firstWhere(
          (d) => d.name == json['dimension'],
        ),
        score: (json['score'] as num).toDouble(),
        summary: json['summary'] as String,
      );

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

  Map<String, dynamic> toJson() => {
        'jointName': jointName,
        'landmarkIndices': landmarkIndices,
        'score': score,
        'issue': issue,
        'correction': correction,
      };

  factory JointFeedback.fromJson(Map<String, dynamic> json) => JointFeedback(
        jointName: json['jointName'] as String,
        landmarkIndices: (json['landmarkIndices'] as List).cast<int>(),
        score: (json['score'] as num).toDouble(),
        issue: json['issue'] as String,
        correction: json['correction'] as String,
      );

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
    this.description = '',
  });

  final String drillId;
  final String name;
  final String targetJoint;
  final EvalDimension targetDimension;

  /// Lower number = higher priority.
  final int priority;

  /// Human-readable description of the drill exercise.
  final String description;

  Map<String, dynamic> toJson() => {
        'drillId': drillId,
        'name': name,
        'targetJoint': targetJoint,
        'targetDimension': targetDimension.name,
        'priority': priority,
        'description': description,
      };

  factory DrillRecommendation.fromJson(Map<String, dynamic> json) =>
      DrillRecommendation(
        drillId: json['drillId'] as String,
        name: json['name'] as String,
        targetJoint: json['targetJoint'] as String,
        targetDimension: EvalDimension.values.firstWhere(
          (d) => d.name == json['targetDimension'],
        ),
        priority: json['priority'] as int,
        description: json['description'] as String? ?? '',
      );

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
    this.referenceName,
    this.sessionName,
    this.timingInsights = const [],
    this.jointInsights = const [],
    this.coachingSummary,
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

  /// Name of the reference choreography used (for display in history).
  final String? referenceName;

  /// Optional user-given name for this session.
  final String? sessionName;

  /// Time-localized timing feedback strings.
  final List<String> timingInsights;

  /// Direction-aware, time-localized joint feedback strings.
  final List<String> jointInsights;

  /// Overall coaching summary (local or AI-generated).
  final String? coachingSummary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'overallScore': overallScore,
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        'jointFeedback': jointFeedback.map((j) => j.toJson()).toList(),
        'drills': drills.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'style': style.name,
        'referenceName': referenceName,
        'sessionName': sessionName,
        'timingInsights': timingInsights,
        'jointInsights': jointInsights,
        'coachingSummary': coachingSummary,
      };

  factory EvaluationResult.fromJson(Map<String, dynamic> json) =>
      EvaluationResult(
        id: json['id'] as String,
        overallScore: (json['overallScore'] as num).toDouble(),
        dimensions: (json['dimensions'] as List)
            .map((d) => DimensionScore.fromJson(d as Map<String, dynamic>))
            .toList(),
        jointFeedback: (json['jointFeedback'] as List)
            .map((j) => JointFeedback.fromJson(j as Map<String, dynamic>))
            .toList(),
        drills: (json['drills'] as List)
            .map((d) => DrillRecommendation.fromJson(d as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        style: DanceStyle.values.firstWhere(
          (s) => s.name == json['style'],
        ),
        referenceName: json['referenceName'] as String?,
        sessionName: json['sessionName'] as String?,
        timingInsights: (json['timingInsights'] as List?)
                ?.cast<String>() ??
            const [],
        jointInsights: (json['jointInsights'] as List?)
                ?.cast<String>() ??
            const [],
        coachingSummary: json['coachingSummary'] as String?,
      );

  @override
  String toString() =>
      'EvaluationResult(id: $id, overall: $overallScore, style: ${style.name})';
}
