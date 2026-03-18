import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/utils/pose_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shorthand to create a Landmark.
Landmark lm(double x, double y, double z) =>
    Landmark(x: x, y: y, z: z, visibility: 1.0);

/// Creates a PoseFrame with Duration.zero and the given landmarks.
PoseFrame makeTestFrame(List<Landmark> landmarks) =>
    PoseFrame(timestamp: Duration.zero, landmarks: landmarks);

/// Creates a default 33-landmark list at the origin. Callers can override
/// specific indices afterward.
List<Landmark> defaultLandmarks() =>
    List<Landmark>.generate(33, (_) => lm(0, 0, 0));

/// Builds a 33-landmark list with known shoulder and hip positions for
/// normalization testing.
///
/// Left shoulder = index 11, right shoulder = index 12,
/// left hip = index 23, right hip = index 24.
///
/// Shoulders at (0.4, 0.3, 0) and (0.6, 0.3, 0).
/// Hips at (0.4, 0.5, 0) and (0.6, 0.5, 0).
/// Mid-hip = (0.5, 0.5, 0), mid-shoulder = (0.5, 0.3, 0).
/// Torso height = 0.2.
List<Landmark> realisticLandmarks() {
  final landmarks = List<Landmark>.generate(
    33,
    (i) => Landmark(x: 0.5, y: 0.5, z: 0.0, visibility: 0.9),
  );
  // Shoulders
  landmarks[PoseConstants.leftShoulder] = lm(0.4, 0.3, 0.0);
  landmarks[PoseConstants.rightShoulder] = lm(0.6, 0.3, 0.0);
  // Hips
  landmarks[PoseConstants.leftHip] = lm(0.4, 0.5, 0.0);
  landmarks[PoseConstants.rightHip] = lm(0.6, 0.5, 0.0);
  // Nose at top-center
  landmarks[PoseConstants.nose] = lm(0.5, 0.15, 0.0);
  // Left knee below hip
  landmarks[PoseConstants.leftKnee] = lm(0.4, 0.7, 0.0);
  landmarks[PoseConstants.rightKnee] = lm(0.6, 0.7, 0.0);
  return landmarks;
}

