import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/core/services/settings_service.dart';

void main() {
  group('SettingsService', () {
    late SettingsService settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService();
      await settings.initialize();
    });

    test('defaults are correct', () {
      expect(settings.audioEnabled, true);
      expect(settings.skeletonOverlay, true);
      expect(settings.referenceGhost, true);
      expect(settings.ghostOpacity, 0.5);
      expect(settings.countdownSeconds, 3);
      expect(settings.maxRecordingSeconds, 30);
      expect(settings.multiPersonDetection, true);
      expect(settings.aiCoaching, false);
      expect(settings.aiApiKey, '');
      expect(settings.mirrorPreview, true);
      expect(settings.hapticFeedback, true);
      expect(settings.defaultStyle, 'hip_hop');
      expect(settings.videoRecording, true);
    });

    test('persists boolean settings', () async {
      settings.audioEnabled = false;
      settings.skeletonOverlay = false;
      settings.referenceGhost = false;
      settings.multiPersonDetection = false;
      settings.aiCoaching = true;
      settings.mirrorPreview = false;
      settings.hapticFeedback = false;
      settings.videoRecording = false;

      // Reload from SharedPreferences
      final settings2 = SettingsService();
      await settings2.initialize();

      expect(settings2.audioEnabled, false);
      expect(settings2.skeletonOverlay, false);
      expect(settings2.referenceGhost, false);
      expect(settings2.multiPersonDetection, false);
      expect(settings2.aiCoaching, true);
      expect(settings2.mirrorPreview, false);
      expect(settings2.hapticFeedback, false);
      expect(settings2.videoRecording, false);
    });

    test('persists numeric and string settings', () async {
      settings.ghostOpacity = 0.8;
      settings.countdownSeconds = 5;
      settings.maxRecordingSeconds = 60;
      settings.defaultStyle = 'kpop';
      settings.aiApiKey = 'sk-ant-test123';

      final settings2 = SettingsService();
      await settings2.initialize();

      expect(settings2.ghostOpacity, 0.8);
      expect(settings2.countdownSeconds, 5);
      expect(settings2.maxRecordingSeconds, 60);
      expect(settings2.defaultStyle, 'kpop');
      expect(settings2.aiApiKey, 'sk-ant-test123');
    });

    test('clamps ghost opacity to 0-1 range', () {
      settings.ghostOpacity = 1.5;
      expect(settings.ghostOpacity, 1.0);

      settings.ghostOpacity = -0.5;
      expect(settings.ghostOpacity, 0.0);
    });

    test('clamps countdown seconds', () {
      settings.countdownSeconds = 0;
      expect(settings.countdownSeconds, 1);

      settings.countdownSeconds = 100;
      expect(settings.countdownSeconds, 10);
    });

    test('clamps max recording seconds', () {
      settings.maxRecordingSeconds = 1;
      expect(settings.maxRecordingSeconds, 5);

      settings.maxRecordingSeconds = 999;
      expect(settings.maxRecordingSeconds, 120);
    });

    test('resetAll restores defaults', () async {
      settings.audioEnabled = false;
      settings.countdownSeconds = 10;
      settings.aiApiKey = 'sk-test';

      await settings.resetAll();

      expect(settings.audioEnabled, true);
      expect(settings.countdownSeconds, 3);
      expect(settings.aiApiKey, '');
    });

    test('notifies listeners on change', () {
      var notified = 0;
      settings.addListener(() => notified++);

      settings.audioEnabled = false;
      expect(notified, 1);

      settings.ghostOpacity = 0.7;
      expect(notified, 2);
    });

    test('isLoaded is true after initialize', () async {
      final fresh = SettingsService();
      expect(fresh.isLoaded, false);

      SharedPreferences.setMockInitialValues({});
      await fresh.initialize();
      expect(fresh.isLoaded, true);
    });

    test('hasSeenOnboarding defaults to false', () {
      expect(settings.hasSeenOnboarding, false);
    });

    test('hasSeenOnboarding persists', () async {
      settings.hasSeenOnboarding = true;

      final settings2 = SettingsService();
      await settings2.initialize();
      expect(settings2.hasSeenOnboarding, true);
    });

    test('minConfidence defaults to 0.3', () {
      expect(settings.minConfidence, 0.3);
    });

    test('minConfidence persists', () async {
      settings.minConfidence = 0.5;

      final settings2 = SettingsService();
      await settings2.initialize();
      expect(settings2.minConfidence, 0.5);
    });

    test('minConfidence clamps to 0-1 range', () {
      settings.minConfidence = 1.5;
      expect(settings.minConfidence, 1.0);

      settings.minConfidence = -0.5;
      expect(settings.minConfidence, 0.0);
    });

    test('resetAll clears hasSeenOnboarding and minConfidence', () async {
      settings.hasSeenOnboarding = true;
      settings.minConfidence = 0.8;

      await settings.resetAll();

      expect(settings.hasSeenOnboarding, false);
      expect(settings.minConfidence, 0.3);
    });
  });
}
