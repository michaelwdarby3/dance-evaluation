import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/presentation/pages/evaluation_result_screen.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

EvaluationResult makeTestResult({double overallScore = 75.0}) =>
    EvaluationResult(
      id: 'test-1',
      overallScore: overallScore,
      dimensions: [
        DimensionScore(
            dimension: EvalDimension.timing, score: 80, summary: 'Good timing'),
        DimensionScore(
            dimension: EvalDimension.technique,
            score: 70,
            summary: 'Decent technique'),
        DimensionScore(
            dimension: EvalDimension.expression,
            score: 65,
            summary: 'Fair expression'),
        DimensionScore(
            dimension: EvalDimension.spatialAwareness,
            score: 72,
            summary: 'OK spatial'),
      ],
      jointFeedback: [
        JointFeedback(
          jointName: 'leftElbow',
          landmarkIndices: [11, 13, 15],
          score: 45,
          issue: 'Elbow too low',
          correction: 'Raise your left elbow',
        ),
        JointFeedback(
          jointName: 'rightKnee',
          landmarkIndices: [24, 26, 28],
          score: 60,
          issue: 'Knee angle off',
          correction: 'Bend more',
        ),
      ],
      drills: [],
      createdAt: DateTime(2026, 3, 17),
      style: DanceStyle.hipHop,
    );

Widget buildSubject({double overallScore = 75.0}) {
  return MaterialApp(
    home: EvaluationResultScreen(result: makeTestResult(overallScore: overallScore)),
  );
}

void main() {
  group('EvaluationResultScreen', () {
    testWidgets('displays overall score via ScoreIndicator', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(ScoreIndicator), findsOneWidget);
      // The rounded overall score text
      expect(find.text('75'), findsAny);
    });

    testWidgets('displays all 4 dimension bars', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(DimensionBar), findsNWidgets(4));
      expect(find.text('Timing'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Expression'), findsOneWidget);
      expect(find.text('Spatial'), findsOneWidget);
    });

    testWidgets('displays joint feedback cards', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Joint Feedback'), findsOneWidget);
      // Joint names are formatted from camelCase
      expect(find.text('Left elbow'), findsOneWidget);
      expect(find.text('Right knee'), findsOneWidget);
    });

    testWidgets('shows Try Again button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsOneWidget);
    });

    testWidgets('shows Home button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
    });

    testWidgets('joint feedback card shows score, issue, and correction',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Score percentage for leftElbow (45)
      expect(find.text('45%'), findsOneWidget);
      // Score percentage for rightKnee (60)
      expect(find.text('60%'), findsOneWidget);

      // Issue and correction text
      expect(find.text('Elbow too low'), findsOneWidget);
      expect(find.text('Raise your left elbow'), findsOneWidget);
      expect(find.text('Knee angle off'), findsOneWidget);
      expect(find.text('Bend more'), findsOneWidget);
    });

    testWidgets('displays dimension summaries', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Good timing'), findsOneWidget);
      expect(find.text('Decent technique'), findsOneWidget);
      expect(find.text('Fair expression'), findsOneWidget);
      expect(find.text('OK spatial'), findsOneWidget);
    });

    testWidgets('displays dance style label', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('HIPHOP'), findsOneWidget);
    });
  });
}
