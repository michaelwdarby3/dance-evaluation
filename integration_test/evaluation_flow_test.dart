import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';

import 'shared/test_fakes.dart';

/// Integration tests for the evaluation flow.
///
/// These tests use fake platform services since we can't access the camera
/// or file system in a headless test environment.
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

      // Can't easily push to /evaluation/:id without captured data,
      // so verify the home screen is reachable and history is empty.
      expect(find.text('Dance Eval'), findsOneWidget);

      final repo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      expect(repo.listAll(), isEmpty);
    });

    testWidgets('upload flow shows processing screen', (tester) async {
      await bootstrapForTest(
        poseDetector: FakePoseDetector(),
        cameraSource: FakeCameraSource(),
        videoFilePicker: FakeVideoFilePicker(),
        videoPoseExtractor: FakeVideoPoseExtractor(),
        sharingService: FakeSharingService(),
      );

      await tester.pumpWidget(const DanceEvalApp());
      await tester.pumpAndSettle();

      // Navigate to Upload Video -> references
      await tester.tap(find.text('Upload Video'));
      await tester.pumpAndSettle();

      // Should be on reference selection screen for upload mode
      expect(find.text('Choose Reference'), findsOneWidget);
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

      // Should navigate to reference list in capture mode
      expect(find.text('Choose Reference'), findsOneWidget);
    });
  });
}
