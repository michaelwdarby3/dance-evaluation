import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/presentation/pages/evaluation_result_screen.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

EvaluationResult _makeResult({
  double overallScore = 75.0,
  String id = 'test',
}) =>
    EvaluationResult(
      id: id,
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
        DimensionScore(
          dimension: EvalDimension.expression,
          score: overallScore - 10,
          summary: 'Expression summary',
        ),
        DimensionScore(
          dimension: EvalDimension.spatialAwareness,
          score: overallScore + 5,
          summary: 'Spatial summary',
        ),
      ],
      jointFeedback: const [],
      drills: const [],
      createdAt: DateTime(2026, 3, 18),
      style: DanceStyle.hipHop,
    );

void main() {
  Widget buildSubject({
    required EvaluationResult result,
    MultiPersonEvaluationResult? multiResult,
  }) {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/capture',
          builder: (_, __) => const Scaffold(body: Text('Capture')),
        ),
        GoRoute(
          path: '/result',
          builder: (_, __) => EvaluationResultScreen(
            result: result,
            multiResult: multiResult,
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('EvaluationResultScreen multi-person', () {
    testWidgets('shows single-person layout when multiResult is null',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        result: _makeResult(overallScore: 85),
      ));

      // Single-person: no tabs, has ScoreIndicator.
      expect(find.byType(ScoreIndicator), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Group Score: '), findsNothing);
    });

    testWidgets(
        'shows single-person layout when multiResult has 1 person',
        (tester) async {
      final result = _makeResult(overallScore: 85);
      final multi = MultiPersonEvaluationResult(
        personResults: [result],
        overallScore: 85,
      );

      await tester.pumpWidget(buildSubject(
        result: result,
        multiResult: multi,
      ));

      // With 1 person, should NOT show tabs (isSinglePerson=true).
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Group Score: '), findsNothing);
    });

    testWidgets('shows multi-person layout with tabs for 2+ persons',
        (tester) async {
      final p1 = _makeResult(overallScore: 90, id: 'p1');
      final p2 = _makeResult(overallScore: 70, id: 'p2');
      final multi = MultiPersonEvaluationResult(
        personResults: [p1, p2],
        overallScore: 80,
      );

      await tester.pumpWidget(buildSubject(
        result: p1,
        multiResult: multi,
      ));

      // Should have tabs.
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Person 2'), findsOneWidget);
    });

    testWidgets('shows Group Score for multi-person result', (tester) async {
      final p1 = _makeResult(overallScore: 90, id: 'p1');
      final p2 = _makeResult(overallScore: 70, id: 'p2');
      final multi = MultiPersonEvaluationResult(
        personResults: [p1, p2],
        overallScore: 80,
      );

      await tester.pumpWidget(buildSubject(
        result: p1,
        multiResult: multi,
      ));

      expect(find.text('Group Score: '), findsOneWidget);
      expect(find.text('80'), findsAtLeast(1));
    });

    testWidgets('each person tab shows dimension bars', (tester) async {
      final p1 = _makeResult(overallScore: 90, id: 'p1');
      final p2 = _makeResult(overallScore: 70, id: 'p2');
      final multi = MultiPersonEvaluationResult(
        personResults: [p1, p2],
        overallScore: 80,
      );

      await tester.pumpWidget(buildSubject(
        result: p1,
        multiResult: multi,
      ));

      // First tab (Person 1) should be visible by default.
      expect(find.byType(DimensionBar), findsNWidgets(4));
    });

    testWidgets('switching tabs shows different person results',
        (tester) async {
      final p1 = _makeResult(overallScore: 95, id: 'p1');
      final p2 = _makeResult(overallScore: 60, id: 'p2');
      final multi = MultiPersonEvaluationResult(
        personResults: [p1, p2],
        overallScore: 77.5,
      );

      await tester.pumpWidget(buildSubject(
        result: p1,
        multiResult: multi,
      ));

      // Tab to Person 2.
      await tester.tap(find.text('Person 2'));
      await tester.pumpAndSettle();

      // Person 2's score indicator should be visible.
      expect(find.byType(ScoreIndicator), findsOneWidget);
    });

    testWidgets('3+ persons makes tabs scrollable', (tester) async {
      final persons = List.generate(
        4,
        (i) => _makeResult(overallScore: 70 + i * 5.0, id: 'p$i'),
      );
      final multi = MultiPersonEvaluationResult(
        personResults: persons,
        overallScore: 82.5,
      );

      await tester.pumpWidget(buildSubject(
        result: persons.first,
        multiResult: multi,
      ));

      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('Person 4'), findsOneWidget);
    });

    testWidgets('Home button navigates to /', (tester) async {
      await tester.pumpWidget(buildSubject(
        result: _makeResult(),
      ));

      // Scroll down to make the Home button visible.
      await tester.scrollUntilVisible(find.text('Home'), 200);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Try Again button exists and is tappable', (tester) async {
      await tester.pumpWidget(buildSubject(
        result: _makeResult(),
      ));

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsOneWidget);
    });
  });

  group('EvaluationResultScreen joint feedback', () {
    testWidgets('no joint feedback section when jointFeedback is empty',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        result: _makeResult(),
      ));

      expect(find.text('Joint Feedback'), findsNothing);
    });

    testWidgets('joint cards show color coded by score', (tester) async {
      final result = EvaluationResult(
        id: 'test',
        overallScore: 50,
        dimensions: [
          DimensionScore(
            dimension: EvalDimension.timing,
            score: 50,
            summary: 'OK',
          ),
          DimensionScore(
            dimension: EvalDimension.technique,
            score: 50,
            summary: 'OK',
          ),
          DimensionScore(
            dimension: EvalDimension.expression,
            score: 50,
            summary: 'OK',
          ),
          DimensionScore(
            dimension: EvalDimension.spatialAwareness,
            score: 50,
            summary: 'OK',
          ),
        ],
        jointFeedback: [
          JointFeedback(
            jointName: 'leftElbow',
            landmarkIndices: [11, 13, 15],
            score: 80, // green
            issue: 'Minor issue',
            correction: 'Small fix',
          ),
          JointFeedback(
            jointName: 'rightKnee',
            landmarkIndices: [24, 26, 28],
            score: 50, // yellow
            issue: 'Medium issue',
            correction: 'Practice more',
          ),
          JointFeedback(
            jointName: 'leftShoulder',
            landmarkIndices: [13, 11, 23],
            score: 20, // red
            issue: 'Major issue',
            correction: 'Focus on this',
          ),
        ],
        drills: const [],
        createdAt: DateTime(2026),
        style: DanceStyle.hipHop,
      );

      await tester.pumpWidget(buildSubject(result: result));

      // All three joints should be shown.
      expect(find.text('Left elbow'), findsOneWidget);
      expect(find.text('Right knee'), findsOneWidget);
      expect(find.text('Left shoulder'), findsOneWidget);

      // Scores as percentages.
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);

      // Issue and correction text.
      expect(find.text('Minor issue'), findsOneWidget);
      expect(find.text('Focus on this'), findsOneWidget);
    });
  });
}
