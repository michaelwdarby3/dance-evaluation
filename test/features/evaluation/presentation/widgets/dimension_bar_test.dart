import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';

void main() {
  Widget buildSubject(EvalDimension dimension, double score) {
    return MaterialApp(
      home: Scaffold(
        body: DimensionBar(dimension: dimension, score: score),
      ),
    );
  }

  group('DimensionBar', () {
    testWidgets('displays "Timing" label for timing dimension', (tester) async {
      await tester.pumpWidget(buildSubject(EvalDimension.timing, 75));

      expect(find.text('Timing'), findsOneWidget);
    });

    testWidgets('displays "Technique" label for technique dimension',
        (tester) async {
      await tester.pumpWidget(buildSubject(EvalDimension.technique, 60));

      expect(find.text('Technique'), findsOneWidget);
    });

    testWidgets('displays "Expression" label for expression dimension',
        (tester) async {
      await tester.pumpWidget(buildSubject(EvalDimension.expression, 50));

      expect(find.text('Expression'), findsOneWidget);
    });

    testWidgets('displays "Spatial" label for spatialAwareness dimension',
        (tester) async {
      await tester
          .pumpWidget(buildSubject(EvalDimension.spatialAwareness, 80));

      expect(find.text('Spatial'), findsOneWidget);
    });

    testWidgets('shows the score number', (tester) async {
      await tester.pumpWidget(buildSubject(EvalDimension.timing, 72));

      expect(find.text('72'), findsOneWidget);
    });

    testWidgets('renders a LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(buildSubject(EvalDimension.timing, 50));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('all four dimensions render without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DimensionBar(dimension: EvalDimension.timing, score: 80),
                DimensionBar(dimension: EvalDimension.technique, score: 70),
                DimensionBar(dimension: EvalDimension.expression, score: 65),
                DimensionBar(
                    dimension: EvalDimension.spatialAwareness, score: 72),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Timing'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Expression'), findsOneWidget);
      expect(find.text('Spatial'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });
  });
}