void main() {
  group('PoseMath.angleBetween', () {
    test('right angle (90 degrees) at vertex', () {
      final a = lm(0, 0, 0);
      final b = lm(1, 0, 0); // vertex
      final c = lm(1, 1, 0);
      expect(PoseMath.angleBetween(a, b, c), closeTo(90.0, 0.01));
    });

    test('straight line (180 degrees)', () {
      final a = lm(0, 0, 0);
      final b = lm(1, 0, 0); // vertex
      final c = lm(2, 0, 0);
      expect(PoseMath.angleBetween(a, b, c), closeTo(180.0, 0.01));
    });

    test('zero angle (same direction)', () {
      final a = lm(2, 0, 0);
      final b = lm(0, 0, 0); // vertex
      final c = lm(3, 0, 0); // same direction as a from b
      expect(PoseMath.angleBetween(a, b, c), closeTo(0.0, 0.01));
    });

    test('3D angle with known geometry', () {
      // Vectors from b: (1,0,0) and (0,1,1). Angle = acos(0/sqrt(1)*sqrt(2)) = 90°
      final a = lm(1, 0, 0);
      final b = lm(0, 0, 0);
      final c = lm(0, 1, 1);
      expect(PoseMath.angleBetween(a, b, c), closeTo(90.0, 0.01));
    });

    test('45-degree angle', () {
      final a = lm(1, 0, 0);
      final b = lm(0, 0, 0);
      final c = lm(1, 1, 0);
      // Angle between (1,0,0) and (1,1,0) = acos(1/sqrt(2)) = 45°
      expect(PoseMath.angleBetween(a, b, c), closeTo(45.0, 0.01));
    });

    test('60-degree angle in 3D', () {
      // Vectors from origin: (1,0,0) and (0.5, sqrt(3)/2, 0)
      final a = lm(1, 0, 0);
      final b = lm(0, 0, 0);
      final c = lm(0.5, math.sqrt(3) / 2, 0);
      expect(PoseMath.angleBetween(a, b, c), closeTo(60.0, 0.01));
    });
  });

  group('PoseMath.cosineSimilarity', () {
    test('identical vectors return 1.0', () {
      final v = [1.0, 2.0, 3.0];
      expect(PoseMath.cosineSimilarity(v, v), closeTo(1.0, 0.001));
    });

    test('opposite vectors return -1.0', () {
      final a = [1.0, 2.0, 3.0];
      final b = [-1.0, -2.0, -3.0];
      expect(PoseMath.cosineSimilarity(a, b), closeTo(-1.0, 0.001));
    });

    test('orthogonal vectors return 0.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(PoseMath.cosineSimilarity(a, b), closeTo(0.0, 0.001));
    });

    test('throws ArgumentError on mismatched lengths', () {
      expect(
        () => PoseMath.cosineSimilarity([1.0, 2.0], [1.0]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('zero vector returns 0.0', () {
      final zero = [0.0, 0.0, 0.0];
      final v = [1.0, 2.0, 3.0];
      expect(PoseMath.cosineSimilarity(zero, v), closeTo(0.0, 0.001));
    });

    test('parallel but different magnitude vectors return 1.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [5.0, 0.0, 0.0];
      expect(PoseMath.cosineSimilarity(a, b), closeTo(1.0, 0.001));
    });
  });

  group('PoseMath.normalizePose', () {
    test('hip midpoint becomes origin (0,0,0)', () {
      final frame = makeTestFrame(realisticLandmarks());
      final normalized = PoseMath.normalizePose(frame);

      final lh = normalized.landmarks[PoseConstants.leftHip];
      final rh = normalized.landmarks[PoseConstants.rightHip];
      final midHipX = (lh.x + rh.x) / 2;
      final midHipY = (lh.y + rh.y) / 2;
      final midHipZ = (lh.z + rh.z) / 2;

      expect(midHipX, closeTo(0.0, 0.001));
      expect(midHipY, closeTo(0.0, 0.001));
      expect(midHipZ, closeTo(0.0, 0.001));
    });

    test('torso height becomes 1.0', () {
      final frame = makeTestFrame(realisticLandmarks());
      final normalized = PoseMath.normalizePose(frame);

      final lh = normalized.landmarks[PoseConstants.leftHip];
      final rh = normalized.landmarks[PoseConstants.rightHip];
      final ls = normalized.landmarks[PoseConstants.leftShoulder];
      final rs = normalized.landmarks[PoseConstants.rightShoulder];

      final midHipX = (lh.x + rh.x) / 2;
      final midHipY = (lh.y + rh.y) / 2;
      final midHipZ = (lh.z + rh.z) / 2;
      final midShoulderX = (ls.x + rs.x) / 2;
      final midShoulderY = (ls.y + rs.y) / 2;
      final midShoulderZ = (ls.z + rs.z) / 2;

      final dx = midShoulderX - midHipX;
      final dy = midShoulderY - midHipY;
      final dz = midShoulderZ - midHipZ;
      final torsoHeight = math.sqrt(dx * dx + dy * dy + dz * dz);

      expect(torsoHeight, closeTo(1.0, 0.001));
    });

    test('all landmarks are translated and scaled consistently', () {
      final landmarks = realisticLandmarks();
      final frame = makeTestFrame(landmarks);
      final normalized = PoseMath.normalizePose(frame);

      // Original mid-hip = (0.5, 0.5, 0), torso height = 0.2.
      // Nose was at (0.5, 0.15, 0), so normalized:
      //   x = (0.5 - 0.5) / 0.2 = 0.0
      //   y = (0.15 - 0.5) / 0.2 = -1.75
      final nose = normalized.landmarks[PoseConstants.nose];
      expect(nose.x, closeTo(0.0, 0.001));
      expect(nose.y, closeTo(-1.75, 0.001));
      expect(nose.z, closeTo(0.0, 0.001));
    });

    test('visibility is preserved', () {
      final landmarks = realisticLandmarks();
      final frame = makeTestFrame(landmarks);
      final normalized = PoseMath.normalizePose(frame);

      // The realisticLandmarks helper uses visibility=0.9 for default and
      // visibility=1.0 for lm() helper. Check that the values are preserved.
      expect(
        normalized.landmarks[PoseConstants.leftShoulder].visibility,
        closeTo(1.0, 0.001),
      );
    });
  });

  group('PoseMath.poseDistance', () {
    test('identical poses return 0.0', () {
      final frame = makeTestFrame(realisticLandmarks());
      expect(PoseMath.poseDistance(frame, frame), closeTo(0.0, 0.001));
    });

    test('known offset gives predictable distance', () {
      final landmarks1 = defaultLandmarks();
      final landmarks2 = List<Landmark>.generate(
        33,
        (_) => lm(1, 0, 0), // each landmark offset by 1 in x
      );
      final frame1 = makeTestFrame(landmarks1);
      final frame2 = makeTestFrame(landmarks2);

      // Each of 33 landmarks is distance 1.0 apart. Total = 33.0.
      expect(PoseMath.poseDistance(frame1, frame2), closeTo(33.0, 0.001));
    });

    test('distance is symmetric', () {
      final frame1 = makeTestFrame(realisticLandmarks());
      final landmarks2 = realisticLandmarks();
      landmarks2[0] = lm(0.9, 0.9, 0.9);
      final frame2 = makeTestFrame(landmarks2);

      final d1 = PoseMath.poseDistance(frame1, frame2);
      final d2 = PoseMath.poseDistance(frame2, frame1);
      expect(d1, closeTo(d2, 0.001));
    });
  });

  group('PoseMath.poseToVector', () {
    test('correct length (33 * 3 = 99)', () {
      final frame = makeTestFrame(defaultLandmarks());
      final vec = PoseMath.poseToVector(frame);
      expect(vec.length, equals(99));
    });

    test('correct ordering (x, y, z interleaved)', () {
      final landmarks = defaultLandmarks();
      landmarks[0] = lm(1.0, 2.0, 3.0);
      landmarks[1] = lm(4.0, 5.0, 6.0);
      final frame = makeTestFrame(landmarks);
      final vec = PoseMath.poseToVector(frame);

      // First landmark
      expect(vec[0], closeTo(1.0, 0.001));
      expect(vec[1], closeTo(2.0, 0.001));
      expect(vec[2], closeTo(3.0, 0.001));
      // Second landmark
      expect(vec[3], closeTo(4.0, 0.001));
      expect(vec[4], closeTo(5.0, 0.001));
      expect(vec[5], closeTo(6.0, 0.001));
    });

    test('all zeros for zero landmarks', () {
      final frame = makeTestFrame(defaultLandmarks());
      final vec = PoseMath.poseToVector(frame);
      for (final v in vec) {
        expect(v, closeTo(0.0, 0.001));
      }
    });
  });

  group('PoseMath.midpoint', () {
    test('average of two landmarks', () {
      final a = lm(2.0, 4.0, 6.0);
      final b = lm(4.0, 8.0, 10.0);
      final mid = PoseMath.midpoint(a, b);

      expect(mid.x, closeTo(3.0, 0.001));
      expect(mid.y, closeTo(6.0, 0.001));
      expect(mid.z, closeTo(8.0, 0.001));
    });

    test('midpoint of identical landmarks is the same point', () {
      final a = lm(3.0, 5.0, 7.0);
      final mid = PoseMath.midpoint(a, a);
      expect(mid.x, closeTo(3.0, 0.001));
      expect(mid.y, closeTo(5.0, 0.001));
      expect(mid.z, closeTo(7.0, 0.001));
    });

    test('visibility is the minimum of both', () {
      final a = Landmark(x: 0, y: 0, z: 0, visibility: 0.9);
      final b = Landmark(x: 1, y: 1, z: 1, visibility: 0.5);
      final mid = PoseMath.midpoint(a, b);
      expect(mid.visibility, closeTo(0.5, 0.001));
    });
  });
}
