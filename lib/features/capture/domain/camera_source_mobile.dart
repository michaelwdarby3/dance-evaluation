import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'camera_source.dart';
import 'pose_detector.dart';

/// Creates the mobile camera source.
CameraSource createCameraSource() => MobileCameraSource();

class MobileCameraSource implements CameraSource {
  CameraController? _controller;
  CameraDescription? _camera;

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    _camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _camera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
  }

  @override
  Widget buildPreview() {
    return CameraPreview(_controller!);
  }

  @override
  Future<void> startFrameStream(void Function(PoseInput input) onFrame) async {
    final camera = _camera!;
    final rotation = _rotationFromSensor(camera.sensorOrientation);

    await _controller!.startImageStream((CameraImage image) {
      final plane = image.planes.first;
      final metadata = mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: mlkit.InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      );

      onFrame(PoseInput(
        width: image.width.toDouble(),
        height: image.height.toDouble(),
        bytes: plane.bytes,
        platformData: metadata,
      ));
    });
  }

  @override
  Future<void> stopFrameStream() async {
    await _controller?.stopImageStream().catchError((_) {});
  }

  @override
  Size get previewSize {
    final ps = _controller?.value.previewSize;
    // Camera package returns (height, width) — swap.
    return ps != null ? Size(ps.height, ps.width) : const Size(480, 640);
  }

  @override
  bool get isFrontCamera =>
      _camera?.lensDirection == CameraLensDirection.front;

  bool _isRecordingVideo = false;

  @override
  Future<void> startVideoRecording() async {
    if (_controller == null || _isRecordingVideo) return;
    try {
      await _controller!.startVideoRecording();
      _isRecordingVideo = true;
    } catch (_) {
      // Video recording may not be supported alongside image streaming
      // on some devices. Non-fatal.
    }
  }

  @override
  Future<String?> stopVideoRecording() async {
    if (_controller == null || !_isRecordingVideo) return null;
    try {
      _isRecordingVideo = false;
      final xFile = await _controller!.stopVideoRecording();
      return xFile.path;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
  }

  mlkit.InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return mlkit.InputImageRotation.rotation0deg;
      case 90:
        return mlkit.InputImageRotation.rotation90deg;
      case 180:
        return mlkit.InputImageRotation.rotation180deg;
      case 270:
        return mlkit.InputImageRotation.rotation270deg;
      default:
        return mlkit.InputImageRotation.rotation0deg;
    }
  }
}
