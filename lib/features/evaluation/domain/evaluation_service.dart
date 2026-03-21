import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_pose_sequence.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/utils/dtw.dart';
import 'package:dance_evaluation/core/utils/pose_math.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';

/// On-device evaluation service for Milestone 1.
///
/// Compares a user [PoseSequence] against a [ReferenceChoreography] using DTW
/// alignment, then produces multi-dimensional scores and joint-level feedback.
class EvaluationService {
  /// Maximum DTW distance that maps to a score of 0.
  /// Distances beyond this are clamped to 0.
  static const double _maxDistance = 50.0;

  final FeedbackGenerator _feedbackGenerator = FeedbackGenerator();

  /// Evaluate [userSequence] against [reference].
  Future<EvaluationResult> evaluate(
    PoseSequence userSequence,
    ReferenceChoreography reference,
  ) async {
    final refNorm = reference.poses.normalize();
    final userNorm = userSequence.normalize();

    final dtwResult = computeDtw(refNorm, userNorm);
    final path = dtwResult.warpingPath;

    final timingScore = _scoreTimingFromPath(path, refNorm.frames.length, userNorm.frames.length);
    final techniqueScore = _scoreTechnique(refNorm, userNorm, path);
    final expressionScore = _scoreExpression(refNorm, userNorm, path);
    final spatialScore = _scoreSpatial(dtwResult.normalizedDistance);

    final weights = StyleProfiles.styleProfiles[reference.style]!;
    final dimensionScores = {
      EvalDimension.timing: timingScore,
      EvalDimension.technique: techniqueScore,
      EvalDimension.expression: expressionScore,
      EvalDimension.spatialAwareness: spatialScore,
    };

    final overallScore = weights.weightedScore(dimensionScores);

    final jointFeedback = _analyzeJoints(refNorm, userNorm, path);

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

    final result = EvaluationResult(
      id: id,
      overallScore: overallScore.clamp(0, 100),
      dimensions: [
        DimensionScore(
          dimension: EvalDimension.timing,
          score: timingScore,
          summary: _timingSummary(timingScore),
        ),
        DimensionScore(
          dimension: EvalDimension.technique,
          score: techniqueScore,
          summary: _techniqueSummary(techniqueScore),
        ),
        DimensionScore(
          dimension: EvalDimension.expression,
          score: expressionScore,
          summary: _expressionSummary(expressionScore),
        ),
        DimensionScore(
          dimension: EvalDimension.spatialAwareness,
          score: spatialScore,
          summary: _spatialSummary(spatialScore),
        ),
      ],
      jointFeedback: jointFeedback,
      drills: const [],
      createdAt: DateTime.now(),
      style: reference.style,
    );

    // Generate detailed, time-localized feedback.
    final detailed = _feedbackGenerator.generate(
      refSequence: refNorm,
      userSequence: userNorm,
      warpingPath: path,
      result: result,
    );

    return EvaluationResult(
      id: result.id,
      overallScore: result.overallScore,
      dimensions: result.dimensions,
      jointFeedback: result.jointFeedback,
      drills: result.drills,
      createdAt: result.createdAt,
      style: result.style,
      timingInsights: detailed.timingInsights,
      jointInsights: detailed.jointInsights,
      coachingSummary: detailed.overallCoaching,
    );
  }

  /// Evaluate a multi-person performance against a multi-person reference.
  ///
  /// Matches user persons to reference persons by first-frame hip centroid
  /// proximity, runs [evaluate] per pair, and aggregates scores.
  Future<MultiPersonEvaluationResult> evaluateMulti(
    MultiPoseSequence userSequence,
    ReferenceChoreography reference,
  ) async {
    final refPersons = reference.personPoses;
    final userPersons = userSequence.personSequences;

    if (userPersons.length == 1 && refPersons.length == 1) {
      final result = await evaluate(userPersons.first, reference);
      return MultiPersonEvaluationResult(
        personResults: [result],
        overallScore: result.overallScore,
      );
    }

    // Match persons by first-frame centroid proximity.
    final matching = _matchPersons(userPersons, refPersons);

    final results = <EvaluationResult>[];
    for (final (userIdx, refIdx) in matching) {
      // Create a temporary single-person reference for each pair.
      final singleRef = ReferenceChoreography(
        id: reference.id,
        name: reference.name,
        style: reference.style,
        poses: refPersons[refIdx],
        bpm: reference.bpm,
        description: reference.description,
        difficulty: reference.difficulty,
        audioAsset: reference.audioAsset,
      );
      final result = await evaluate(userPersons[userIdx], singleRef);
      results.add(result);
    }

    final overallScore = results.isEmpty
        ? 0.0
        : results.map((r) => r.overallScore).reduce((a, b) => a + b) /
            results.length;

    return MultiPersonEvaluationResult(
      personResults: results,
      overallScore: overallScore,
    );
  }

