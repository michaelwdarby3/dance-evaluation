import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'video_file_picker.dart';

VideoFilePicker createVideoFilePicker() => MobileVideoFilePicker();

/// Picks a video file from the device gallery using the system intent.
class MobileVideoFilePicker implements VideoFilePicker {
  @override
  Future<String?> pickVideo() async {
    // Use a platform channel-free approach: launch a file intent.
    // For now, we use a simple approach that works without image_picker.
    // On Android, the camera plugin can record video, and users can also
    // share video files directly. This stub returns null (no picker UI).
    //
    // TODO: Add image_picker dependency for full gallery access.
    // For M1, the primary flow is live capture, not upload.
    debugPrint('MobileVideoFilePicker: video upload not yet implemented on mobile');
    return null;
  }

  @override
  void dispose() {}
}
