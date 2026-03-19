import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';

class FakePoseDetector extends PoseDetector {
  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => null;
  @override
  void dispose() {}
}

PoseFrame _makeFrame(Duration ts, {double x = 0.5}) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      33,
      (_) => Landmark(x: x, y: 0.5, z: 0, visibility: 0.9),
    ),
  );
}

void main() {
  late CaptureController controller;

  setUp(() {
    controller = CaptureController(poseDetector: FakePoseDetector());
  });

  tearDown(() {
    controller.dispose();
  });

  group('CaptureController external recording', () {
    test('startExternalRecording transitions to recording state', () {
      controller.startExternalRecording();

      expect(controller.state, CaptureState.recording);
      expect(controller.recordedFrames, isEmpty);
      expect(controller.isMultiPerson, isFalse);
    });

    test('addExternalFrame records frames with correct timestamps', () {
      controller.startExternalRecording();

      final f1 = _makeFrame(const Duration(milliseconds: 100));
      final f2 = _makeFrame(const Duration(milliseconds: 200));

      controller.addExternalFrame(f1);
      controller.addExternalFrame(f2);

      expect(controller.recordedFrames.length, 2);
      expect(controller.recordingDuration, const Duration(milliseconds: 200));
    });

    test('addExternalFrame updates currentFrame', () {
      controller.startExternalRecording();
      expect(controller.currentFrame, isNull);

      final frame = _makeFrame(const Duration(milliseconds: 100));
      controller.addExternalFrame(frame);

      expect(controller.currentFrame, isNotNull);
    });

    test('addExternalFrame is ignored when not recording', () {
      expect(controller.state, CaptureState.idle);

      controller.addExternalFrame(
        _makeFrame(const Duration(milliseconds: 100)),
      );

      expect(controller.recordedFrames, isEmpty);
    });

    test('stopRecording after external recording transitions to done', () {
      controller.startExternalRecording();

      controller.addExternalFrame(
        _makeFrame(const Duration(milliseconds: 100)),
      );
      controller.addExternalFrame(
        _makeFrame(const Duration(milliseconds: 200)),
      );

      controller.stopRecording();

      expect(controller.state, CaptureState.done);
      expect(controller.recordedFrames.length, 2);
    });

    test('getRecordedSequence after external recording returns correct fps', () {
      controller.startExternalRecording();

      // 10 frames over 1 second = 10 fps
      for (var i = 0; i < 10; i++) {
        controller.addExternalFrame(
          _makeFrame(Duration(milliseconds: i * 100)),
        );
      }

      controller.stopRecording();
      final seq = controller.getRecordedSequence();

      expect(seq.frames.length, 10);
      expect(seq.duration, const Duration(milliseconds: 900));
      // fps = 10 * 1000 / 900 ≈ 11.1
      expect(seq.fps, closeTo(11.1, 0.2));
    });

    test('startExternalRecording clears previous recording state', () {
      controller.startExternalRecording();
      controller.addExternalFrame(
        _makeFrame(const Duration(milliseconds: 100)),
      );
      expect(controller.recordedFrames.length, 1);

      // Start a new external recording
      controller.startExternalRecording();

      expect(controller.recordedFrames, isEmpty);
      expect(controller.recordingDuration, Duration.zero);
    });

    test('addExternalMultiFrames records multi-person frames', () {
      controller.startExternalRecording();

      final frames = [
        _makeFrame(const Duration(milliseconds: 100), x: 0.2),
        _makeFrame(const Duration(milliseconds: 100), x: 0.8),
      ];

      controller.addExternalMultiFrames(frames);

      expect(controller.isMultiPerson, isTrue);
      expect(controller.currentTrackedPersons.length, 2);
      // Legacy list also gets first person
      expect(controller.recordedFrames.length, 1);
    });

    test('addExternalMultiFrames is ignored when not recording', () {
      expect(controller.state, CaptureState.idle);

      controller.addExternalMultiFrames([
        _makeFrame(const Duration(milliseconds: 100)),
      ]);

      expect(controller.recordedFrames, isEmpty);
      expect(controller.currentTrackedPersons, isEmpty);
    });

    test('getRecordedMultiSequence after external multi frames', () {
      controller.startExternalRecording();

      // Add 5 frames with 2 persons each
      for (var i = 0; i < 5; i++) {
        controller.addExternalMultiFrames([
          _makeFrame(Duration(milliseconds: i * 100), x: 0.2),
          _makeFrame(Duration(milliseconds: i * 100), x: 0.8),
        ]);
      }

      controller.stopRecording();
      final multiSeq = controller.getRecordedMultiSequence();

      expect(multiSeq.personCount, 2);
      for (final seq in multiSeq.personSequences) {
        expect(seq.frames.length, 5);
      }
    });

    test('mixed single and multi person external frames', () {
      controller.startExternalRecording();

      // First frame: single person
      controller.addExternalMultiFrames([
        _makeFrame(const Duration(milliseconds: 100), x: 0.5),
      ]);
      expect(controller.isMultiPerson, isFalse);

      // Second frame: two persons
      controller.addExternalMultiFrames([
        _makeFrame(const Duration(milliseconds: 200), x: 0.2),
        _makeFrame(const Duration(milliseconds: 200), x: 0.8),
      ]);
      expect(controller.isMultiPerson, isTrue);
    });
  });
}
