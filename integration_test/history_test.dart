import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';

/// Integration tests for the history screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  EvaluationResult _makeResult({
    required String id,
    required double score,
    String? referenceName,
  }) {
    return EvaluationResult(
      id: id,
      overallScore: score,
      dimensions: [
        const DimensionScore(
            dimension: EvalDimension.timing, score: 75, summary: 'Good timing'),
        const DimensionScore(
            dimension: EvalDimension.technique,
            score: 65,
            summary: 'Decent technique'),
        const DimensionScore(
            dimension: EvalDimension.expression,
            score: 80,
            summary: 'Great expression'),
        const DimensionScore(
            dimension: EvalDimension.spatialAwareness,
            score: 70,
            summary: 'Good awareness'),
      ],
      jointFeedback: const [],
      drills: const [],
      createdAt: DateTime(2026, 3, 20, 14, 30),
      style: DanceStyle.hipHop,
      referenceName: referenceName ?? 'Hip Hop Basic',
    );
  }

  group('History screen', () {
    testWidgets('shows empty state when no results', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('shows seeded results', (tester) async {
      await bootstrapForTest();

      // Seed data after bootstrap
      final repo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      repo.save(_makeResult(id: 'test-1', score: 72.5));
      repo.save(_makeResult(id: 'test-2', score: 85.0));

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show session cards, not empty state
      expect(find.text('No sessions yet'), findsNothing);
      expect(find.text('Hip Hop Basic'), findsWidgets);
    });

    testWidgets('tapping a result navigates to detail screen', (tester) async {
      await bootstrapForTest();

      final repo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      repo.save(_makeResult(id: 'detail-test', score: 78.0));

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Tap the session card
      await tester.tap(find.text('Hip Hop Basic').first);
      await tester.pumpAndSettle();

      // Should navigate to detail screen showing the result
      // The detail screen shows the result content with dimensions
      expect(find.byType(Scaffold), findsWidgets);

      // Should show score dimensions
      final hasTimingText = find.text('Timing').evaluate().isNotEmpty;
      final hasTechniqueText = find.text('Technique').evaluate().isNotEmpty;
      expect(hasTimingText || hasTechniqueText, isTrue,
          reason: 'Detail screen should show dimension scores');
    });
  });
}
