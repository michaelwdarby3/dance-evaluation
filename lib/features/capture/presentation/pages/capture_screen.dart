import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/multi_skeleton_painter.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/skeleton_painter.dart';

/// Full-screen camera capture with real-time skeleton overlay.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.referenceKey});

  final String? referenceKey;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSource?.stopFrameStream().catchError((_) {});
    _cameraSource?.dispose();
    _captureController?.removeListener(_onControllerChanged);
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
      _captureController!.addListener(_onControllerChanged);

      await cameraSource.startFrameStream(_onFrame);

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});

    // Navigate away when recording is done.
    final ctrl = _captureController;
    if (ctrl != null && ctrl.state == CaptureState.done) {
      Future.microtask(() {
        if (mounted) {
          final refParam = widget.referenceKey != null
              ? '?ref=${widget.referenceKey}'
              : '';
          context.go('/evaluation/latest$refParam');
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

    final frames = await detector.detectMultiPose(input);
    if (frames.isNotEmpty) {
      ctrl.onMultiPoseDetected(frames);
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
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 18, color: Colors.redAccent),
              textAlign: TextAlign.center,
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
          // Camera preview.
          camera.buildPreview(),

          // Skeleton overlay.
          if (capture.currentTrackedPersons.isNotEmpty)
            CustomPaint(
              painter: MultiSkeletonPainter(
                trackedPersons: capture.currentTrackedPersons,
                imageSize: camera.previewSize,
                rotationDegrees: 0,
                isFrontCamera: camera.isFrontCamera,
              ),
            )
          else if (capture.currentFrame != null)
            CustomPaint(
              painter: SkeletonPainter(
                currentFrame: capture.currentFrame,
                imageSize: camera.previewSize,
                rotationDegrees: 0,
                isFrontCamera: camera.isFrontCamera,
              ),
            ),

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
                      context.pop();
                    },
                  ),
                  const Spacer(),
                  if (capture.state == CaptureState.recording)
                    _buildTimerDisplay(capture),
                ],
              ),
            ),
          ),

          // Bottom controls: record button.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(child: _buildRecordButton(capture)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(CaptureController capture) {
    final elapsed = capture.recordingDuration;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '$minutes:$seconds',
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
