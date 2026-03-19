import 'package:flutter/foundation.dart';

import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';

enum UploadState { idle, picking, processing, done, error }

class UploadController extends ChangeNotifier {
  UploadController({
    required VideoFilePicker videoFilePicker,
    required VideoPoseExtractor videoPoseExtractor,
    required CaptureController captureController,
  })  : _picker = videoFilePicker,
        _extractor = videoPoseExtractor,
        _capture = captureController;

  final VideoFilePicker _picker;
  final VideoPoseExtractor _extractor;
  final CaptureController _capture;

  UploadState _state = UploadState.idle;
  UploadState get state => _state;

  double _progress = 0.0;
  double get progress => _progress;

  int _frameCount = 0;
  int get frameCount => _frameCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Pick a video file and extract poses from it.
  Future<void> pickAndProcess() async {
    _state = UploadState.picking;
    _progress = 0.0;
    _frameCount = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      final videoUrl = await _picker.pickVideo();
      if (videoUrl == null) {
        _state = UploadState.idle;
        notifyListeners();
        return;
      }

      _state = UploadState.processing;
      notifyListeners();

      _capture.startExternalRecording();

      await _extractor.extractMultiPoses(
        videoUrl: videoUrl,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
        onFrames: (frames) {
          _capture.addExternalMultiFrames(frames);
          _frameCount++;
        },
      );

      _capture.stopRecording();
      _state = UploadState.done;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _state = UploadState.error;
      notifyListeners();
    }
  }

  void reset() {
    _state = UploadState.idle;
    _progress = 0.0;
    _frameCount = 0;
    _errorMessage = null;
    notifyListeners();
  }
}
