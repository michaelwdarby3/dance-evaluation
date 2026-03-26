import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/history/presentation/pages/history_detail_screen.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

class _InMemoryStorage extends EvaluationStorage {
  final _store = <String, String>{};

  @override
  void save(String key, String json) => _store[key] = json;

  @override
  Map<String, String> loadAll() => Map.of(_store);

  @override
  void delete(String key) => _store.remove(key);
}

EvaluationResult _makeResult({
  String id = 'test-id',
  double overallScore = 80.0,
  String? sessionName,
  String? referenceName,
}) {
  return EvaluationResult(
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
    ],
    jointFeedback: const [],
    drills: const [],
    createdAt: DateTime(2026, 3, 18),
    style: DanceStyle.hipHop,
    sessionName: sessionName,
    referenceName: referenceName,
  );
}

void main() {
  late EvaluationHistoryRepository repo;

  setUp(() {
    repo = EvaluationHistoryRepository(storage: _InMemoryStorage());
    ServiceLocator.instance.register<EvaluationHistoryRepository>(repo);
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  Widget buildSubject(String resultId) {
    final router = GoRouter(
      initialLocation: '/history/$resultId',
      routes: [
        GoRoute(
          path: '/history',
          builder: (_, __) => const Scaffold(body: Text('History')),
        ),
        GoRoute(
          path: '/history/:id',
          builder: (context, state) => HistoryDetailScreen(
            resultId: state.pathParameters['id'] ?? '',
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('HistoryDetailScreen', () {
    testWidgets('shows result content when found', (tester) async {
      final result = _makeResult(id: 'abc', overallScore: 85);
      repo.save(result);

      await tester.pumpWidget(buildSubject('abc'));

      expect(find.byType(ScoreIndicator), findsOneWidget);
      expect(find.text('Timing summary'), findsOneWidget);
    });

    testWidgets('uses sessionName as title when available', (tester) async {
      final result = _makeResult(
        id: 'named',
        sessionName: 'My Practice',
      );
      repo.save(result);

      await tester.pumpWidget(buildSubject('named'));

      expect(find.text('My Practice'), findsOneWidget);
    });

    testWidgets('uses referenceName as title fallback', (tester) async {
      final result = _makeResult(
        id: 'ref-named',
        referenceName: 'Hip Hop Basic',
      );
      repo.save(result);

      await tester.pumpWidget(buildSubject('ref-named'));

      // Appears in both AppBar title and ResultContent reference name.
      expect(find.text('Hip Hop Basic'), findsAtLeast(1));
    });

    testWidgets('shows error state when result not found', (tester) async {
      await tester.pumpWidget(buildSubject('nonexistent'));

      expect(find.text('Session not found'), findsOneWidget);
      expect(find.text('Back to History'), findsOneWidget);
    });

    testWidgets('Back to History button navigates to /history',
        (tester) async {
      await tester.pumpWidget(buildSubject('nonexistent'));

      await tester.tap(find.text('Back to History'));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
    });
  });
}
