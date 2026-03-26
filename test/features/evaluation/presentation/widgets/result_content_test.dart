import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/result_content.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';

EvaluationResult _makeResult({
  double overallScore = 75.0,
  List<JointFeedback> jointFeedback = const [],
  List<DrillRecommendation> drills = const [],
  String? coachingSummary,
  List<String> timingInsights = const [],
  List<String> jointInsights = const [],
  String? referenceName,
}) {
  return EvaluationResult(
    id: 'test',
    overallScore: overallScore,
    dimensions: [
      DimensionScore(
        dimension: EvalDimension.timing,
        score: overallScore,
        summary: 'Timing summary',
      ),
      DimensionScore(
        dimension: EvalDimension.technique,
        score: overallScore - 5,
        summary: 'Technique summary',
      ),
    ],
    jointFeedback: jointFeedback,
    drills: drills,
    createdAt: DateTime(2026, 3, 18),
    style: DanceStyle.hipHop,
    coachingSummary: coachingSummary,
    timingInsights: timingInsights,
    jointInsights: jointInsights,
    referenceName: referenceName,
  );
}

void main() {
  Widget buildSubject(EvaluationResult result, {Widget? trailing}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResultContent(result: result, trailing: trailing),
        ),
      ),
    );
  }

  group('ResultContent', () {
    testWidgets('shows ScoreIndicator and DimensionBars', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.byType(ScoreIndicator), findsOneWidget);
      expect(find.byType(DimensionBar), findsNWidgets(2));
      expect(find.text('Dimensions'), findsOneWidget);
    });

    testWidgets('shows style name', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.text('HIPHOP'), findsOneWidget);
    });

    testWidgets('shows reference name when provided', (tester) async {
      await tester.pumpWidget(
        buildSubject(_makeResult(referenceName: 'Hip Hop Basic')),
      );

      expect(find.text('Hip Hop Basic'), findsOneWidget);
    });

    testWidgets('hides reference name when null', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.text('Hip Hop Basic'), findsNothing);
    });

    testWidgets('shows coaching summary section', (tester) async {
      await tester.pumpWidget(
        buildSubject(_makeResult(coachingSummary: 'Great work!')),
      );

      expect(find.text('Coaching'), findsOneWidget);
      expect(find.text('Great work!'), findsOneWidget);
    });

    testWidgets('hides coaching section when null', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.text('Coaching'), findsNothing);
    });

    testWidgets('shows timing insights', (tester) async {
      await tester.pumpWidget(
        buildSubject(_makeResult(timingInsights: ['Beat 1 was late'])),
      );

      // "Timing" appears as both a dimension bar label and a section header.
      expect(find.text('Timing'), findsAtLeast(1));
      expect(find.text('Beat 1 was late'), findsOneWidget);
    });

    testWidgets('shows body feedback insights', (tester) async {
      await tester.pumpWidget(
        buildSubject(_makeResult(jointInsights: ['Left arm too low'])),
      );

      expect(find.text('Body Feedback'), findsOneWidget);
      expect(find.text('Left arm too low'), findsOneWidget);
    });

    testWidgets('shows joint feedback cards', (tester) async {
      final result = _makeResult(
        jointFeedback: [
          JointFeedback(
            jointName: 'leftElbow',
            landmarkIndices: [11, 13, 15],
            score: 40,
            issue: 'Arm is low',
            correction: 'Raise arm',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(result));

      expect(find.text('Joint Feedback'), findsOneWidget);
      expect(find.text('Left elbow'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Arm is low'), findsOneWidget);
      expect(find.text('Raise arm'), findsOneWidget);
    });

    testWidgets('shows drill recommendations', (tester) async {
      final result = _makeResult(
        drills: [
          DrillRecommendation(
            drillId: 'timing_clap',
            name: 'Beat Clap Drill',
            targetJoint: 'general',
            targetDimension: EvalDimension.timing,
            priority: 1,
            description: 'Clap along',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(result));

      expect(find.text('Recommended Drills'), findsOneWidget);
      expect(find.text('Beat Clap Drill'), findsOneWidget);
      expect(find.text('Clap along'), findsOneWidget);
    });

    testWidgets('hides drill section when empty', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.text('Recommended Drills'), findsNothing);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          _makeResult(),
          trailing: const Text('Custom Trailing'),
        ),
      );

      expect(find.text('Custom Trailing'), findsOneWidget);
    });

    testWidgets('dimension summaries are shown', (tester) async {
      await tester.pumpWidget(buildSubject(_makeResult()));

      expect(find.text('Timing summary'), findsOneWidget);
      expect(find.text('Technique summary'), findsOneWidget);
    });
  });
}
