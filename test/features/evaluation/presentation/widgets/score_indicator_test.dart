import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

void main() {
  Widget buildSubject(double score) {
    return MaterialApp(
      home: Scaffold(
        body: ScoreIndicator(score: score),
      ),
    );
  }

  group('ScoreIndicator', () {
    testWidgets('renders the rounded score number', (tester) async {
      await tester.pumpWidget(buildSubject(85.3));

      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('shows SCORE label', (tester) async {
      await tester.pumpWidget(buildSubject(50));

      expect(find.text('SCORE'), findsOneWidget);
    });

    testWidgets('high score (85) renders without error', (tester) async {
      await tester.pumpWidget(buildSubject(85));

      expect(find.text('85'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
    });

    testWidgets('low score (25) renders without error', (tester) async {
      await tester.pumpWidget(buildSubject(25));

      expect(find.text('25'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
    });

    testWidgets('zero score renders without error', (tester) async {
      await tester.pumpWidget(buildSubject(0));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
    });

    testWidgets('score of 100 renders without error', (tester) async {
      await tester.pumpWidget(buildSubject(100));

      expect(find.text('100'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
    });
  });
}
