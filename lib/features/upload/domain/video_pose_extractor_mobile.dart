import 'dart:io';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';

import 'video_pose_extractor.dart';

VideoPoseExtractor createVideoPoseExtractor() => MobileVideoPoseExtractor();

/// Extracts poses from a video file on mobile using video_thumbnail + MLKit.
///
/// Strategy:
/// 1. Use VideoPlayerController to get the video duration.
/// 2. Step through the video at ~10fps using video_thumbnail to extract frames.
/// 3. Feed each frame image to MLKit pose detection.
class MobileVideoPoseExtractor extends VideoPoseExtractor {
  static const double _extractionFps = 10.0;

  final mlkit.PoseDetector _detector = mlkit.PoseDetector(
    options: mlkit.PoseDetectorOptions(
      mode: mlkit.PoseDetectionMode.single,
      model: mlkit.PoseDetectionModel.accurate,
    ),
  );

  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    final totalDuration = await _getVideoDuration(videoUrl);
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      throw Exception('Could not determine video duration');
    }

    final stepMs = (1000.0 / _extractionFps).round();
    final tempDir = await getTemporaryDirectory();
    final thumbDir = Directory('${tempDir.path}/pose_extract');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    var currentMs = 0;
    while (currentMs < totalMs) {
      final framePath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        timeMs: currentMs,
        quality: 85,
      );

      if (framePath != null) {
        final inputImage = mlkit.InputImage.fromFilePath(framePath);
        final poses = await _detector.processImage(inputImage);

        if (poses.isNotEmpty) {
          final frame = _poseToFrame(poses.first, currentMs);
          onFrame(frame);
        }

        // Clean up temp frame file.
        try {
          await File(framePath).delete();
        } catch (_) {}
      }

      currentMs += stepMs;
      onProgress((currentMs / totalMs).clamp(0.0, 1.0));
    }

    // Clean up temp directory.
    try {
      await thumbDir.delete(recursive: true);
    } catch (_) {}

    return totalDuration;
  }

  @override
  Future<Duration> extractMultiPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(List<PoseFrame> frames) onFrames,
  }) async {
    final totalDuration = await _getVideoDuration(videoUrl);
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      throw Exception('Could not determine video duration');
    }

    final stepMs = (1000.0 / _extractionFps).round();
    final tempDir = await getTemporaryDirectory();
    final thumbDir = Directory('${tempDir.path}/pose_extract');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    var currentMs = 0;
    while (currentMs < totalMs) {
      final framePath = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        timeMs: currentMs,
        quality: 85,
      );

      if (framePath != null) {
        final inputImage = mlkit.InputImage.fromFilePath(framePath);
        final poses = await _detector.processImage(inputImage);

        if (poses.isNotEmpty) {
          final frames = poses
              .map((pose) => _poseToFrame(pose, currentMs))
              .toList();
          onFrames(frames);
        }

        try {
          await File(framePath).delete();
        } catch (_) {}
      }

      currentMs += stepMs;
      onProgress((currentMs / totalMs).clamp(0.0, 1.0));
    }

    try {
      await thumbDir.delete(recursive: true);
    } catch (_) {}

    return totalDuration;
  }

  /// Gets video duration using VideoPlayerController.
  Future<Duration> _getVideoDuration(String videoUrl) async {
    final controller = VideoPlayerController.file(File(videoUrl));
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  /// Converts an MLKit Pose to a normalized PoseFrame.
  PoseFrame _poseToFrame(mlkit.Pose pose, int timestampMs) {
    final sortedTypes = List<mlkit.PoseLandmarkType>.from(
      mlkit.PoseLandmarkType.values,
    )..sort((a, b) => a.index.compareTo(b.index));

    // MLKit fromFilePath doesn't give us image dimensions directly.
    // We need to normalize using the bounding box of all landmarks.
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final type in sortedTypes) {
      final lm = pose.landmarks[type];
      if (lm != null) {
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
        if (lm.y < minY) minY = lm.y;
        if (lm.y > maxY) maxY = lm.y;
      }
    }

    // Use image dimensions from the thumbnail (480 wide, proportional height).
    // MLKit returns pixel coordinates relative to the input image.
    // We normalize to 0-1 range using the image width as reference.
    // Since we requested maxWidth=480, use that as a reasonable estimate.
    // The actual normalization just needs consistency — the DTW comparison
    // works on relative positions, so the exact scale doesn't matter much.
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final imageSize = rangeX > rangeY ? rangeX * 1.5 : rangeY * 1.5;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    final landmarks = <Landmark>[];
    for (final type in sortedTypes) {
      final lm = pose.landmarks[type];
      if (lm != null) {
        landmarks.add(Landmark(
          x: imageSize > 0 ? (lm.x - centerX) / imageSize + 0.5 : 0.5,
          y: imageSize > 0 ? (lm.y - centerY) / imageSize + 0.5 : 0.5,
          z: lm.z,
          visibility: lm.likelihood,
        ),);
      } else {
        landmarks.add(
          const Landmark(x: 0, y: 0, z: 0, visibility: 0),
        );
      }
    }

    return PoseFrame(
      landmarks: landmarks,
      timestamp: Duration(milliseconds: timestampMs),
    );
  }

  @override
  void dispose() {
    _detector.close();
  }
}
