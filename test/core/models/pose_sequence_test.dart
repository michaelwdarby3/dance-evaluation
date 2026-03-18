import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

Landmark _lm(double x, double y, double z) =>
    Landmark(x: x, y: y, z: z, visibility: 1.0);

/// Creates a 33-landmark list with controlled shoulder and hip positions.
List<Landmark> _makeBodyLandmarks({
  double leftShoulderX = 0.4,
  double rightShoulderX = 0.6,
  double shoulderY = 0.3,
  double leftHipX = 0.4,
  double rightHipX = 0.6,
  double hipY = 0.5,
}) {
  final landmarks = List<Landmark>.generate(
    33,
    (_) => _lm(0.5, 0.5, 0.0),
  );
  landmarks[PoseConstants.leftShoulder] = _lm(leftShoulderX, shoulderY, 0.0);
  landmarks[PoseConstants.rightShoulder] = _lm(rightShoulderX, shoulderY, 0.0);
  landmarks[PoseConstants.leftHip] = _lm(leftHipX, hipY, 0.0);
  landmarks[PoseConstants.rightHip] = _lm(rightHipX, hipY, 0.0);
  return landmarks;
}

/// Builds a PoseSequence with the given frame count at the given fps.
PoseSequence _buildSequence(int frameCount, double fps) {
  final frames = <PoseFrame>[];
  for (var i = 0; i < frameCount; i++) {
    final timestampMs = (i * 1000.0 / fps).round();
    frames.add(PoseFrame(
      timestamp: Duration(milliseconds: timestampMs),
      landmarks: _makeBodyLandmarks(),
    ));
  }
  final durationMs = frameCount > 0 ? (frameCount * 1000.0 / fps).round() : 0;
  return PoseSequence(
    frames: frames,
    fps: fps,
    duration: Duration(milliseconds: durationMs),
  );
}

void main() {
  group('PoseSequence.normalize', () {
    test('centers frames on hip midpoint', () {
      final seq = _buildSequence(3, 15.0);
      final normalized = seq.normalize();

      for (final frame in normalized.frames) {
        final lh = frame.landmarks[PoseConstants.leftHip];
        final rh = frame.landmarks[PoseConstants.rightHip];
        final midX = (lh.x + rh.x) / 2;
        final midY = (lh.y + rh.y) / 2;
        final midZ = (lh.z + rh.z) / 2;

        expect(midX, closeTo(0.0, 0.001));
        expect(midY, closeTo(0.0, 0.001));
        expect(midZ, closeTo(0.0, 0.001));
      }
    });

    test('scales torso height to 1.0', () {
      final seq = _buildSequence(2, 15.0);
      final normalized = seq.normalize();

      for (final frame in normalized.frames) {
        final lh = frame.landmarks[PoseConstants.leftHip];
        final rh = frame.landmarks[PoseConstants.rightHip];
        final ls = frame.landmarks[PoseConstants.leftShoulder];
        final rs = frame.landmarks[PoseConstants.rightShoulder];

        final midHipX = (lh.x + rh.x) / 2;
        final midHipY = (lh.y + rh.y) / 2;
        final midShoulderX = (ls.x + rs.x) / 2;
        final midShoulderY = (ls.y + rs.y) / 2;

        final dx = midShoulderX - midHipX;
        final dy = midShoulderY - midHipY;
        final torsoHeight = math.sqrt(dx * dx + dy * dy);

        expect(torsoHeight, closeTo(1.0, 0.001));
      }
    });

    test('preserves fps, duration, and label', () {
      final seq = PoseSequence(
        frames: _buildSequence(2, 15.0).frames,
        fps: 15.0,
        duration: const Duration(milliseconds: 133),
        label: 'test_label',
      );
      final normalized = seq.normalize();

      expect(normalized.fps, equals(15.0));
      expect(normalized.duration, equals(const Duration(milliseconds: 133)));
      expect(normalized.label, equals('test_label'));
    });
  });

  group('PoseSequence.subsample', () {
    test('30fps to 15fps roughly halves frame count', () {
      // 30 frames at 30fps = 1 second. Subsample to 15fps -> ~15 frames.
      final seq = _buildSequence(30, 30.0);
      final resampled = seq.subsample(15.0);

      // Duration is 1000ms. ceil(1.0 * 15) = 15.
      expect(resampled.frames.length, equals(15));
      expect(resampled.fps, equals(15.0));
    });

    test('15fps to 30fps roughly doubles frame count', () {
      // 15 frames at 15fps = 1 second. Subsample to 30fps -> ~30 frames.
      final seq = _buildSequence(15, 15.0);
      final resampled = seq.subsample(30.0);

      // Duration is 1000ms. ceil(1.0 * 30) = 30.
      expect(resampled.frames.length, equals(30));
      expect(resampled.fps, equals(30.0));
    });

    test('0 fps returns empty sequence', () {
      final seq = _buildSequence(10, 10.0);
      final resampled = seq.subsample(0.0);

      expect(resampled.frames, isEmpty);
      expect(resampled.fps, equals(0.0));
    });

    test('empty sequence stays empty', () {
      final empty = PoseSequence(
        frames: const [],
        fps: 15.0,
        duration: Duration.zero,
      );
      final resampled = empty.subsample(30.0);
      expect(resampled.frames, isEmpty);
    });

    test('timestamps are recalculated after subsample', () {
      final seq = _buildSequence(10, 10.0);
      final resampled = seq.subsample(5.0);

      // At 5fps each frame should be 200ms apart.
      for (var i = 0; i < resampled.frames.length; i++) {
        final expectedMs = (i / 5.0 * 1000000).round(); // microseconds
        expect(
          resampled.frames[i].timestamp.inMicroseconds,
          closeTo(expectedMs, 1),
        );
      }
    });

    test('preserves label and duration', () {
      final seq = PoseSequence(
        frames: _buildSequence(10, 10.0).frames,
        fps: 10.0,
        duration: const Duration(seconds: 1),
        label: 'keep_me',
      );
      final resampled = seq.subsample(5.0);

      expect(resampled.label, equals('keep_me'));
      expect(resampled.duration, equals(const Duration(seconds: 1)));
    });
  });
}
