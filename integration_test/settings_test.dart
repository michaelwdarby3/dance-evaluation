import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';

/// Integration tests for the settings screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  Future<void> navigateToSettings(WidgetTester tester) async {
    await bootstrapForTest();
    await tester.pumpWidget(const DanceEvalApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  group('Settings screen', () {
    testWidgets('renders all toggle groups', (tester) async {
      await navigateToSettings(tester);

      // Section headers
      expect(find.text('CAPTURE'), findsOneWidget);
      expect(find.text('DETECTION'), findsOneWidget);
      expect(find.text('EVALUATION'), findsOneWidget);
      expect(find.text('FEEDBACK'), findsOneWidget);
      expect(find.text('HELP'), findsOneWidget);
      expect(find.text('DATA'), findsOneWidget);

      // Key toggle items
      expect(find.text('Audio Playback'), findsOneWidget);
      expect(find.text('Skeleton Overlay'), findsOneWidget);
      expect(find.text('Multi-Person Detection'), findsOneWidget);
      expect(find.text('AI Coaching'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);
    });

    testWidgets('toggling a switch changes value', (tester) async {
      await navigateToSettings(tester);

      final settings = ServiceLocator.instance.get<SettingsService>();
      expect(settings.audioEnabled, isTrue); // default

      // Find and tap the Audio Playback switch
      final audioSwitch = find.widgetWithText(SwitchListTile, 'Audio Playback');
      await tester.tap(audioSwitch);
      await tester.pumpAndSettle();

      expect(settings.audioEnabled, isFalse);
    });

    testWidgets('Replay Tutorial navigates to onboarding', (tester) async {
      await navigateToSettings(tester);

      // Need to scroll to find Replay Tutorial
      await tester.scrollUntilVisible(
        find.text('Replay Tutorial'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Replay Tutorial'));
      await tester.pumpAndSettle();

      expect(find.text('Record Your Dance'), findsOneWidget);
    });
  });
}
