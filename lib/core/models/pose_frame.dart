import 'dart:math' as math;

import '../constants/pose_constants.dart';
import 'landmark.dart';

export 'landmark.dart' show Landmark;

/// One frame of pose data containing all 33 BlazePose landmarks.
class PoseFrame {
  const PoseFrame({
    required this.timestamp,
    required this.landmarks,
  }) : assert(landmarks.length == PoseConstants.landmarkCount);

  /// Elapsed time from the start of the sequence.
  final Duration timestamp;

  /// 33 landmarks ordered by BlazePose index.
  final List<Landmark> landmarks;

  /// Returns the landmark at the given BlazePose [index].
  Landmark landmarkAt(int index) => landmarks[index];

  /// Computes the angle (in degrees) at vertex [b] formed by points [a]-[b]-[c].
  ///
  /// Uses 3-D coordinates. Returns a value in the range [0, 180].
  double angleBetween(int a, int b, int c) {
    final la = landmarks[a];
    final lb = landmarks[b];
    final lc = landmarks[c];

    // Vectors from b -> a and b -> c
    final baX = la.x - lb.x;
    final baY = la.y - lb.y;
    final baZ = la.z - lb.z;

    final bcX = lc.x - lb.x;
    final bcY = lc.y - lb.y;
    final bcZ = lc.z - lb.z;

    final dot = baX * bcX + baY * bcY + baZ * bcZ;
    final magBA = math.sqrt(baX * baX + baY * baY + baZ * baZ);
    final magBC = math.sqrt(bcX * bcX + bcY * bcY + bcZ * bcZ);

    if (magBA == 0 || magBC == 0) return 0.0;

    final cosAngle = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * (180.0 / math.pi);
  }

  @override
  String toString() => 'PoseFrame(timestamp: $timestamp)';
}
