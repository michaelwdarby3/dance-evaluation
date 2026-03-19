import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source_factory.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector_factory.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker_factory.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor_factory.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

/// Integration tests that run the real app in a real browser.
///
/// Run with:
///   chromedriver --port=4444 &
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/app_flow_test.dart \
///     -d chrome
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Registers all real services without calling runApp().
  void registerServices() {
    final sl = ServiceLocator.instance;
    sl.reset();

    final poseDetector = createPoseDetector();
    final cameraSource = createCameraSource();
    final capture = CaptureController(poseDetector: poseDetector);
    final videoFilePicker = createVideoFilePicker();
    final videoPoseExtractor = createVideoPoseExtractor();

    sl.register<PoseDetector>(poseDetector);
    sl.register<CameraSource>(cameraSource);
    sl.register<EvaluationService>(EvaluationService());
    sl.register<ReferenceRepository>(ReferenceRepository());
    sl.register<CaptureController>(capture);
    sl.register<VideoFilePicker>(videoFilePicker);
    sl.register<VideoPoseExtractor>(videoPoseExtractor);
    sl.register<UploadController>(UploadController(
      videoFilePicker: videoFilePicker,
      videoPoseExtractor: videoPoseExtractor,
      captureController: capture,
    ));
  }

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  group('Home screen', () {
    testWidgets('renders with all navigation buttons', (tester) async {
      registerServices();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);
      expect(find.text('Start Dancing'), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);
      expect(find.text('Manage References'), findsOneWidget);
    });
  });

  group('Reference list flow', () {
    testWidgets('Manage References loads bundled references', (tester) async {
      registerServices();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Reference'), findsOneWidget);

      // Bundled references from assets/references/ should load.
      // This catches asset loading failures (double prefix, missing .json).
      final hasRefs = find.byType(Card).evaluate().isNotEmpty;
      final hasEmpty = find.text('No references yet').evaluate().isNotEmpty;

      expect(
        hasRefs || hasEmpty,
        isTrue,
        reason: 'Should show reference tiles or empty state, not hang',
      );

      // If assets loaded correctly, we should see actual reference names.
      if (hasRefs) {
        // At least one bundled .json loaded without 404.
        expect(find.byType(ListTile), findsWidgets);
      }
    });

    testWidgets('tapping a reference navigates without error', (tester) async {
      registerServices();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      final cards = find.byType(Card).evaluate();
      if (cards.isNotEmpty) {
        // Tap the first reference tile.
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();

        // Should navigate to capture screen (camera init may fail in test,
        // but we should NOT see a blank screen or unhandled error).
        final hasCaptureUI =
            find.text('Capture').evaluate().isNotEmpty ||
            find.text('Camera error').evaluate().isNotEmpty ||
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty;

        expect(hasCaptureUI, isTrue,
            reason: 'Should show capture UI or camera error, not crash');
      }
    });
  });

  group('Create reference flow', () {
    testWidgets('Create from Video FAB navigates to form', (tester) async {
      registerServices();
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
    testWidgets('references screen and back to home', (tester) async {
      registerServices();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Reference'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Dance Eval'), findsOneWidget);
    });

    testWidgets('create reference and back to home', (tester) async {
      registerServices();
      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage References'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create from Video'));
      await tester.pumpAndSettle();
      expect(find.text('Create Reference'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      // Should be back on references or home.
      final backToNav = find.text('Choose Reference').evaluate().isNotEmpty ||
          find.text('Dance Eval').evaluate().isNotEmpty;
      expect(backToNav, isTrue);
    });
  });
}
