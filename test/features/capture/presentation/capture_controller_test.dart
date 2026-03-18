import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';

class MockPoseDetector extends Mock implements PoseDetector {}

PoseFrame makeFrame([Duration ts = Duration.zero]) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      33,
      (_) => const Landmark(x: 0.5, y: 0.5, z: 0, visibility: 0.9),
    ),
  );
}

void main() {
  late MockPoseDetector mockDetector;
  late CaptureController controller;

  setUp(() {
    mockDetector = MockPoseDetector();
    controller = CaptureController(poseDetector: mockDetector);
  });

  tearDown(() {
    controller.dispose();
  });

  group('CaptureController', () {
    test('initial state is CaptureState.idle', () {
      expect(controller.state, CaptureState.idle);
    });

    test('startCountdown() transitions to countdown state', () {
      fakeAsync((async) {
        controller.startCountdown();

        expect(controller.state, CaptureState.countdown);
      });
    });

    test('after countdown completes, transitions to recording', () {
      fakeAsync((async) {
        controller.startCountdown();

        // Advance past the 3-second countdown
        async.elapse(const Duration(seconds: 3));

        expect(controller.state, CaptureState.recording);
      });
    });

    test('countdownSeconds decrements from 3 to 0', () {
      fakeAsync((async) {
        controller.startCountdown();
        expect(controller.countdownSeconds, 3);

        async.elapse(const Duration(seconds: 1));
        expect(controller.countdownSeconds, 2);

        async.elapse(const Duration(seconds: 1));
        expect(controller.countdownSeconds, 1);

        async.elapse(const Duration(seconds: 1));
        expect(controller.countdownSeconds, 0);
      });
    });

    test('onPoseDetected() during recording adds frames to recordedFrames', () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        expect(controller.state, CaptureState.recording);

        controller.onPoseDetected(makeFrame());
        controller.onPoseDetected(makeFrame());

        expect(controller.recordedFrames.length, 2);
      });
    });

    test('onPoseDetected() during idle does NOT add to recordedFrames', () {
      expect(controller.state, CaptureState.idle);

      controller.onPoseDetected(makeFrame());

      expect(controller.recordedFrames, isEmpty);
    });

    test('onPoseDetected() always updates currentFrame regardless of state',
        () {
      expect(controller.currentFrame, isNull);

      final frame = makeFrame();
      controller.onPoseDetected(frame);

      expect(controller.currentFrame, isNotNull);
      expect(controller.currentFrame!.landmarks.length, 33);
    });

    test('stopRecording() transitions to done state', () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        expect(controller.state, CaptureState.recording);

        controller.stopRecording();

        expect(controller.state, CaptureState.done);
      });
    });

    test('getRecordedSequence() returns PoseSequence with correct frame count',
        () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        controller.onPoseDetected(makeFrame());
        controller.onPoseDetected(makeFrame());
        controller.onPoseDetected(makeFrame());

        final sequence = controller.getRecordedSequence();

        expect(sequence, isA<PoseSequence>());
        expect(sequence.frames.length, 3);
      });
    });

    test('getRecordedSequence() calculates fps from recorded timestamps', () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        // Add frames at different elapsed times by advancing the stopwatch
        controller.onPoseDetected(makeFrame());
        async.elapse(const Duration(milliseconds: 100));
        controller.onPoseDetected(makeFrame());
        async.elapse(const Duration(milliseconds: 100));
        controller.onPoseDetected(makeFrame());

        final sequence = controller.getRecordedSequence();

        // fps = (frameCount * 1000) / lastTimestampMs
        // The exact value depends on Stopwatch elapsed, but it should be > 0
        expect(sequence.fps, greaterThan(0));
      });
    });

    test('reset() returns to idle, clears frames, clears currentFrame', () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        controller.onPoseDetected(makeFrame());
        expect(controller.recordedFrames, isNotEmpty);
        expect(controller.currentFrame, isNotNull);

        controller.reset();

        expect(controller.state, CaptureState.idle);
        expect(controller.recordedFrames, isEmpty);
        expect(controller.currentFrame, isNull);
      });
    });

    test('recording auto-stops at maxDuration (30s)', () {
      fakeAsync((async) {
        controller.startCountdown();
        async.elapse(const Duration(seconds: 3));

        expect(controller.state, CaptureState.recording);

        // Advance past the 30-second max recording duration
        async.elapse(const Duration(seconds: 31));

        expect(controller.state, CaptureState.done);
      });
    });
  });
}
