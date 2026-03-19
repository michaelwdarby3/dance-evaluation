import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Extracts pose frames from a video file.
abstract class VideoPoseExtractor {
  /// Steps through the video at [videoUrl], detecting poses.
  /// Calls [onProgress] with 0.0–1.0 and [onFrame] for each detected pose.
  /// Returns the total video duration.
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  });

  /// Multi-person variant. Calls [onFrames] with all detected persons per
  /// video frame. Default implementation wraps [extractPoses].
  Future<Duration> extractMultiPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(List<PoseFrame> frames) onFrames,
  }) {
    return extractPoses(
      videoUrl: videoUrl,
      onProgress: onProgress,
      onFrame: (frame) => onFrames([frame]),
    );
  }

  void dispose();
}
