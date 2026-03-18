import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StyleProfiles weight sums', () {
    for (final style in DanceStyle.values) {
      test('${style.name} weights sum to 1.0', () {
        final profile = StyleProfiles.styleProfiles[style];
        expect(profile, isNotNull, reason: '$style must have a profile');

        final sum = profile!.weights.values.fold(0.0, (a, b) => a + b);
        expect(sum, closeTo(1.0, 0.001));
      });
    }
  });

  group('StyleProfiles completeness', () {
    test('all 4 dance styles are present', () {
      expect(StyleProfiles.styleProfiles.length, equals(4));
      expect(StyleProfiles.styleProfiles.containsKey(DanceStyle.hipHop), isTrue);
      expect(StyleProfiles.styleProfiles.containsKey(DanceStyle.kPop), isTrue);
      expect(
        StyleProfiles.styleProfiles.containsKey(DanceStyle.contemporary),
        isTrue,
      );
      expect(
        StyleProfiles.styleProfiles.containsKey(DanceStyle.freestyle),
        isTrue,
      );
    });
  });

  group('StyleWeights.weightedScore', () {
    test('computes correct weighted sum', () {
      final weights = StyleWeights({
        EvalDimension.timing: 0.30,
        EvalDimension.technique: 0.30,
        EvalDimension.expression: 0.20,
        EvalDimension.spatialAwareness: 0.20,
      });

      final scores = {
        EvalDimension.timing: 80.0,
        EvalDimension.technique: 90.0,
        EvalDimension.expression: 70.0,
        EvalDimension.spatialAwareness: 60.0,
      };

      // 0.30*80 + 0.30*90 + 0.20*70 + 0.20*60 = 24 + 27 + 14 + 12 = 77.0
      expect(weights.weightedScore(scores), closeTo(77.0, 0.01));
    });

    test('missing dimension scores treated as 0.0', () {
      final weights = StyleWeights({
        EvalDimension.timing: 0.50,
        EvalDimension.technique: 0.50,
      });

      final scores = {
        EvalDimension.timing: 100.0,
        // technique is missing
      };

      // 0.50*100 + 0.50*0 = 50.0
      expect(weights.weightedScore(scores), closeTo(50.0, 0.01));
    });

    test('all zeros gives zero', () {
      final weights = StyleWeights({
        EvalDimension.timing: 0.25,
        EvalDimension.technique: 0.25,
        EvalDimension.expression: 0.25,
        EvalDimension.spatialAwareness: 0.25,
      });

      final scores = {
        EvalDimension.timing: 0.0,
        EvalDimension.technique: 0.0,
        EvalDimension.expression: 0.0,
        EvalDimension.spatialAwareness: 0.0,
      };

      expect(weights.weightedScore(scores), closeTo(0.0, 0.01));
    });

    test('all perfect scores gives 100', () {
      final weights = StyleWeights({
        EvalDimension.timing: 0.25,
        EvalDimension.technique: 0.25,
        EvalDimension.expression: 0.25,
        EvalDimension.spatialAwareness: 0.25,
      });

      final scores = {
        EvalDimension.timing: 100.0,
        EvalDimension.technique: 100.0,
        EvalDimension.expression: 100.0,
        EvalDimension.spatialAwareness: 100.0,
      };

      expect(weights.weightedScore(scores), closeTo(100.0, 0.01));
    });

    test('operator [] returns 0.0 for missing dimension', () {
      final weights = StyleWeights({
        EvalDimension.timing: 0.5,
      });
      expect(weights[EvalDimension.timing], closeTo(0.5, 0.001));
      expect(weights[EvalDimension.expression], closeTo(0.0, 0.001));
    });
  });
}
