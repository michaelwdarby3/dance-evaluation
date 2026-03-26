import 'package:flutter/widgets.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/core/services/sharing_service.dart';

/// A pose detector that always returns null (no pose detected).
class FakePoseDetector extends PoseDetector {
  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => null;

  @override
  Future<List<PoseFrame>> detectMultiPose(PoseInput input) async => [];

  @override
  void dispose() {}
}

/// A camera source that returns a placeholder widget and no-ops streams.
class FakeCameraSource extends CameraSource {
  @override
  Future<void> initialize() async {}

  @override
  Widget buildPreview() => const SizedBox(width: 320, height: 240);

  @override
  Future<void> startFrameStream(void Function(PoseInput input) onFrame) async {}

  @override
  Future<void> stopFrameStream() async {}

  @override
  Size get previewSize => const Size(320, 240);

  @override
  bool get isFrontCamera => true;

  @override
  void dispose() {}
}

/// A video file picker that always returns null (cancelled).
class FakeVideoFilePicker extends VideoFilePicker {
  @override
  Future<String?> pickVideo() async => null;

  @override
  void dispose() {}
}

/// A video pose extractor that returns Duration.zero immediately.
class FakeVideoPoseExtractor extends VideoPoseExtractor {
  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    return Duration.zero;
  }

  @override
  void dispose() {}
}

/// A sharing service that no-ops everything.
class FakeSharingService extends SharingService {
  @override
  Future<void> shareText(String text) async {}

  @override
  Future<void> saveJsonFile(String jsonString, String fileName) async {}

  @override
  Future<String?> pickJsonFile() async => null;
}
