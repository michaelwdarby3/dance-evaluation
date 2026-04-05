import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/services/audio_service.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/capture_settings_panel.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/multi_skeleton_painter.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/reference_ghost_painter.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/skeleton_painter.dart';

/// Full-screen camera capture with real-time skeleton overlay.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.referenceKey, this.mode = 'evaluate'});

  final String? referenceKey;

  /// 'evaluate' (default) navigates to evaluation when done.
  /// 'reference' navigates to create-reference with captured poses.
  final String mode;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraSource? _cameraSource;
  CaptureController? _captureController;
  PoseDetector? _poseDetector;

  bool _isInitialized = false;
  bool _isProcessing = false;
  int _frameCount = 0;

  String? _errorMessage;

  ReferenceChoreography? _reference;
  AudioService? _audioService;
  SettingsService? _settingsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadReference();
  }

  Future<void> _loadReference() async {
    final key = widget.referenceKey;
    if (key == null) return;
    try {
      final repo = ServiceLocator.instance.get<ReferenceRepository>();
      final ref = await repo.load(key);
      if (!mounted) return;
      setState(() => _reference = ref);

      // Tell the controller about reference duration for auto-stop.
      _captureController?.setReferenceDuration(ref.poses.duration);

      // Load settings and prepare audio.
      _settingsService = ServiceLocator.instance.get<SettingsService>();
      _audioService = ServiceLocator.instance.get<AudioService>();
      await _audioService!.prepare(ref);
    } catch (e) {
      // Reference/audio load failure shouldn't block capture, but inform user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load reference: $e'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSource?.stopFrameStream().catchError((_) {});
    _cameraSource?.dispose();
    _captureController?.removeListener(_onControllerChanged);
    _audioService?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraSource?.dispose();
      setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera initialisation
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    try {
      final sl = ServiceLocator.instance;
      final cameraSource = sl.get<CameraSource>();
      final poseDetector = sl.get<PoseDetector>();
      final captureController = sl.get<CaptureController>();

      await cameraSource.initialize();
      if (!mounted) return;

      _cameraSource = cameraSource;
      _poseDetector = poseDetector;
      _captureController = captureController;

      // Load settings early so they're available before reference loads.
      try {
        _settingsService ??= sl.get<SettingsService>();
        // Sync configurable durations from settings into controller.
        captureController.updateDurations(
          countdownSeconds: _settingsService?.countdownSeconds,
          maxRecordingSeconds: _settingsService?.maxRecordingSeconds,
        );
      } catch (_) {
        // Settings may not be registered in test environments.
      }
      _captureController!.addListener(_onControllerChanged);

      await cameraSource.startFrameStream(_onFrame);

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  CaptureState? _previousState;

  void _onControllerChanged() {
    if (mounted) setState(() {});

    final ctrl = _captureController;
    if (ctrl == null) return;

    final settings = _settingsService;
    final haptic = settings?.hapticFeedback ?? true;

    // Haptic on countdown ticks.
    if (haptic &&
        ctrl.state == CaptureState.countdown &&
        _previousState == CaptureState.countdown) {
      HapticFeedback.lightImpact();
    }

    // Start audio and video recording when recording begins.
    if (ctrl.state == CaptureState.recording &&
        _previousState != CaptureState.recording) {
      if (haptic) HapticFeedback.heavyImpact();
      if (settings == null || settings.audioEnabled) {
        _audioService?.play();
      }
      if (settings == null || settings.videoRecording) {
        _cameraSource?.startVideoRecording();
      }
    }

    // Stop audio and video recording when recording ends.
    if (ctrl.state == CaptureState.done &&
        _previousState != CaptureState.done) {
      if (haptic) HapticFeedback.mediumImpact();
      _audioService?.stop();
      if (settings == null || settings.videoRecording) {
        _cameraSource?.stopVideoRecording().then((path) {
          if (path != null) {
            ctrl.videoPath = path;
          }
        });
      }
    }

    _previousState = ctrl.state;

    // Navigate away when recording is done.
    if (ctrl.state == CaptureState.done) {
      Future.microtask(() {
        if (mounted) {
          if (widget.mode == 'reference') {
            context.go('/create-reference?fromCapture=true');
          } else {
            final refParam = widget.referenceKey != null
                ? '?ref=${widget.referenceKey}'
                : '';
            context.go('/evaluation/latest$refParam');
          }
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Frame stream → pose detection (throttled to every 2nd frame)
  // ---------------------------------------------------------------------------

  void _onFrame(PoseInput input) {
    _frameCount++;
    if (_frameCount % 2 != 0) return;
    if (_isProcessing) return;
    _isProcessing = true;

    _processFrame(input).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(PoseInput input) async {
    final ctrl = _captureController;
    final detector = _poseDetector;
    if (ctrl == null || detector == null) return;

    final useMulti = _settingsService?.multiPersonDetection ?? true;

    if (useMulti) {
      final frames = await detector.detectMultiPose(input);
      if (frames.isNotEmpty) {
        ctrl.onMultiPoseDetected(frames);
      }
    } else {
      final frame = await detector.detectPose(input);
      if (frame != null) {
        ctrl.onPoseDetected(frame);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 18, color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _initCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraSource == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final camera = _cameraSource!;
    final capture = _captureController!;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (optionally mirrored).
          if (_settingsService?.mirrorPreview ?? true)
            Transform.flip(flipX: true, child: camera.buildPreview())
          else
            camera.buildPreview(),

          // Reference ghost overlay (shown during recording).
          if (_reference != null &&
              capture.state == CaptureState.recording &&
              (_settingsService?.referenceGhost ?? true))
            CustomPaint(
              painter: ReferenceGhostPainter(
                referenceSequence: _reference!.poses,
                elapsed: capture.recordingDuration,
                canvasSize: MediaQuery.of(context).size,
                opacity: _settingsService?.ghostOpacity ?? 0.5,
                mirror: _settingsService?.mirrorSkeleton ?? false,
              ),
            ),

          // Skeleton overlay.
          // Mirror the live overlay when both the video preview is mirrored
          // AND we have a front camera, so the skeleton tracks the video.
          if ((_settingsService?.skeletonOverlay ?? true)) ...[
            if (capture.currentTrackedPersons.isNotEmpty)
              CustomPaint(
                painter: MultiSkeletonPainter(
                  trackedPersons: capture.currentTrackedPersons,
                  imageSize: camera.previewSize,
                  rotationDegrees: 0,
                  isFrontCamera: camera.isFrontCamera &&
                      (_settingsService?.mirrorPreview ?? false),
                ),
              )
            else if (capture.currentFrame != null)
              CustomPaint(
                painter: SkeletonPainter(
                  currentFrame: capture.currentFrame,
                  imageSize: camera.previewSize,
                  rotationDegrees: 0,
                  isFrontCamera: camera.isFrontCamera &&
                      (_settingsService?.mirrorPreview ?? false),
                ),
              ),
          ],

          // Countdown overlay.
          if (capture.state == CaptureState.countdown)
            Center(
              child: Text(
                '${capture.countdownSeconds}',
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 20, color: Colors.black54),
                  ],
                ),
              ),
            ),

          // Top bar: back button and timer.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      capture.reset();
                      if (widget.mode == 'reference') {
                        context.go('/create-reference');
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const Spacer(),
                  if (_reference != null && capture.state == CaptureState.idle)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBB86FC).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _reference!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (capture.state == CaptureState.recording)
                    _buildTimerDisplay(capture),
                ],
              ),
            ),
          ),

          // Bottom: settings panel + record button.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_settingsService != null &&
                      capture.state == CaptureState.idle)
                    CaptureSettingsPanel(
                      settings: _settingsService!,
                      onChanged: () {
                        // Re-sync durations if countdown/recording changed.
                        _captureController?.updateDurations(
                          countdownSeconds:
                              _settingsService?.countdownSeconds,
                          maxRecordingSeconds:
                              _settingsService?.maxRecordingSeconds,
                        );
                        setState(() {});
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    child: _buildRecordButton(capture),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(CaptureController capture) {
    final elapsed = capture.recordingDuration;
    final elapsedMin = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final elapsedSec = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    final refDur = _reference?.poses.duration;
    final pastRef = refDur != null && elapsed > refDur;

    // Show "elapsed / total" when a reference is loaded.
    String timerText = '$elapsedMin:$elapsedSec';
    if (refDur != null) {
      final totalSec = refDur.inSeconds;
      final totalMin = (totalSec ~/ 60).toString().padLeft(2, '0');
      final totalRemSec = (totalSec % 60).toString().padLeft(2, '0');
      timerText = '$elapsedMin:$elapsedSec / $totalMin:$totalRemSec';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pastRef ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pastRef ? Icons.check_circle : Icons.fiber_manual_record,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            timerText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton(CaptureController capture) {
    final isRecording = capture.state == CaptureState.recording;
    final isIdle = capture.state == CaptureState.idle;

    return GestureDetector(
      onTap: () {
        if (isIdle) {
          capture.startCountdown();
        } else if (isRecording) {
          capture.stopRecording();
        }
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 28 : 56,
            height: isRecording ? 28 : 56,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius:
                  BorderRadius.circular(isRecording ? 6 : 28),
            ),
          ),
        ),
      ),
    );
  }
}
