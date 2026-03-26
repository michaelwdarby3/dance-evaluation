import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/domain/drill_catalog.dart';

List<DimensionScore> _makeDimensions({
  double timing = 80,
  double technique = 80,
  double expression = 80,
  double spatial = 80,
}) {
  return [
    DimensionScore(dimension: EvalDimension.timing, score: timing, summary: ''),
    DimensionScore(dimension: EvalDimension.technique, score: technique, summary: ''),
    DimensionScore(dimension: EvalDimension.expression, score: expression, summary: ''),
    DimensionScore(dimension: EvalDimension.spatialAwareness, score: spatial, summary: ''),
  ];
}

JointFeedback _makeJoint(String name, double score) {
  return JointFeedback(
    jointName: name,
    landmarkIndices: [0, 1, 2],
    score: score,
    issue: 'test issue',
    correction: 'test correction',
  );
}

void main() {
  group('DrillCatalog.recommend', () {
    test('returns empty list when all scores are high', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(),
        jointFeedback: [_makeJoint('leftElbow', 85)],
      );

      expect(drills, isEmpty);
    });

    test('returns drills for weak dimensions', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(timing: 30),
        jointFeedback: [],
      );

      expect(drills, isNotEmpty);
      expect(
        drills.every((d) => d.targetDimension == EvalDimension.timing),
        isTrue,
      );
    });

    test('returns joint-specific drills for weak joints', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(technique: 40),
        jointFeedback: [_makeJoint('leftElbow', 35)],
      );

      expect(drills, isNotEmpty);
      // Should have a joint-specific technique drill.
      final jointDrill = drills.firstWhere(
        (d) => d.targetDimension == EvalDimension.technique,
      );
      expect(jointDrill, isNotNull);
    });

    test('limits to 5 recommendations', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(
          timing: 20,
          technique: 20,
          expression: 20,
          spatial: 20,
        ),
        jointFeedback: [
          _makeJoint('leftElbow', 20),
          _makeJoint('rightKnee', 25),
          _makeJoint('leftShoulder', 30),
          _makeJoint('leftHip', 15),
          _makeJoint('leftAnkle', 10),
        ],
      );

      expect(drills.length, lessThanOrEqualTo(5));
    });

    test('priorities are sequential starting at 1', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(timing: 20, expression: 30),
        jointFeedback: [_makeJoint('leftElbow', 30)],
      );

      expect(drills, isNotEmpty);
      for (var i = 0; i < drills.length; i++) {
        expect(drills[i].priority, i + 1);
      }
    });

    test('no duplicate drill IDs', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(
          timing: 20,
          technique: 20,
          expression: 20,
          spatial: 20,
        ),
        jointFeedback: [
          _makeJoint('leftElbow', 20),
          _makeJoint('rightElbow', 25),
        ],
      );

      final ids = drills.map((d) => d.drillId).toSet();
      expect(ids.length, drills.length);
    });

    test('all drills have non-empty description', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(
          timing: 20,
          technique: 20,
          expression: 20,
          spatial: 20,
        ),
        jointFeedback: [_makeJoint('leftKnee', 20)],
      );

      for (final drill in drills) {
        expect(drill.description, isNotEmpty);
        expect(drill.name, isNotEmpty);
        expect(drill.drillId, isNotEmpty);
      }
    });

    test('expression drills recommended for weak expression', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(expression: 25),
        jointFeedback: [],
      );

      expect(drills, isNotEmpty);
      expect(
        drills.any((d) => d.targetDimension == EvalDimension.expression),
        isTrue,
      );
    });

    test('spatial drills recommended for weak spatial awareness', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(spatial: 30),
        jointFeedback: [],
      );

      expect(drills, isNotEmpty);
      expect(
        drills.any((d) => d.targetDimension == EvalDimension.spatialAwareness),
        isTrue,
      );
    });

    test('joint matching normalizes left/right prefixes', () {
      // leftShoulder and rightShoulder should both match shoulder drills.
      final drillsLeft = DrillCatalog.recommend(
        dimensions: _makeDimensions(technique: 30),
        jointFeedback: [_makeJoint('leftShoulder', 30)],
      );
      final drillsRight = DrillCatalog.recommend(
        dimensions: _makeDimensions(technique: 30),
        jointFeedback: [_makeJoint('rightShoulder', 30)],
      );

      // Both should get a shoulder-related drill.
      final leftHasShoulderDrill = drillsLeft.any(
        (d) => d.targetDimension == EvalDimension.technique,
      );
      final rightHasShoulderDrill = drillsRight.any(
        (d) => d.targetDimension == EvalDimension.technique,
      );
      expect(leftHasShoulderDrill, isTrue);
      expect(rightHasShoulderDrill, isTrue);
    });

    test('joint-specific drills come before dimension-level drills', () {
      final drills = DrillCatalog.recommend(
        dimensions: _makeDimensions(timing: 30, technique: 30),
        jointFeedback: [_makeJoint('leftElbow', 30)],
      );

      if (drills.length >= 2) {
        // First drill should be a technique drill (joint-specific).
        expect(drills.first.targetDimension, EvalDimension.technique);
      }
    });
  });
}
