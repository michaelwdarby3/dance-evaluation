import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/features/home/presentation/pages/home_screen.dart';

void main() {
  Widget buildSubject() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/capture',
          builder: (context, state) => const Scaffold(body: Text('Capture')),
        ),
        GoRoute(
          path: '/upload',
          builder: (context, state) => const Scaffold(body: Text('Upload')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('HomeScreen', () {
    testWidgets('displays "Dance Eval" title text', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Dance Eval'), findsOneWidget);
    });

    testWidgets('displays subtitle "AI-powered movement evaluation"',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('AI-powered movement evaluation'), findsOneWidget);
    });

    testWidgets('has "Start Dancing" button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Start Dancing'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('has "Upload Video" button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Upload Video'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('Start Dancing button navigates to /capture', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Capture'), findsOneWidget);
    });

    testWidgets('Upload Video button navigates to /upload', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.text('Upload'), findsOneWidget);
    });
  });
}
