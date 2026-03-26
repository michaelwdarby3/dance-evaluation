import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';

/// Integration tests for the onboarding flow.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  group('Onboarding', () {
    testWidgets('first launch shows onboarding', (tester) async {
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      expect(find.text('Record Your Dance'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Next button advances through pages', (tester) async {
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // Page 1
      expect(find.text('Record Your Dance'), findsOneWidget);

      // Advance to page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Get Detailed Feedback'), findsOneWidget);

      // Advance to page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Track Your Progress'), findsOneWidget);

      // On last page, button says "Get Started"
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Skip button goes to home', (tester) async {
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);
    });

    testWidgets('Get Started on last page goes to home', (tester) async {
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // Advance to last page
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);
    });

    testWidgets('after completing, re-bootstrapping goes directly to home',
        (tester) async {
      // First run: complete onboarding
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Dance Eval'), findsOneWidget);

      // Second run: should skip onboarding because hasSeenOnboarding is now
      // persisted. Re-bootstrap with skipOnboarding: false to test the
      // settings persistence (SharedPreferences mock retains data).
      ServiceLocator.instance.reset();
      await bootstrapForTest(skipOnboarding: false);
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);
    });
  });
}
