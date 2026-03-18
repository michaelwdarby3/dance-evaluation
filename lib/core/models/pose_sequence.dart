import 'dart:math' as math;

import '../constants/pose_constants.dart';
import 'pose_frame.dart';

/// An ordered sequence of [PoseFrame]s representing a dance clip.
class PoseSequence {
  const PoseSequence({
    required this.frames,
    required this.fps,
    required this.duration,
    this.label,
  });

  /// Ordered pose frames.
  final List<PoseFrame> frames;

  /// Frames per second of the source video.
  final double fps;

  /// Total duration of the sequence.
  final Duration duration;

  /// Optional label (e.g. move name, reference clip id).
  final String? label;

  // ---------------------------------------------------------------------------
  // Normalization
  // ---------------------------------------------------------------------------

  /// Returns a new [PoseSequence] where every frame is:
  ///  1. Centred on the midpoint between the left and right hips.
  ///  2. Scaled so that the torso height (hip-midpoint to shoulder-midpoint)
  ///     equals 1.0.
  PoseSequence normalize() {
    final normalizedFrames = frames.map(_normalizeFrame).toList();
    return PoseSequence(
      frames: normalizedFrames,
      fps: fps,
      duration: duration,
      label: label,
    );
  }

  static PoseFrame _normalizeFrame(PoseFrame frame) {
    final lh = frame.landmarkAt(PoseConstants.leftHip);
    final rh = frame.landmarkAt(PoseConstants.rightHip);

    // Hip midpoint (translation origin)
    final hipMidX = (lh.x + rh.x) / 2;
    final hipMidY = (lh.y + rh.y) / 2;
    final hipMidZ = (lh.z + rh.z) / 2;

    // Shoulder midpoint
    final ls = frame.landmarkAt(PoseConstants.leftShoulder);
    final rs = frame.landmarkAt(PoseConstants.rightShoulder);
    final shoulderMidX = (ls.x + rs.x) / 2;
    final shoulderMidY = (ls.y + rs.y) / 2;
    final shoulderMidZ = (ls.z + rs.z) / 2;

    // Torso height (Euclidean distance hip-mid -> shoulder-mid)
    final dx = shoulderMidX - hipMidX;
    final dy = shoulderMidY - hipMidY;
    final dz = shoulderMidZ - hipMidZ;
    var torsoHeight = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (torsoHeight == 0) torsoHeight = 1.0; // avoid division by zero

    final normalized = frame.landmarks.map((lm) {
      return Landmark(
        x: (lm.x - hipMidX) / torsoHeight,
        y: (lm.y - hipMidY) / torsoHeight,
        z: (lm.z - hipMidZ) / torsoHeight,
        visibility: lm.visibility,
      );
    }).toList();

    return PoseFrame(timestamp: frame.timestamp, landmarks: normalized);
  }

  // ---------------------------------------------------------------------------
  // Sub-sampling
  // ---------------------------------------------------------------------------

  /// Returns a new [PoseSequence] re-sampled to [targetFps].
  ///
  /// Uses nearest-neighbour frame selection.
  PoseSequence subsample(double targetFps) {
    if (frames.isEmpty || targetFps <= 0) {
      return PoseSequence(
        frames: const [],
        fps: targetFps,
        duration: duration,
        label: label,
      );
    }

    final totalSeconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final targetCount = (totalSeconds * targetFps).ceil();

    final sampled = <PoseFrame>[];
    for (var i = 0; i < targetCount; i++) {
      final targetTime = i / targetFps;
      // Find nearest frame by timestamp
      var bestIdx = 0;
      var bestDiff = double.infinity;
      for (var j = 0; j < frames.length; j++) {
        final frameSec =
            frames[j].timestamp.inMicroseconds / Duration.microsecondsPerSecond;
        final diff = (frameSec - targetTime).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = j;
        }
      }
      final original = frames[bestIdx];
      sampled.add(PoseFrame(
        timestamp: Duration(microseconds: (targetTime * Duration.microsecondsPerSecond).round()),
        landmarks: original.landmarks,
      ));
    }

    return PoseSequence(
      frames: sampled,
      fps: targetFps,
      duration: duration,
      label: label,
    );
  }

  @override
  String toString() =>
      'PoseSequence(frames: ${frames.length}, fps: $fps, '
      'duration: $duration, label: $label)';
}
