import 'package:flutter/widgets.dart';

import 'pose_detector.dart';

/// Platform-agnostic camera frame source.
abstract class CameraSource {
  /// Initialize the camera (request permissions, open device).
  Future<void> initialize();

  /// Widget that shows the live camera feed.
  Widget buildPreview();

  /// Start streaming frames for pose detection.
  Future<void> startFrameStream(void Function(PoseInput input) onFrame);

  /// Stop the frame stream.
  Future<void> stopFrameStream();

  /// Preview dimensions (width x height) for skeleton overlay scaling.
  Size get previewSize;

  /// Whether the front/selfie camera is active (for mirroring).
  bool get isFrontCamera;

  /// Start recording video to a file. Returns immediately.
  Future<void> startVideoRecording() async {}

  /// Stop recording and return the file path of the recorded video.
  /// Returns null if recording was not supported or failed.
  Future<String?> stopVideoRecording() async => null;

  /// Release camera resources.
  void dispose();
}
