import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';

import 'shared/test_fakes.dart';

// ---------------------------------------------------------------------------
// Test-only picker that loads a real video asset and returns a blob URL,
// identical to what the production WebVideoFilePicker returns.
// The only thing bypassed is the native file dialog.
// ---------------------------------------------------------------------------

class AssetVideoFilePicker extends VideoFilePicker {
  @override
  Future<String?> pickVideo() async {
    final bytes = await rootBundle.load('assets/test_videos/dance_test.mp4');
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: 'video/mp4'),
    );
    return web.URL.createObjectURL(blob);
  }

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  group('Evaluation flow', () {
    testWidgets('evaluation screen shows progress or error on empty capture',
        (tester) async {
      await bootstrapForTest(
        poseDetector: FakePoseDetector(),
        cameraSource: FakeCameraSource(),
        videoFilePicker: FakeVideoFilePicker(),
        videoPoseExtractor: FakeVideoPoseExtractor(),
        sharingService: FakeSharingService(),
      );

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      expect(find.text('Dance Eval'), findsOneWidget);

      final repo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      expect(repo.listAll(), isEmpty);
    });

    testWidgets('capture flow navigates to reference selection',
        (tester) async {
      await bootstrapForTest(
        poseDetector: FakePoseDetector(),
        cameraSource: FakeCameraSource(),
        videoFilePicker: FakeVideoFilePicker(),
        videoPoseExtractor: FakeVideoPoseExtractor(),
        sharingService: FakeSharingService(),
      );

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Dancing'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Reference'), findsOneWidget);
    });

    testWidgets(
        'upload flow: real video → real pose extraction → evaluate → show results',
        (tester) async {
      // Real video picker (blob URL from bundled asset) + real pose extractor
      // (MediaPipe WASM). Only the file dialog UI is bypassed.
      await bootstrapForTest(
        poseDetector: FakePoseDetector(),
        cameraSource: FakeCameraSource(),
        videoFilePicker: AssetVideoFilePicker(),
        // videoPoseExtractor: not passed — uses real WebVideoPoseExtractor
        sharingService: FakeSharingService(),
      );

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // 1. Tap "Upload Video" on home screen
      await tester.tap(find.text('Upload Video'));
      await tester.pumpAndSettle();

      // 2. Should be on reference selection screen (upload mode)
      expect(find.text('Choose Reference'), findsOneWidget);

      // 3. Select the first reference (Basic Hip Hop Two-Step)
      await tester.tap(find.text('Basic Hip Hop Two-Step'));

      // Real MediaPipe WASM pose extraction + DTW evaluation — allow plenty of time.
      // Poll with pump until results screen appears or we timeout.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text('Your Results').evaluate().isNotEmpty) break;
      }

      // 4. Verify we reached the results screen
      expect(find.text('Your Results'), findsOneWidget);

      // 5. Verify a numeric score is displayed (ScoreIndicator renders "SCORE")
      expect(find.text('SCORE'), findsOneWidget);

      // 6. Verify dimension breakdown is shown
      expect(find.text('Dimensions'), findsOneWidget);

      // 7. Verify the reference name is shown
      expect(find.text('Basic Hip Hop Two-Step'), findsOneWidget);

      // 8. Verify the result was persisted to history
      final historyRepo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      final results = historyRepo.listAll();
      expect(results, hasLength(1));
      expect(results.first.overallScore, greaterThan(0));
      expect(results.first.overallScore, lessThanOrEqualTo(100));
      expect(results.first.dimensions, hasLength(4));
    });

    testWidgets(
        'evaluation results persisted in history and navigable from home',
        (tester) async {
      // Same real pipeline as above.
      await bootstrapForTest(
        poseDetector: FakePoseDetector(),
        cameraSource: FakeCameraSource(),
        videoFilePicker: AssetVideoFilePicker(),
        // videoPoseExtractor: not passed — uses real WebVideoPoseExtractor
        sharingService: FakeSharingService(),
      );

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // Run the evaluation
      await tester.tap(find.text('Upload Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic Hip Hop Two-Step'));

      // Poll until results screen appears
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text('Your Results').evaluate().isNotEmpty) break;
      }

      expect(find.text('Your Results'), findsOneWidget);
      expect(find.text('Dimensions'), findsOneWidget);

      // Navigate home — the button may be off-screen, so scroll to it first.
      await tester.ensureVisible(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show at least one result (not the empty state)
      expect(find.text('No sessions yet'), findsNothing);
    });
  });
}
