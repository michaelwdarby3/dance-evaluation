import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';

import 'video_pose_extractor.dart';

VideoPoseExtractor createVideoPoseExtractor() => MobileVideoPoseExtractor();

/// Extracts poses from a video file on mobile platforms.
class MobileVideoPoseExtractor extends VideoPoseExtractor {
  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    // TODO: Implement using video_player + MLKit pose detection per frame.
    // For M1, the primary flow is live capture, not video upload.
    debugPrint(
        'MobileVideoPoseExtractor: video extraction not yet implemented on mobile');
    throw UnsupportedError('Video pose extraction is not yet available on mobile');
  }

  @override
  void dispose() {}
}
