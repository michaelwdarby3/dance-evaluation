import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Wraps google_mlkit_pose_detection to detect poses from camera frames.
class PoseDetectionService {
  PoseDetectionService()
      : _detector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.accurate,
          ),
        );

  final PoseDetector _detector;

  /// Detects a pose in the given [image] and returns a [PoseFrame] with
  /// normalized coordinates, or `null` if no pose is found.
  Future<PoseFrame?> detectPose(InputImage image) async {
    final poses = await _detector.processImage(image);
    if (poses.isEmpty) return null;

    final pose = poses.first;
    final imageSize = image.metadata?.size;
    final imageWidth = imageSize?.width ?? 1.0;
    final imageHeight = imageSize?.height ?? 1.0;

    // Map the 33 PoseLandmarkType values (ordered by index) to Landmarks.
    final sortedTypes = List<PoseLandmarkType>.from(PoseLandmarkType.values)
      ..sort((a, b) => a.index.compareTo(b.index));

    final landmarks = <Landmark>[];
    for (final type in sortedTypes) {
      final lm = pose.landmarks[type];
      if (lm != null) {
        landmarks.add(Landmark(
          x: lm.x / imageWidth,
          y: lm.y / imageHeight,
          z: lm.z,
          visibility: lm.likelihood,
        ));
      } else {
        landmarks.add(const Landmark(x: 0, y: 0, z: 0, visibility: 0));
      }
    }

    return PoseFrame(
      landmarks: landmarks,
      timestamp: Duration.zero, // Caller will set the real timestamp.
    );
  }

  /// Closes the underlying ML Kit detector and frees resources.
  void dispose() {
    _detector.close();
  }
}
