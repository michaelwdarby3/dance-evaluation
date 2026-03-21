import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';

PoseSequence _makeSequence({
  int frameCount = 20,
  int durationMs = 2000,
  double Function(int frameIndex)? xOffset,
}) {
  final landmarks = List.generate(
    33,
    (i) => Landmark(x: 0.5, y: 0.5 + i * 0.01, z: 0.0, visibility: 0.9),
  );

  return PoseSequence(
    frames: List.generate(
      frameCount,
      (i) {
        final offset = xOffset?.call(i) ?? 0.0;
        return PoseFrame(
          timestamp: Duration(
            milliseconds: (i * durationMs / frameCount).round(),
          ),
          landmarks: landmarks
              .map((lm) => Landmark(
                    x: lm.x + offset,
                    y: lm.y,
                    z: lm.z,
                    visibility: lm.visibility,
                  ))
              .toList(),
        );
      },
    ),
    fps: frameCount / (durationMs / 1000),
    duration: Duration(milliseconds: durationMs),
  );
}

EvaluationResult _makeResult({double overall = 75.0}) {
  return EvaluationResult(
    id: 'test',
    overallScore: overall,
    dimensions: const [
      DimensionScore(
        dimension: EvalDimension.timing,
        score: 80,
        summary: 'Good',
      ),
      DimensionScore(
        dimension: EvalDimension.technique,
        score: 70,
        summary: 'Decent',
      ),
      DimensionScore(
        dimension: EvalDimension.expression,
        score: 60,
        summary: 'OK',
      ),
      DimensionScore(
        dimension: EvalDimension.spatialAwareness,
        score: 75,
        summary: 'Fine',
      ),
    ],
    jointFeedback: const [],
    drills: const [],
    createdAt: DateTime(2026, 3, 21),
    style: DanceStyle.hipHop,
  );
}

void main() {
  final generator = FeedbackGenerator();

  group('FeedbackGenerator', () {
    test('generates feedback for diagonal warping path (perfect timing)', () {
      final ref = _makeSequence(frameCount: 20);
      final user = _makeSequence(frameCount: 20);
      // Perfect diagonal path.
      final path = List.generate(20, (i) => (i, i));

      final feedback = generator.generate(
        refSequence: ref,
        userSequence: user,
        warpingPath: path,
        result: _makeResult(),
      );

      expect(feedback.timingInsights, isNotEmpty);
      expect(
        feedback.timingInsights.first,
        contains('consistent'),
      );
      expect(feedback.overallCoaching, isNotEmpty);
    });

    test('detects rushing in warping path', () {
      final ref = _makeSequence(frameCount: 20);
      final user = _makeSequence(frameCount: 20);
      // User rushes: maps early ref frames to late user frames.
      final path = <(int, int)>[];
      for (var i = 0; i < 20; i++) {
        // First quarter: user is ahead (steeper slope).
        if (i < 5) {
          path.add((i, (i * 2).clamp(0, 19)));
        } else {
          path.add((i, i));
        }
      }

      final feedback = generator.generate(
        refSequence: ref,
        userSequence: user,
        warpingPath: path,
        result: _makeResult(),
      );

      final hasRush = feedback.timingInsights.any(
        (t) => t.contains('rushed') || t.contains('ahead'),
      );
      expect(hasRush, isTrue);
    });

    test('generates coaching summary', () {
      final ref = _makeSequence(frameCount: 20);
      final user = _makeSequence(frameCount: 20);
      final path = List.generate(20, (i) => (i, i));

      final feedback = generator.generate(
        refSequence: ref,
        userSequence: user,
        warpingPath: path,
        result: _makeResult(overall: 90),
      );

      expect(feedback.overallCoaching, contains('Excellent'));
    });

    test('coaching mentions weakest dimension', () {
      final ref = _makeSequence(frameCount: 20);
      final user = _makeSequence(frameCount: 20);
      final path = List.generate(20, (i) => (i, i));

      final result = EvaluationResult(
        id: 'test',
        overallScore: 55,
        dimensions: const [
          DimensionScore(
            dimension: EvalDimension.timing,
            score: 80,
            summary: 'Good',
          ),
          DimensionScore(
            dimension: EvalDimension.technique,
            score: 30,
            summary: 'Needs work',
          ),
          DimensionScore(
            dimension: EvalDimension.expression,
            score: 60,
            summary: 'OK',
          ),
          DimensionScore(
            dimension: EvalDimension.spatialAwareness,
            score: 50,
            summary: 'Average',
          ),
        ],
        jointFeedback: const [],
        drills: const [],
        createdAt: DateTime(2026, 3, 21),
        style: DanceStyle.hipHop,
      );

      final feedback = generator.generate(
        refSequence: ref,
        userSequence: user,
        warpingPath: path,
        result: result,
      );

      expect(feedback.overallCoaching, contains('technique'));
    });

    test('returns empty insights for empty warping path', () {
      final ref = _makeSequence(frameCount: 20);
      final user = _makeSequence(frameCount: 20);

      final feedback = generator.generate(
        refSequence: ref,
        userSequence: user,
        warpingPath: [],
        result: _makeResult(),
      );

      expect(feedback.timingInsights, isEmpty);
      expect(feedback.jointInsights, isEmpty);
      expect(feedback.overallCoaching, isNotEmpty);
    });
  });
}
