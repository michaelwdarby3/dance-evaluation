import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';

void main() {
  group('EvaluationResult serialization', () {
    EvaluationResult _makeResult({
      String? sessionName,
      String? referenceName,
      String? coachingSummary,
      List<DrillRecommendation> drills = const [],
    }) {
      return EvaluationResult(
        id: 'test-id',
        overallScore: 85.0,
        dimensions: [
          DimensionScore(
            dimension: EvalDimension.timing,
            score: 80,
            summary: 'Good timing',
          ),
        ],
        jointFeedback: const [],
        drills: drills,
        createdAt: DateTime(2026, 3, 18, 10, 30),
        style: DanceStyle.hipHop,
        sessionName: sessionName,
        referenceName: referenceName,
        timingInsights: const ['Insight 1'],
        jointInsights: const ['Joint insight 1'],
        coachingSummary: coachingSummary,
      );
    }

    test('round-trips with all fields', () {
      final original = _makeResult(
        sessionName: 'My Session',
        referenceName: 'Hip Hop Basic',
        coachingSummary: 'Great job!',
      );

      final json = original.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.overallScore, original.overallScore);
      expect(restored.sessionName, 'My Session');
      expect(restored.referenceName, 'Hip Hop Basic');
      expect(restored.coachingSummary, 'Great job!');
      expect(restored.timingInsights, ['Insight 1']);
      expect(restored.jointInsights, ['Joint insight 1']);
      expect(restored.style, DanceStyle.hipHop);
    });

    test('round-trips with null sessionName', () {
      final original = _makeResult();
      final json = original.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.sessionName, isNull);
    });

    test('round-trips with null referenceName and coachingSummary', () {
      final original = _makeResult();
      final json = original.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.referenceName, isNull);
      expect(restored.coachingSummary, isNull);
    });

    test('fromJson handles missing timingInsights gracefully', () {
      final json = _makeResult().toJson();
      json.remove('timingInsights');
      json.remove('jointInsights');

      final restored = EvaluationResult.fromJson(json);
      expect(restored.timingInsights, isEmpty);
      expect(restored.jointInsights, isEmpty);
    });
  });

  group('DrillRecommendation serialization', () {
    test('round-trips with description', () {
      const drill = DrillRecommendation(
        drillId: 'drill_1',
        name: 'Test Drill',
        targetJoint: 'leftElbow',
        targetDimension: EvalDimension.technique,
        priority: 1,
        description: 'Practice this drill daily.',
      );

      final json = drill.toJson();
      final restored = DrillRecommendation.fromJson(json);

      expect(restored.drillId, 'drill_1');
      expect(restored.name, 'Test Drill');
      expect(restored.description, 'Practice this drill daily.');
      expect(restored.targetDimension, EvalDimension.technique);
      expect(restored.priority, 1);
    });

    test('fromJson handles missing description', () {
      final json = {
        'drillId': 'drill_2',
        'name': 'No Desc',
        'targetJoint': 'general',
        'targetDimension': 'timing',
        'priority': 2,
      };

      final restored = DrillRecommendation.fromJson(json);
      expect(restored.description, '');
    });

    test('default description is empty string', () {
      const drill = DrillRecommendation(
        drillId: 'd',
        name: 'D',
        targetJoint: 'general',
        targetDimension: EvalDimension.timing,
        priority: 1,
      );

      expect(drill.description, '');
    });
  });

  group('EvaluationResult with drills', () {
    test('round-trips drills list', () {
      final result = EvaluationResult(
        id: 'test',
        overallScore: 50,
        dimensions: const [],
        jointFeedback: const [],
        drills: const [
          DrillRecommendation(
            drillId: 'a',
            name: 'A',
            targetJoint: 'general',
            targetDimension: EvalDimension.timing,
            priority: 1,
            description: 'Desc A',
          ),
          DrillRecommendation(
            drillId: 'b',
            name: 'B',
            targetJoint: 'leftKnee',
            targetDimension: EvalDimension.technique,
            priority: 2,
            description: 'Desc B',
          ),
        ],
        createdAt: DateTime(2026),
        style: DanceStyle.hipHop,
      );

      final json = result.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.drills.length, 2);
      expect(restored.drills[0].drillId, 'a');
      expect(restored.drills[0].description, 'Desc A');
      expect(restored.drills[1].drillId, 'b');
      expect(restored.drills[1].description, 'Desc B');
    });
  });
}
