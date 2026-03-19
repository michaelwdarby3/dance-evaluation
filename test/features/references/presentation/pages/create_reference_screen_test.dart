import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/references/presentation/pages/create_reference_screen.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakePoseDetector extends PoseDetector {
  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => null;
  @override
  void dispose() {}
}

class FakeVideoFilePicker extends VideoFilePicker {
  String? videoUrlToReturn;

  @override
  Future<String?> pickVideo() async => videoUrlToReturn;

  @override
  void dispose() {}
}

class FakeVideoPoseExtractor extends VideoPoseExtractor {
  List<PoseFrame> framesToEmit = [];
  Duration durationToReturn = const Duration(seconds: 5);
  bool throwOnExtract = false;

  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    if (throwOnExtract) throw Exception('Extraction failed');
    for (var i = 0; i < framesToEmit.length; i++) {
      onProgress((i + 1) / framesToEmit.length);
      onFrame(framesToEmit[i]);
    }
    return durationToReturn;
  }

  @override
  void dispose() {}
}

PoseFrame _makeFrame(Duration ts) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      33,
      (_) => const Landmark(x: 0.5, y: 0.5, z: 0, visibility: 0.9),
    ),
  );
}

void main() {
  late FakeVideoFilePicker picker;
  late FakeVideoPoseExtractor extractor;
  late ReferenceRepository repo;

  setUp(() {
    picker = FakeVideoFilePicker();
    extractor = FakeVideoPoseExtractor();
    repo = ReferenceRepository();

    final sl = ServiceLocator.instance;
    sl.reset();
    sl.register<VideoFilePicker>(picker);
    sl.register<VideoPoseExtractor>(extractor);
    sl.register<ReferenceRepository>(repo);
    sl.register<CaptureController>(
      CaptureController(poseDetector: FakePoseDetector()),
    );
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/create-reference',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/create-reference',
          builder: (_, __) => const CreateReferenceScreen(),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('CreateReferenceScreen', () {
    testWidgets('shows form initially with required fields', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Reference Name'), findsOneWidget);
      expect(find.text('Dance Style'), findsOneWidget);
      expect(find.text('Difficulty'), findsOneWidget);
      expect(find.text('BPM (optional)'), findsOneWidget);
      expect(find.text('Select Video & Create'), findsOneWidget);
    });

    testWidgets('has instructional text explaining purpose', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.textContaining('Upload a dance video to create a reference'),
        findsOneWidget,
      );
    });

    testWidgets('returns to form when user cancels file picker',
        (tester) async {
      picker.videoUrlToReturn = null;

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      // Should still show the form.
      expect(find.text('Reference Name'), findsOneWidget);
    });

    testWidgets('shows processing state during extraction', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
        _makeFrame(const Duration(milliseconds: 200)),
        _makeFrame(const Duration(milliseconds: 300)),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      // After extraction completes, should show done state.
      expect(find.text('Reference created!'), findsOneWidget);
      expect(find.text('3 frames extracted'), findsOneWidget);
    });

    testWidgets('saves reference to repository on success', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
        _makeFrame(const Duration(milliseconds: 200)),
      ];

      await tester.pumpWidget(buildSubject());

      // Enter a name.
      await tester.enterText(
        find.widgetWithText(TextField, 'Reference Name'),
        'My Custom Dance',
      );

      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      // Verify reference was saved.
      final available = await repo.listAvailable();
      expect(available, isNotEmpty);

      // Load and verify name.
      final loaded = await repo.load(available.first);
      expect(loaded.name, 'My Custom Dance');
    });

    testWidgets('generates default name when none provided', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];

      await tester.pumpWidget(buildSubject());

      // Don't enter a name — leave it empty.
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      // Should still succeed with auto-generated name.
      expect(find.text('Reference created!'), findsOneWidget);

      final available = await repo.listAvailable();
      expect(available, isNotEmpty);
    });

    testWidgets('shows error when extraction fails', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.throwOnExtract = true;

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Extraction failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('shows error when no poses detected in video',
        (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = []; // No frames emitted.

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No poses detected'), findsOneWidget);
    });

    testWidgets('Try Again returns to form', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.throwOnExtract = true;

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Should be back to the form.
      expect(find.text('Reference Name'), findsOneWidget);
    });

    testWidgets('Done button navigates to home', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Select Video & Create'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('has back button in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Create Reference'), findsOneWidget);
    });
  });
}
