import 'dart:math' as math;

import '../constants/pose_constants.dart';
import '../models/pose_frame.dart';

/// Pure math utilities for pose analysis.
///
/// All methods are static and side-effect free.
class PoseMath {
  PoseMath._();

  /// Returns the angle (in degrees, 0-180) at point [b] formed by the
  /// line segments a-b and b-c.
  ///
  /// Uses [atan2] for numerical stability.
  static double angleBetween(Landmark a, Landmark b, Landmark c) {
    // Vectors from b -> a and b -> c.
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final baZ = a.z - b.z;

    final bcX = c.x - b.x;
    final bcY = c.y - b.y;
    final bcZ = c.z - b.z;

    // Cross product magnitude (|ba x bc|).
    final crossX = baY * bcZ - baZ * bcY;
    final crossY = baZ * bcX - baX * bcZ;
    final crossZ = baX * bcY - baY * bcX;
    final crossMag = math.sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ);

    // Dot product.
    final dot = baX * bcX + baY * bcY + baZ * bcZ;

    // atan2(|cross|, dot) gives the angle in [0, pi].
    return math.atan2(crossMag, dot) * (180.0 / math.pi);
  }

  /// Standard cosine similarity between two equal-length vectors.
  ///
  /// Returns a value in [-1, 1]. Throws if lengths differ.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must have equal length: ${a.length} vs ${b.length}');
    }

    var dot = 0.0;
    var magA = 0.0;
    var magB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }

    magA = math.sqrt(magA);
    magB = math.sqrt(magB);

    if (magA == 0 || magB == 0) return 0.0;
    return dot / (magA * magB);
  }

  /// Normalizes a [PoseFrame] by centering on the hip midpoint (landmarks
  /// 23 & 24) and scaling so that torso height (midHip to midShoulder) = 1.0.
  static PoseFrame normalizePose(PoseFrame frame) {
    final lh = frame.landmarks[PoseConstants.leftHip];
    final rh = frame.landmarks[PoseConstants.rightHip];
    final midHip = midpoint(lh, rh);

    final ls = frame.landmarks[PoseConstants.leftShoulder];
    final rs = frame.landmarks[PoseConstants.rightShoulder];
    final midShoulder = midpoint(ls, rs);

    // Torso height as the scale reference.
    final dx = midShoulder.x - midHip.x;
    final dy = midShoulder.y - midHip.y;
    final dz = midShoulder.z - midHip.z;
    var torsoHeight = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (torsoHeight == 0) torsoHeight = 1.0;

    final normalized = frame.landmarks.map((lm) {
      return Landmark(
        x: (lm.x - midHip.x) / torsoHeight,
        y: (lm.y - midHip.y) / torsoHeight,
        z: (lm.z - midHip.z) / torsoHeight,
        visibility: lm.visibility,
      );
    }).toList();

    return PoseFrame(timestamp: frame.timestamp, landmarks: normalized);
  }

  /// Euclidean distance between two normalized poses, computed as the sum
  /// of per-landmark distances.
  static double poseDistance(PoseFrame a, PoseFrame b) {
    final la = a.landmarks;
    final lb = b.landmarks;
    final count = math.min(la.length, lb.length);

    var total = 0.0;
    for (var i = 0; i < count; i++) {
      final dx = la[i].x - lb[i].x;
      final dy = la[i].y - lb[i].y;
      final dz = la[i].z - lb[i].z;
      total += math.sqrt(dx * dx + dy * dy + dz * dz);
    }
    return total;
  }

  /// Flattens a [PoseFrame]'s landmarks into a vector:
  /// `[x1, y1, z1, x2, y2, z2, ...]`.
  static List<double> poseToVector(PoseFrame frame) {
    final vec = <double>[];
    for (final lm in frame.landmarks) {
      vec.add(lm.x);
      vec.add(lm.y);
      vec.add(lm.z);
    }
    return vec;
  }

  /// Returns the midpoint (average) of two landmarks.
  static Landmark midpoint(Landmark a, Landmark b) {
    return Landmark(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      visibility: math.min(a.visibility, b.visibility),
    );
  }
}
