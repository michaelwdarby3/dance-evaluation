import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

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
  bool throwOnPick = false;

  @override
  Future<String?> pickVideo() async {
    if (throwOnPick) throw Exception('pick failed');
    return videoUrlToReturn;
  }

  @override
  void dispose() {}
}

class FakeVideoPoseExtractor extends VideoPoseExtractor {
  List<PoseFrame> framesToEmit = [];
  List<double> progressValues = [];
  bool throwOnExtract = false;

  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    if (throwOnExtract) throw Exception('extract failed');
    for (final p in progressValues) {
      onProgress(p);
    }
    for (final f in framesToEmit) {
      onFrame(f);
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
  late UploadController controller;

  setUp(() {
    picker = FakeVideoFilePicker();
    extractor = FakeVideoPoseExtractor();
    capture = CaptureController(poseDetector: FakePoseDetector());
    controller = UploadController(
      videoFilePicker: picker,
      videoPoseExtractor: extractor,
      captureController: capture,
    );
  });

  tearDown(() {
    controller.dispose();
    capture.dispose();
  });

  group('UploadController', () {
    test('initial state is idle with zero progress', () {
      expect(controller.state, UploadState.idle);
      expect(controller.progress, 0.0);
      expect(controller.frameCount, 0);
      expect(controller.errorMessage, isNull);
    });

    test('pickAndProcess transitions to idle when user cancels pick', () async {
      picker.videoUrlToReturn = null;

      await controller.pickAndProcess();

      expect(controller.state, UploadState.idle);
      expect(controller.frameCount, 0);
    });

    test('pickAndProcess processes video and transitions to done', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.progressValues = [0.25, 0.5, 0.75, 1.0];
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
        _makeFrame(const Duration(milliseconds: 200)),
        _makeFrame(const Duration(milliseconds: 300)),
      ];

      await controller.pickAndProcess();

      expect(controller.state, UploadState.done);
      expect(controller.frameCount, 3);
      expect(controller.progress, 1.0);
    });

    test('pickAndProcess puts capture controller into recording then done', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];

      await controller.pickAndProcess();

      expect(capture.state, CaptureState.done);
      expect(capture.recordedFrames.length, 1);
    });

    test('pickAndProcess transitions to error on picker exception', () async {
      picker.throwOnPick = true;

      await controller.pickAndProcess();

      expect(controller.state, UploadState.error);
      expect(controller.errorMessage, contains('pick failed'));
    });

    test('pickAndProcess transitions to error on extractor exception', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.throwOnExtract = true;

      await controller.pickAndProcess();

      expect(controller.state, UploadState.error);
      expect(controller.errorMessage, contains('extract failed'));
    });

    test('progress updates during extraction', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.progressValues = [0.5];

      final progressValues = <double>[];
      controller.addListener(() {
        progressValues.add(controller.progress);
      });

      await controller.pickAndProcess();

      expect(progressValues, contains(0.5));
    });

    test('reset clears all state back to idle', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];
      extractor.progressValues = [1.0];

      await controller.pickAndProcess();
      expect(controller.state, UploadState.done);

      controller.reset();

      expect(controller.state, UploadState.idle);
      expect(controller.progress, 0.0);
      expect(controller.frameCount, 0);
      expect(controller.errorMessage, isNull);
    });

    test('reset clears error state', () async {
      picker.throwOnPick = true;
      await controller.pickAndProcess();
      expect(controller.state, UploadState.error);

      controller.reset();

      expect(controller.state, UploadState.idle);
      expect(controller.errorMessage, isNull);
    });

    test('notifies listeners on state changes', () async {
      picker.videoUrlToReturn = null;

      final states = <UploadState>[];
      controller.addListener(() {
        states.add(controller.state);
      });

      await controller.pickAndProcess();

      // picking → idle (cancelled)
      expect(states, contains(UploadState.picking));
      expect(states.last, UploadState.idle);
    });

    test('notifies listeners through full success flow', () async {
      picker.videoUrlToReturn = 'test_video.mp4';
      extractor.framesToEmit = [
        _makeFrame(const Duration(milliseconds: 100)),
      ];

      final states = <UploadState>[];
      controller.addListener(() {
        states.add(controller.state);
      });

      await controller.pickAndProcess();

      expect(states, contains(UploadState.picking));
      expect(states, contains(UploadState.processing));
      expect(states, contains(UploadState.done));
    });
  });
}
