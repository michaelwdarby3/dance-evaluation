import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/utils/dtw.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a uniform 33-landmark frame where every landmark is at (v, v, v).
PoseFrame _uniformFrame(double v, {Duration? timestamp}) {
  final landmarks = List<Landmark>.generate(
    33,
    (_) => Landmark(x: v, y: v, z: v, visibility: 1.0),
  );
  return PoseFrame(timestamp: timestamp ?? Duration.zero, landmarks: landmarks);
}

/// Builds a PoseSequence from a list of uniform frame values.
PoseSequence _buildSequence(List<double> values) {
  final frames = <PoseFrame>[];
  for (var i = 0; i < values.length; i++) {
    frames.add(_uniformFrame(
      values[i],
      timestamp: Duration(milliseconds: i * 100),
    ));
  }
  return PoseSequence(
    frames: frames,
    fps: 10.0,
    duration: Duration(milliseconds: values.length * 100),
  );
}

void main() {
  group('computeDtw', () {
    test('identical sequences produce distance 0 and diagonal warping path',
        () {
      final seq = _buildSequence([0.0, 1.0, 2.0]);
      final result = computeDtw(seq, seq);

      expect(result.distance, closeTo(0.0, 0.001));
      expect(result.warpingPath.length, equals(3));
      // Diagonal path: (0,0), (1,1), (2,2)
      expect(result.warpingPath[0], equals((0, 0)));
      expect(result.warpingPath[1], equals((1, 1)));
      expect(result.warpingPath[2], equals((2, 2)));
    });

    test('two sequences offset by one frame produce compensating warping path',
        () {
      final ref = _buildSequence([0.0, 1.0, 2.0, 3.0]);
      final user = _buildSequence([1.0, 2.0, 3.0]);
      final result = computeDtw(ref, user);

      // Path should start at (0,0) and end at (3,2).
      expect(result.warpingPath.first, equals((0, 0)));
      expect(result.warpingPath.last, equals((3, 2)));
      // Distance should be finite and positive (offset creates cost).
      expect(result.distance, greaterThan(0.0));
      expect(result.distance.isFinite, isTrue);
    });

    test('one sequence longer than the other still produces valid alignment',
        () {
      final ref = _buildSequence([0.0, 0.5, 1.0, 1.5, 2.0]);
      final user = _buildSequence([0.0, 2.0]);
      final result = computeDtw(ref, user);

      // Path must start at (0,0) and end at (4,1).
      expect(result.warpingPath.first, equals((0, 0)));
      expect(result.warpingPath.last, equals((4, 1)));
      expect(result.warpingPath.length, greaterThanOrEqualTo(5));
    });

    test('empty sequences return infinity distance and empty path', () {
      final empty = PoseSequence(
        frames: const [],
        fps: 10.0,
        duration: Duration.zero,
      );
      final nonEmpty = _buildSequence([1.0]);

      final result1 = computeDtw(empty, nonEmpty);
      expect(result1.distance, equals(double.infinity));
      expect(result1.normalizedDistance, equals(double.infinity));
      expect(result1.warpingPath, isEmpty);

      final result2 = computeDtw(nonEmpty, empty);
      expect(result2.distance, equals(double.infinity));
      expect(result2.warpingPath, isEmpty);

      final result3 = computeDtw(empty, empty);
      expect(result3.distance, equals(double.infinity));
      expect(result3.warpingPath, isEmpty);
    });

    test('single frame sequences return pose distance and path [(0,0)]', () {
      final seq1 = _buildSequence([0.0]);
      final seq2 = _buildSequence([1.0]);
      final result = computeDtw(seq1, seq2);

      // Each landmark differs by 1.0 in all 3 coordinates.
      // Distance per landmark = sqrt(1+1+1) = sqrt(3).
      // Total = 33 * sqrt(3).
      expect(result.distance, closeTo(33.0 * 1.7320508, 0.01));
      expect(result.warpingPath, equals([(0, 0)]));
    });

    test('normalizedDistance equals distance divided by path length', () {
      final ref = _buildSequence([0.0, 1.0, 2.0]);
      final user = _buildSequence([0.0, 1.0, 2.0, 3.0]);
      final result = computeDtw(ref, user);

      expect(
        result.normalizedDistance,
        closeTo(result.distance / result.warpingPath.length, 0.001),
      );
    });
  });

  group('alignSequences', () {
    test('returns just the warping path from computeDtw', () {
      final ref = _buildSequence([0.0, 1.0, 2.0]);
      final user = _buildSequence([0.0, 1.0, 2.0]);
      final path = alignSequences(ref, user);
      final dtwResult = computeDtw(ref, user);

      expect(path, equals(dtwResult.warpingPath));
    });
  });
}
