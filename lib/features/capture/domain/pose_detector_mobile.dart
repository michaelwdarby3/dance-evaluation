import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'pose_detector.dart';

/// Creates the mobile (ML Kit) pose detector.
PoseDetector createPoseDetector() => MobilePoseDetector();

class MobilePoseDetector implements PoseDetector {
  MobilePoseDetector()
      : _detector = mlkit.PoseDetector(
          options: mlkit.PoseDetectorOptions(
            mode: mlkit.PoseDetectionMode.stream,
            model: mlkit.PoseDetectionModel.accurate,
          ),
        );

  final mlkit.PoseDetector _detector;

  @override
  Future<PoseFrame?> detectPose(PoseInput input) async {
    final metadata = input.platformData as mlkit.InputImageMetadata;
    final inputImage = mlkit.InputImage.fromBytes(
      bytes: input.bytes,
      metadata: metadata,
    );

    final poses = await _detector.processImage(inputImage);
    if (poses.isEmpty) return null;

    final pose = poses.first;
    final imageWidth = input.width;
    final imageHeight = input.height;

    final sortedTypes = List<mlkit.PoseLandmarkType>.from(mlkit.PoseLandmarkType.values)
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

    return PoseFrame(landmarks: landmarks, timestamp: Duration.zero);
  }

  @override
  void dispose() {
    _detector.close();
  }
}
