import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';

/// The current phase of the capture workflow.
enum CaptureState { idle, countdown, recording, processing, done }

/// Manages the capture lifecycle: countdown, recording, and pose collection.
class CaptureController extends ChangeNotifier {
  CaptureController({required PoseDetector poseDetector})
      : _poseDetector = poseDetector;

  final PoseDetector _poseDetector;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  CaptureState _state = CaptureState.idle;
  CaptureState get state => _state;

  PoseFrame? _currentFrame;
  PoseFrame? get currentFrame => _currentFrame;

  final List<PoseFrame> _recordedFrames = [];
  List<PoseFrame> get recordedFrames => List.unmodifiable(_recordedFrames);

  int _countdownSeconds = 3;
  int get countdownSeconds => _countdownSeconds;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  /// Maximum recording duration.
  static const Duration maxDuration = Duration(seconds: 30);

  PoseDetector get poseDetector => _poseDetector;

  Timer? _countdownTimer;
  Timer? _recordingTimer;
  Duration _recordingElapsed = Duration.zero;

  // ---------------------------------------------------------------------------
  // Countdown
  // ---------------------------------------------------------------------------

  /// Starts a 3-second countdown, then begins recording.
  Future<void> startCountdown() async {
    _state = CaptureState.countdown;
    _countdownSeconds = 3;
    notifyListeners();

    final completer = Completer<void>();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _startRecording();
        completer.complete();
      }
      notifyListeners();
    });

    return completer.future;
  }

  void _startRecording() {
    _recordedFrames.clear();
    _recordingDuration = Duration.zero;
    _recordingElapsed = Duration.zero;
    _state = CaptureState.recording;

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recordingElapsed += const Duration(milliseconds: 100);
      _recordingDuration = _recordingElapsed;
      notifyListeners();

      if (_recordingDuration >= maxDuration) {
        stopRecording();
      }
    });

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // External frame injection (for video upload processing)
  // ---------------------------------------------------------------------------

  /// Begins accepting externally-provided frames (skips countdown).
  void startExternalRecording() {
    _recordedFrames.clear();
    _recordingDuration = Duration.zero;
    _recordingElapsed = Duration.zero;
    _state = CaptureState.recording;
    notifyListeners();
  }

  /// Adds a frame with an explicit timestamp (from video extraction).
  void addExternalFrame(PoseFrame frame) {
    if (_state != CaptureState.recording) return;
    _recordedFrames.add(frame);
    _recordingElapsed = frame.timestamp;
    _recordingDuration = frame.timestamp;
    _currentFrame = frame;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Pose handling
  // ---------------------------------------------------------------------------

  /// Called for every detected pose. Updates the live preview frame and, if
  /// recording, appends the frame to the recorded list.
  void onPoseDetected(PoseFrame frame) {
    if (_state == CaptureState.recording) {
      final timestamped = PoseFrame(
        landmarks: frame.landmarks,
        timestamp: _recordingElapsed,
      );
      _recordedFrames.add(timestamped);
    }

    _currentFrame = frame;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Stop / result
  // ---------------------------------------------------------------------------

  /// Stops an active recording.
  void stopRecording() {
    _recordingTimer?.cancel();
    _state = CaptureState.done;
    notifyListeners();
  }

  /// Builds a [PoseSequence] from the recorded frames.
  PoseSequence getRecordedSequence() {
    final durationMs = _recordedFrames.isNotEmpty
        ? _recordedFrames.last.timestamp.inMilliseconds
        : 0;
    final fps =
        durationMs > 0 ? (_recordedFrames.length * 1000.0) / durationMs : 0.0;

    return PoseSequence(
      frames: List.unmodifiable(_recordedFrames),
      fps: fps,
      duration: Duration(milliseconds: durationMs),
    );
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets everything back to idle.
  void reset() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _recordedFrames.clear();
    _currentFrame = null;
    _recordingDuration = Duration.zero;
    _recordingElapsed = Duration.zero;
    _countdownSeconds = 3;
    _state = CaptureState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }
}
