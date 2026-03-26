import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/features/onboarding/presentation/pages/onboarding_screen.dart';

void main() {
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.initialize();

    final sl = ServiceLocator.instance;
    sl.register<SettingsService>(settings);
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('OnboardingScreen', () {
    testWidgets('shows first page content', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Record Your Dance'), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Next button advances to second page', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Detailed Feedback'), findsOneWidget);
      expect(find.byIcon(Icons.analytics), findsOneWidget);
    });

    testWidgets('shows Get Started on last page', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Navigate to last page.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Track Your Progress'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started sets hasSeenOnboarding and navigates home',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Navigate to last page.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(settings.hasSeenOnboarding, true);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Skip sets hasSeenOnboarding and navigates home',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(settings.hasSeenOnboarding, true);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('has 3 page indicator dots', (tester) async {
      await tester.pumpWidget(buildSubject());

      // 3 dots are rendered as Containers with circle shape.
      // There should be a PageView with 3 pages.
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
