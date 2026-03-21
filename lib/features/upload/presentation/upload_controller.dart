import 'package:flutter/foundation.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
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

  PoseFrame? _latestFrame;
  PoseFrame? get latestFrame => _latestFrame;

  int _personsInLatestFrame = 0;
  int get personsInLatestFrame => _personsInLatestFrame;

  DateTime? _processingStartTime;

  /// Estimated seconds remaining, or null if not enough data.
  double? get estimatedSecondsRemaining {
    if (_progress <= 0.01 || _processingStartTime == null) return null;
    final elapsed =
        DateTime.now().difference(_processingStartTime!).inMilliseconds;
    final totalEstimate = elapsed / _progress;
    final remaining = (totalEstimate - elapsed) / 1000.0;
    return remaining > 0 ? remaining : 0;
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Pick a video file and extract poses from it.
  Future<void> pickAndProcess() async {
    _state = UploadState.picking;
    _progress = 0.0;
    _frameCount = 0;
    _latestFrame = null;
    _personsInLatestFrame = 0;
    _processingStartTime = null;
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
      _processingStartTime = DateTime.now();
      notifyListeners();

      _capture.startExternalRecording();
      _capture.videoPath = videoUrl;

      await _extractor.extractMultiPoses(
        videoUrl: videoUrl,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
        onFrames: (frames) {
          _capture.addExternalMultiFrames(frames);
          _frameCount++;
          _personsInLatestFrame = frames.length;
          if (frames.isNotEmpty) {
            _latestFrame = frames.first;
          }
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
    _latestFrame = null;
    _personsInLatestFrame = 0;
    _processingStartTime = null;
    _errorMessage = null;
    notifyListeners();
  }
}