  /// Match user persons to reference persons by first-frame hip centroid.
  List<(int userIdx, int refIdx)> _matchPersons(
    List<PoseSequence> userPersons,
    List<PoseSequence> refPersons,
  ) {
    if (userPersons.isEmpty || refPersons.isEmpty) return [];

    final userCentroids = userPersons.map(_firstFrameCentroid).toList();
    final refCentroids = refPersons.map(_firstFrameCentroid).toList();

    final matched = <(int, int)>[];
    final usedRef = <int>{};

    // Greedy matching by nearest centroid.
    for (var ui = 0; ui < userCentroids.length; ui++) {
      var bestRefIdx = -1;
      var bestDist = double.infinity;

      for (var ri = 0; ri < refCentroids.length; ri++) {
        if (usedRef.contains(ri)) continue;
        final dx = userCentroids[ui].$1 - refCentroids[ri].$1;
        final dy = userCentroids[ui].$2 - refCentroids[ri].$2;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < bestDist) {
          bestDist = dist;
          bestRefIdx = ri;
        }
      }

      if (bestRefIdx >= 0) {
        matched.add((ui, bestRefIdx));
        usedRef.add(bestRefIdx);
      }
    }

    return matched;
  }

  (double, double) _firstFrameCentroid(PoseSequence seq) {
    if (seq.frames.isEmpty) return (0.5, 0.5);
    final frame = seq.frames.first;
    final lh = frame.landmarks[PoseConstants.leftHip];
    final rh = frame.landmarks[PoseConstants.rightHip];
    return ((lh.x + rh.x) / 2, (lh.y + rh.y) / 2);
  }

  // ---------------------------------------------------------------------------
  // Dimension scoring
  // ---------------------------------------------------------------------------

  /// Timing: how close the warping path is to a straight diagonal.
  /// A perfect diagonal means the user matched the reference timing exactly.
  double _scoreTimingFromPath(List<(int, int)> path, int refLen, int userLen) {
    if (path.isEmpty) return 0;

    final idealSlope = refLen > 1 ? (userLen - 1) / (refLen - 1) : 1.0;
    var totalDeviation = 0.0;

    for (final (ri, ui) in path) {
      final expected = ri * idealSlope;
      totalDeviation += (ui - expected).abs();
    }

    final avgDeviation = totalDeviation / path.length;
    // Map deviation to 0-100: 0 deviation = 100, deviation >= refLen/2 = 0
    final maxDev = math.max(refLen / 2, 1).toDouble();
    return ((1 - avgDeviation / maxDev) * 100).clamp(0, 100);
  }

  /// Technique: average cosine similarity of aligned poses.
  double _scoreTechnique(
    PoseSequence ref,
    PoseSequence user,
    List<(int, int)> path,
  ) {
    if (path.isEmpty) return 0;

    var totalSim = 0.0;
    for (final (ri, ui) in path) {
      final refVec = PoseMath.poseToVector(ref.frames[ri]);
      final userVec = PoseMath.poseToVector(user.frames[ui]);
      totalSim += PoseMath.cosineSimilarity(refVec, userVec);
    }

    final avgSim = totalSim / path.length;
    // Cosine similarity ranges from -1 to 1; map [0.5, 1.0] → [0, 100]
    return ((avgSim - 0.5) * 200).clamp(0, 100);
  }

  /// Expression: how similar the movement dynamics (velocity variance) are.
  double _scoreExpression(
    PoseSequence ref,
    PoseSequence user,
    List<(int, int)> path,
  ) {
    final refVelocities = _computeVelocities(ref);
    final userVelocities = _computeVelocities(user);

    if (refVelocities.isEmpty || userVelocities.isEmpty) return 50;

    final refVar = _variance(refVelocities);
    final userVar = _variance(userVelocities);

    if (refVar == 0 && userVar == 0) return 100;
    if (refVar == 0 || userVar == 0) return 20;

    // Ratio of variances: closer to 1.0 = more similar dynamics
    final ratio = math.min(refVar, userVar) / math.max(refVar, userVar);
    return (ratio * 100).clamp(0, 100);
  }

  /// Spatial awareness: based on normalized DTW distance.
  double _scoreSpatial(double normalizedDistance) {
    return ((1 - normalizedDistance / _maxDistance) * 100).clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Joint analysis
  // ---------------------------------------------------------------------------

  /// Analyze each key joint and return feedback for the worst performers.
  List<JointFeedback> _analyzeJoints(
    PoseSequence ref,
    PoseSequence user,
    List<(int, int)> path,
  ) {
    if (path.isEmpty) return [];

    final jointScores = <String, double>{};

    for (final entry in PoseConstants.keyJoints.entries) {
      final jointName = entry.key;
      final indices = entry.value;

      var totalAngleDiff = 0.0;
      for (final (ri, ui) in path) {
        final refAngle = ref.frames[ri].angleBetween(indices[0], indices[1], indices[2]);
        final userAngle = user.frames[ui].angleBetween(indices[0], indices[1], indices[2]);
        totalAngleDiff += (refAngle - userAngle).abs();
      }

      final avgDiff = totalAngleDiff / path.length;
      // Map angle difference to score: 0° diff = 100, ≥45° diff = 0
      jointScores[jointName] = ((1 - avgDiff / 45) * 100).clamp(0, 100);
    }

    // Sort by score ascending (worst first), take top 5
    final sortedJoints = jointScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final worstJoints = sortedJoints.take(5);

    return worstJoints.map((entry) {
      final indices = PoseConstants.keyJoints[entry.key]!;
      return JointFeedback(
        jointName: entry.key,
        landmarkIndices: indices,
        score: entry.value,
        issue: _jointIssue(entry.key, entry.value),
        correction: _jointCorrection(entry.key, entry.value),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<double> _computeVelocities(PoseSequence seq) {
    final velocities = <double>[];
    for (var i = 1; i < seq.frames.length; i++) {
      final dt = (seq.frames[i].timestamp - seq.frames[i - 1].timestamp).inMilliseconds;
      if (dt <= 0) continue;
      final dist = PoseMath.poseDistance(seq.frames[i], seq.frames[i - 1]);
      velocities.add(dist / dt * 1000); // units per second
    }
    return velocities;
  }

  double _variance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  }

  // ---------------------------------------------------------------------------
  // Template feedback text
  // ---------------------------------------------------------------------------

  String _timingSummary(double score) {
    if (score >= 80) return 'Great rhythm! You stayed on beat consistently.';
    if (score >= 60) return 'Decent timing, but you drifted off beat in places.';
    if (score >= 40) return 'Timing needs work. Try counting beats out loud.';
    return 'Significant timing issues. Practice with a metronome first.';
  }

  String _techniqueSummary(double score) {
    if (score >= 80) return 'Excellent form! Your poses closely match the reference.';
    if (score >= 60) return 'Good technique overall with room for improvement.';
    if (score >= 40) return 'Several poses were off. Focus on the joint feedback below.';
    return 'Technique needs significant improvement. Start with basic drills.';
  }

  String _expressionSummary(double score) {
    if (score >= 80) return 'Great dynamics! Your energy matches the choreography.';
    if (score >= 60) return 'Good energy, but some moves lack punch or fluidity.';
    if (score >= 40) return 'Movement feels flat. Try exaggerating your motions.';
    return 'Movement dynamics are very different from the reference.';
  }

  String _spatialSummary(double score) {
    if (score >= 80) return 'Excellent spatial accuracy and movement range.';
    if (score >= 60) return 'Mostly in the right positions with minor drift.';
    if (score >= 40) return 'Positions are off in several sections. Watch the reference again.';
    return 'Large spatial deviations. Focus on where your body should be.';
  }

  String _jointIssue(String joint, double score) {
    final readableName = _readableJointName(joint);
    if (score >= 70) return 'Your $readableName movement is mostly accurate.';
    if (score >= 40) return 'Your $readableName angle deviates from the reference.';
    return 'Your $readableName position is significantly off.';
  }

  String _jointCorrection(String joint, double score) {
    final readableName = _readableJointName(joint);
    if (score >= 70) return 'Minor adjustments: watch the reference closely for $readableName.';
    if (score >= 40) return 'Practice isolating your $readableName movement separately.';
    return 'Start with slow-motion drills focusing on $readableName positioning.';
  }

  String _readableJointName(String joint) {
    // Convert camelCase to readable: "leftElbow" → "left elbow"
    return joint.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
    );
  }
}
