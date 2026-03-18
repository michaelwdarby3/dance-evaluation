import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Platform-agnostic pose detection interface.
abstract class PoseDetector {
  /// Detect a pose from platform-specific input.
  Future<PoseFrame?> detectPose(PoseInput input);

  /// Release resources.
  void dispose();
}

/// Platform-agnostic input for pose detection.
class PoseInput {
  const PoseInput({
    required this.width,
    required this.height,
    this.bytes,
    this.platformData,
  });

  final double width;
  final double height;

  /// Raw image bytes (mobile: NV21/BGRA). Null on web.
  final dynamic bytes;

  /// Opaque platform-specific data.
  /// Mobile: InputImageMetadata. Web: VideoElement.
  final dynamic platformData;
}
