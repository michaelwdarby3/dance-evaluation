import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';
import 'package:dance_evaluation/features/upload/presentation/pages/upload_processing_screen.dart';

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
  Completer<String?>? _completer;

  void holdPickVideo() {
    _completer = Completer<String?>();
  }

  void completePickVideo(String? url) {
    _completer?.complete(url);
  }

  @override
  Future<String?> pickVideo() async {
    if (_completer != null) return _completer!.future;
    return videoUrlToReturn;
  }

  @override
  void dispose() {}
}

class FakeVideoPoseExtractor extends VideoPoseExtractor {
  List<PoseFrame> framesToEmit = [];
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
    return const Duration(seconds: 5);
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
  late CaptureController capture;
  late UploadController uploadController;
  String? lastNavigatedTo;

  setUp(() {
    picker = FakeVideoFilePicker();
    extractor = FakeVideoPoseExtractor();
    capture = CaptureController(poseDetector: FakePoseDetector());
    uploadController = UploadController(
      videoFilePicker: picker,
      videoPoseExtractor: extractor,
      captureController: capture,
    );
    lastNavigatedTo = null;

    final sl = ServiceLocator.instance;
    sl.reset();
    sl.register<UploadController>(uploadController);
  });

  tearDown(() {
    capture.dispose();
    ServiceLocator.instance.reset();
  });

  // The UploadProcessingScreen calls context.pop() on cancel and
  // context.go('/evaluation/...') on done. We start at '/' and push
  // to '/upload' so there's something to pop back to.
  Widget buildSubject({String? referenceKey}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('go_upload'),
                onPressed: () => context.push('/upload'),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/upload',
          builder: (_, state) =>
              UploadProcessingScreen(referenceKey: referenceKey),
        ),
        GoRoute(
          path: '/evaluation/:id',
          builder: (_, __) {
            lastNavigatedTo = '/evaluation';
            return const Scaffold(body: Text('Evaluation'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  Future<void> navigateToUpload(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(const Key('go_upload')));
    await tester.pump();
  }

  group('UploadProcessingScreen', () {
    testWidgets('shows picking UI while file picker is open', (tester) async {
      picker.holdPickVideo();

      await navigateToUpload(tester);
      await tester.pump();

      expect(find.text('Select a video file...'), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);

      picker.completePickVideo(null);
      await tester.pumpAndSettle();
    });

    testWidgets('returns to previous screen when user cancels picker',
        (tester) async {
      picker.videoUrlToReturn = null;

      await navigateToUpload(tester);
      await tester.pumpAndSettle();

      // Should have popped back to Home.
      expect(uploadController.state, UploadState.idle);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('navigates to evaluation on successful extraction',
        (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
        _makeFrame(const Duration(milliseconds: 200)),
      ];

      await navigateToUpload(tester);
      await tester.pumpAndSettle();

      expect(uploadController.state, UploadState.done);
      expect(lastNavigatedTo, '/evaluation');
    });

    testWidgets('shows error UI on extraction failure', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.throwOnExtract = true;

      await navigateToUpload(tester);
      await tester.pumpAndSettle();

      expect(uploadController.state, UploadState.error);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Extraction failed'), findsOneWidget);
    });

    testWidgets('Try Again resets and retries', (tester) async {
      picker.videoUrlToReturn = 'test.mp4';
      extractor.throwOnExtract = true;

      await navigateToUpload(tester);
      await tester.pumpAndSettle();

      // Fix and retry.
      extractor.throwOnExtract = false;
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(uploadController.state, UploadState.done);
    });

    testWidgets('has back button and title in app bar', (tester) async {
      picker.holdPickVideo();

      await navigateToUpload(tester);
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);

      picker.completePickVideo(null);
      await tester.pumpAndSettle();
    });
  });
}
