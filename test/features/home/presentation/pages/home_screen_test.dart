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
          path: '/references/:mode',
          builder: (context, state) => Scaffold(
            body: Text('References ${state.pathParameters['mode']}'),
          ),
        ),
        GoRoute(
          path: '/create-reference',
          builder: (context, state) =>
              const Scaffold(body: Text('Create Reference')),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) =>
              const Scaffold(body: Text('History')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Settings Page')),
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
    });

    testWidgets('Start Dancing navigates to reference selection',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('References capture'), findsOneWidget);
    });

    testWidgets('Upload Video navigates to reference selection',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Upload Video'));
      await tester.pumpAndSettle();

      expect(find.text('References upload'), findsOneWidget);
    });

    testWidgets('Manage References navigates to references/manage',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      expect(find.text('References manage'), findsOneWidget);
    });

    testWidgets('Settings navigates to settings page', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
    });
  });
}
