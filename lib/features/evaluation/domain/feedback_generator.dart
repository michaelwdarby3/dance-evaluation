import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

/// Rich, time-localized feedback generated entirely on-device.
class DetailedFeedback {
  const DetailedFeedback({
    required this.timingInsights,
    required this.jointInsights,
    required this.overallCoaching,
  });

  /// Time-localized timing feedback (e.g. "You rushed during the second quarter").
  final List<String> timingInsights;

  /// Direction-aware, time-localized joint feedback.
  final List<String> jointInsights;

  /// 2-3 sentence overall coaching summary.
  final String overallCoaching;
}

/// Generates rich verbal feedback from DTW alignment data.
class FeedbackGenerator {
  /// Number of temporal segments to divide the routine into.
  static const int _segments = 4;
  static const List<String> _segmentNames = [
    'first quarter',
    'second quarter',
    'third quarter',
    'final quarter',
  ];

  /// Generate detailed feedback from aligned sequences.
  DetailedFeedback generate({
    required PoseSequence refSequence,
    required PoseSequence userSequence,
    required List<(int, int)> warpingPath,
    required EvaluationResult result,
  }) {
    final timingInsights = _analyzeTimingSegments(
      warpingPath,
      refSequence.frames.length,
      userSequence.frames.length,
    );

    final jointInsights = _analyzeJointSegments(
      refSequence,
      userSequence,
      warpingPath,
    );

    final overallCoaching = _generateCoachingSummary(result, timingInsights);

    return DetailedFeedback(
      timingInsights: timingInsights,
      jointInsights: jointInsights,
      overallCoaching: overallCoaching,
    );
  }

  // ---------------------------------------------------------------------------
  // Timing analysis by segment
  // ---------------------------------------------------------------------------

  List<String> _analyzeTimingSegments(
    List<(int, int)> path,
    int refLen,
    int userLen,
  ) {
    if (path.isEmpty || refLen <= 1) return [];

    final insights = <String>[];
    final segmentSize = (path.length / _segments).ceil().clamp(1, path.length);
    final idealSlope = (userLen - 1) / (refLen - 1);

    for (var seg = 0; seg < _segments; seg++) {
      final start = seg * segmentSize;
      final end = math.min(start + segmentSize, path.length);
      if (start >= path.length) break;

      final segmentPath = path.sublist(start, end);

      // Compute average slope in this segment.
      double avgSlope = 0;
      int slopeCount = 0;
      for (var i = 1; i < segmentPath.length; i++) {
        final dRef = segmentPath[i].$1 - segmentPath[i - 1].$1;
        final dUser = segmentPath[i].$2 - segmentPath[i - 1].$2;
        if (dRef > 0) {
          avgSlope += dUser / dRef;
          slopeCount++;
        }
      }

      if (slopeCount == 0) continue;
      avgSlope /= slopeCount;

      final slopeRatio = idealSlope > 0 ? avgSlope / idealSlope : 1.0;
      final name = _segmentNames[seg];

      if (slopeRatio > 1.3) {
        insights.add('You rushed through the $name of the routine.');
      } else if (slopeRatio < 0.7) {
        insights.add('You fell behind during the $name of the routine.');
      } else if (slopeRatio > 1.1) {
        insights.add('You were slightly ahead of the beat in the $name.');
      } else if (slopeRatio < 0.9) {
        insights.add('You were slightly behind the beat in the $name.');
      }
    }

    if (insights.isEmpty) {
      insights.add('Your timing was consistent throughout the routine.');
    }

    return insights;
  }

  // ---------------------------------------------------------------------------
  // Joint analysis by segment with direction awareness
  // ---------------------------------------------------------------------------

