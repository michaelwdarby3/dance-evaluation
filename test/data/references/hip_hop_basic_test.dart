import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/data/references/hip_hop_basic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getHipHopBasicReference', () {
    test('returns a valid choreography', () {
      final ref = getHipHopBasicReference();
      expect(ref.id, isNotEmpty);
      expect(ref.name, isNotEmpty);
      expect(ref.description, isNotEmpty);
      expect(ref.difficulty, isNotEmpty);
      expect(ref.bpm, greaterThan(0.0));
    });

    test('has 30 frames', () {
      final ref = getHipHopBasicReference();
      expect(ref.poses.frames.length, equals(30));
    });

    test('fps is 15.0', () {
      final ref = getHipHopBasicReference();
      expect(ref.poses.fps, closeTo(15.0, 0.001));
    });

    test('style is hipHop', () {
      final ref = getHipHopBasicReference();
      expect(ref.style, equals(DanceStyle.hipHop));
    });

    test('all frames have exactly 33 landmarks', () {
      final ref = getHipHopBasicReference();
      for (var i = 0; i < ref.poses.frames.length; i++) {
        expect(
          ref.poses.frames[i].landmarks.length,
          equals(PoseConstants.landmarkCount),
          reason: 'Frame $i should have 33 landmarks',
        );
      }
    });

    test('all landmarks have visibility > 0', () {
      final ref = getHipHopBasicReference();
      for (var i = 0; i < ref.poses.frames.length; i++) {
        for (var j = 0; j < ref.poses.frames[i].landmarks.length; j++) {
          expect(
            ref.poses.frames[i].landmarks[j].visibility,
            greaterThan(0.0),
            reason: 'Frame $i, landmark $j should have visibility > 0',
          );
        }
      }
    });

    test('duration is 2 seconds', () {
      final ref = getHipHopBasicReference();
      expect(ref.poses.duration, equals(const Duration(seconds: 2)));
    });

    test('timestamps are monotonically increasing', () {
      final ref = getHipHopBasicReference();
      for (var i = 1; i < ref.poses.frames.length; i++) {
        expect(
          ref.poses.frames[i].timestamp,
          greaterThan(ref.poses.frames[i - 1].timestamp),
          reason: 'Frame $i timestamp should be after frame ${i - 1}',
        );
      }
    });

    test('label is set', () {
      final ref = getHipHopBasicReference();
      expect(ref.poses.label, isNotNull);
      expect(ref.poses.label, isNotEmpty);
    });
  });
}
