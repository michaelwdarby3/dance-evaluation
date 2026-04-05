import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/multi_pose_sequence.dart';
import 'package:dance_evaluation/core/utils/person_tracker.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';

/// The current phase of the capture workflow.
enum CaptureState { idle, countdown, recording, processing, done }

/// Manages the capture lifecycle: countdown, recording, and pose collection.
class CaptureController extends ChangeNotifier {
  CaptureController({
    required PoseDetector poseDetector,
    int countdownDuration = 3,
    int maxRecordingDuration = 30,
  })  : _poseDetector = poseDetector,
        _initialCountdown = countdownDuration,
        _maxSeconds = maxRecordingDuration;

  final PoseDetector _poseDetector;
  int _initialCountdown;
  int _maxSeconds;

  /// When set, the recording auto-stops this long after the reference ends.
  static const _autoStopBuffer = Duration(milliseconds: 1500);

  /// Reference choreography duration. When set, recording auto-stops at
  /// [_referenceDuration] + [_autoStopBuffer].
  Duration? _referenceDuration;

  /// Set the reference choreography duration for auto-stop behavior.
  void setReferenceDuration(Duration? d) => _referenceDuration = d;

  /// Update configurable durations (e.g. from settings changes).
  void updateDurations({int? countdownSeconds, int? maxRecordingSeconds}) {
    if (countdownSeconds != null) _initialCountdown = countdownSeconds;
    if (maxRecordingSeconds != null) _maxSeconds = maxRecordingSeconds;
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  CaptureState _state = CaptureState.idle;
  CaptureState get state => _state;

  PoseFrame? _currentFrame;
  PoseFrame? get currentFrame => _currentFrame;

  /// Path/URL of the recorded video file, available after recording stops.
  // ignore: unnecessary_getters_setters
  String? videoPath;

  final List<PoseFrame> _recordedFrames = [];
  List<PoseFrame> get recordedFrames => List.unmodifiable(_recordedFrames);

  // Multi-person tracking state.
  final PersonTracker _personTracker = PersonTracker();
  Map<int, PoseFrame> _currentTrackedPersons = {};
  Map<int, PoseFrame> get currentTrackedPersons => Map.unmodifiable(_currentTrackedPersons);
  final Map<int, List<PoseFrame>> _recordedPersonFrames = {};
  bool _isMultiPerson = false;
  bool get isMultiPerson => _isMultiPerson;

  int _countdownSeconds = 3;
  int get countdownSeconds => _countdownSeconds;

  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  /// Maximum recording duration.
  Duration get maxDuration => Duration(seconds: _maxSeconds);

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
    _countdownSeconds = _initialCountdown;
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
    _recordedPersonFrames.clear();
    _personTracker.reset();
    _isMultiPerson = false;
    videoPath = null;
    _recordingDuration = Duration.zero;
    _recordingElapsed = Duration.zero;
    _state = CaptureState.recording;

    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recordingElapsed += const Duration(milliseconds: 100);
      _recordingDuration = _recordingElapsed;
      notifyListeners();

      // Auto-stop: reference duration + buffer takes priority, then max.
      final refLimit = _referenceDuration != null
          ? _referenceDuration! + _autoStopBuffer
          : null;
      if (refLimit != null && _recordingDuration >= refLimit) {
        stopRecording();
      } else if (_recordingDuration >= maxDuration) {
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
    _recordedPersonFrames.clear();
    _personTracker.reset();
    _isMultiPerson = false;
    videoPath = null;
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
  // Multi-person pose handling
  // ---------------------------------------------------------------------------

  /// Called for every multi-person detection. Tracks persons and records.
  void onMultiPoseDetected(List<PoseFrame> frames) {
    final tracked = _personTracker.track(frames);
    _currentTrackedPersons = tracked;

    if (tracked.length > 1) _isMultiPerson = true;

    if (_state == CaptureState.recording) {
      for (final entry in tracked.entries) {
        final timestamped = PoseFrame(
          landmarks: entry.value.landmarks,
          timestamp: _recordingElapsed,
        );
        _recordedPersonFrames
            .putIfAbsent(entry.key, () => [])
            .add(timestamped);
      }
      // Also record first person in legacy list for backwards compat.
      if (tracked.isNotEmpty) {
        final firstFrame = tracked.values.first;
        final timestamped = PoseFrame(
          landmarks: firstFrame.landmarks,
          timestamp: _recordingElapsed,
        );
        _recordedFrames.add(timestamped);
      }
    }

    _currentFrame = tracked.isNotEmpty ? tracked.values.first : null;
    notifyListeners();
  }

  /// Adds externally-provided multi-person frames (from video upload).
  void addExternalMultiFrames(List<PoseFrame> frames) {
    if (_state != CaptureState.recording) return;

    final tracked = _personTracker.track(frames);
    _currentTrackedPersons = tracked;

    if (tracked.length > 1) _isMultiPerson = true;

    for (final entry in tracked.entries) {
      _recordedPersonFrames
          .putIfAbsent(entry.key, () => [])
          .add(entry.value);
    }

    // Also record first person in legacy list.
    if (frames.isNotEmpty) {
      _recordedFrames.add(frames.first);
      _recordingElapsed = frames.first.timestamp;
      _recordingDuration = frames.first.timestamp;
      _currentFrame = frames.first;
    }
    notifyListeners();
  }

  /// Builds a [MultiPoseSequence] from the recorded multi-person frames.
  MultiPoseSequence getRecordedMultiSequence() {
    if (_recordedPersonFrames.isEmpty) {
      return MultiPoseSequence.fromSingle(getRecordedSequence());
    }

    final durationMs = _recordedFrames.isNotEmpty
        ? _recordedFrames.last.timestamp.inMilliseconds
        : 0;

    final personSequences = _recordedPersonFrames.entries.map((entry) {
      final frames = entry.value;
      final fps = durationMs > 0 ? (frames.length * 1000.0) / durationMs : 0.0;
      return PoseSequence(
        frames: List.unmodifiable(frames),
        fps: fps,
        duration: Duration(milliseconds: durationMs),
        label: 'person_${entry.key}',
      );
    }).toList();

    final fps =
        durationMs > 0 ? (_recordedFrames.length * 1000.0) / durationMs : 0.0;

    return MultiPoseSequence(
      personSequences: personSequences,
      fps: fps,
      duration: Duration(milliseconds: durationMs),
    );
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
    _recordedPersonFrames.clear();
    _personTracker.reset();
    _currentTrackedPersons = {};
    _isMultiPerson = false;
    videoPath = null;
    _currentFrame = null;
    _recordingDuration = Duration.zero;
    _recordingElapsed = Duration.zero;
    _countdownSeconds = _initialCountdown;
    _referenceDuration = null;
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