  List<String> _analyzeJointSegments(
    PoseSequence ref,
    PoseSequence user,
    List<(int, int)> path,
  ) {
    if (path.isEmpty) return [];

    final insights = <String>[];
    final segmentSize = (path.length / _segments).ceil().clamp(1, path.length);

    for (final entry in PoseConstants.keyJoints.entries) {
      final jointName = entry.key;
      final indices = entry.value;
      final readable = _readableJointName(jointName);

      // Compute per-segment angle diffs.
      var worstSegment = -1;
      var worstAvgDiff = 0.0;
      var worstDirection = 0.0; // positive = user angle too large (too extended)

      for (var seg = 0; seg < _segments; seg++) {
        final start = seg * segmentSize;
        final end = math.min(start + segmentSize, path.length);
        if (start >= path.length) break;

        var totalDiff = 0.0;
        var totalSigned = 0.0;
        var count = 0;

        for (var i = start; i < end; i++) {
          final (ri, ui) = path[i];
          final refAngle = ref.frames[ri].angleBetween(
            indices[0],
            indices[1],
            indices[2],
          );
          final userAngle = user.frames[ui].angleBetween(
            indices[0],
            indices[1],
            indices[2],
          );
          totalDiff += (refAngle - userAngle).abs();
          totalSigned += userAngle - refAngle;
          count++;
        }

        if (count == 0) continue;
        final avgDiff = totalDiff / count;

        if (avgDiff > worstAvgDiff) {
          worstAvgDiff = avgDiff;
          worstSegment = seg;
          worstDirection = totalSigned / count;
        }
      }

      // Only report joints with meaningful deviation (>15 degrees avg).
      if (worstAvgDiff < 15 || worstSegment < 0) continue;

      final segName = _segmentNames[worstSegment];
      final direction = _directionPhrase(jointName, worstDirection);

      if (worstAvgDiff >= 30) {
        insights.add(
          'Your $readable was significantly $direction during the $segName.',
        );
      } else {
        insights.add(
          'Your $readable was slightly $direction in the $segName.',
        );
      }
    }

    // Limit to top 5 most actionable.
    if (insights.length > 5) {
      return insights.sublist(0, 5);
    }
    return insights;
  }

  /// Returns a directional phrase based on joint type and angle difference sign.
  String _directionPhrase(String jointName, double signedDiff) {
    final isElbow = jointName.contains('Elbow');
    final isKnee = jointName.contains('Knee');
    final isShoulder = jointName.contains('Shoulder');
    final isHip = jointName.contains('Hip');
    final isAnkle = jointName.contains('Ankle');

    if (isElbow || isKnee) {
      return signedDiff > 0 ? 'too extended' : 'too bent';
    }
    if (isShoulder) {
      return signedDiff > 0 ? 'raised too high' : 'too low';
    }
    if (isHip) {
      return signedDiff > 0 ? 'too open' : 'too closed';
    }
    if (isAnkle) {
      return signedDiff > 0 ? 'too flexed' : 'too pointed';
    }
    return signedDiff > 0 ? 'over-extended' : 'under-extended';
  }

  // ---------------------------------------------------------------------------
  // Overall coaching summary
  // ---------------------------------------------------------------------------

  String _generateCoachingSummary(
    EvaluationResult result,
    List<String> timingInsights,
  ) {
    final score = result.overallScore;
    final dims = {
      for (final d in result.dimensions) d.dimension: d.score,
    };

    final buf = StringBuffer();

    // Opening line based on overall score.
    if (score >= 85) {
      buf.write('Excellent performance! ');
    } else if (score >= 70) {
      buf.write('Good work overall. ');
    } else if (score >= 50) {
      buf.write('Decent effort with clear areas to improve. ');
    } else {
      buf.write('Keep practicing — every session builds muscle memory. ');
    }

    // Find weakest dimension.
    final weakest = dims.entries.reduce(
      (a, b) => a.value < b.value ? a : b,
    );

    switch (weakest.key) {
      case EvalDimension.timing:
        buf.write('Focus on your timing — try practicing with the metronome.');
        break;
      case EvalDimension.technique:
        buf.write(
          'Your biggest opportunity is technique — '
          'slow down and nail the shapes before adding speed.',
        );
        break;
      case EvalDimension.expression:
        buf.write(
          'Work on your dynamics — '
          'exaggerate movements to match the energy of the reference.',
        );
        break;
      case EvalDimension.spatialAwareness:
        buf.write(
          'Pay attention to your positioning — '
          'watch the reference ghost overlay to guide your placement.',
        );
        break;
    }

    // If they had timing issues, add a specific pointer.
    final hasRush =
        timingInsights.any((t) => t.contains('rushed'));
    final hasFellBehind =
        timingInsights.any((t) => t.contains('fell behind'));

    if (hasRush && hasFellBehind) {
      buf.write(' Your pacing was inconsistent — try to stay steady throughout.');
    } else if (hasRush) {
      buf.write(' In particular, slow down in the sections where you rushed.');
    } else if (hasFellBehind) {
      buf.write(' Try to keep up in the sections where you fell behind.');
    }

    return buf.toString();
  }

  String _readableJointName(String joint) {
    return joint.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
    );
  }
}
