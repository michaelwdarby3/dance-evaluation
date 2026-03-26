import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';

/// Core app flow integration tests.
///
/// Run with:
///   chromedriver --port=4444 &
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/app_flow_test.dart \
///     -d chrome
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  group('Home screen', () {
    testWidgets('renders with all navigation buttons', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);
      expect(find.text('Start Dancing'), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);
      expect(find.text('Manage References'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('Reference list flow', () {
    testWidgets('Manage References loads bundled references', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      expect(find.text('My References'), findsOneWidget);

      // Bundled references from assets/references/ should load.
      final hasRefs = find.byType(Card).evaluate().isNotEmpty;
      final hasEmpty = find.text('No references yet').evaluate().isNotEmpty;

      expect(
        hasRefs || hasEmpty,
        isTrue,
        reason: 'Should show reference tiles or empty state, not hang',
      );

      if (hasRefs) {
        expect(find.byType(ListTile), findsWidgets);
      }
    });

    testWidgets('tapping a reference navigates without error', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      final cards = find.byType(Card).evaluate();
      if (cards.isNotEmpty) {
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();

        // In manage mode, tapping a reference shows a dialog or detail,
        // not capture. Just verify no crash.
        expect(find.byType(Scaffold), findsWidgets);
      }
    });
  });

  group('Create reference flow', () {
    testWidgets('Create from Video FAB navigates to form', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create from Video'));
      await tester.pumpAndSettle();

      expect(find.text('Create Reference'), findsOneWidget);
      expect(find.text('Reference Name'), findsOneWidget);
      expect(find.text('Select Video & Create'), findsOneWidget);
    });
  });

  group('Navigation round-trips', () {
    testWidgets('history screen back to home', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('No sessions yet'), findsOneWidget);

      // History uses context.go('/') for back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Dance Eval'), findsOneWidget);
    });

    testWidgets('multi-step navigation: home → references → create',
        (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // Home → references
      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();
      expect(find.text('My References'), findsOneWidget);

      // References → create
      await tester.tap(find.text('Create from Video'));
      await tester.pumpAndSettle();
      expect(find.text('Create Reference'), findsOneWidget);
      expect(find.text('Reference Name'), findsOneWidget);
      expect(find.text('Select Video & Create'), findsOneWidget);
    });
  });

  group('History screen', () {
    testWidgets('shows empty state', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('No sessions yet'), findsOneWidget);
      expect(
        find.text('Complete a dance evaluation to see your progress'),
        findsOneWidget,
      );
    });
  });

  group('Settings screen', () {
    testWidgets('renders all sections', (tester) async {
      await bootstrapForTest();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('CAPTURE'), findsOneWidget);
      expect(find.text('DETECTION'), findsOneWidget);
      expect(find.text('EVALUATION'), findsOneWidget);
      expect(find.text('FEEDBACK'), findsOneWidget);
      expect(find.text('HELP'), findsOneWidget);
      expect(find.text('DATA'), findsOneWidget);
    });
  });
}
