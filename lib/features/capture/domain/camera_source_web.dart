import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'camera_source.dart';
import 'pose_detector.dart';

/// Creates the web camera source.
CameraSource createCameraSource() => WebCameraSource();

class WebCameraSource implements CameraSource {
  static const _viewType = 'dance-eval-camera';
  static var _registered = false;

  web.HTMLVideoElement? _video;
  Timer? _frameTimer;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video.setAttribute('autoplay', '');
    video.setAttribute('playsinline', '');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..transform = 'scaleX(-1)'; // Mirror front camera.

    final constraints = web.MediaStreamConstraints(
      video: {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      }.jsify()!,
    );

    final stream =
        await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    video.srcObject = stream;
    await video.play().toDart;

    _video = video;
    _initialized = true;

    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId, {Object? params}) => video,
      );
      _registered = true;
    }
  }

  @override
  Widget buildPreview() {
    return const HtmlElementView(viewType: _viewType);
  }

  @override
  Future<void> startFrameStream(void Function(PoseInput input) onFrame) async {
    final video = _video;
    if (video == null) return;

    // Deliver frames at ~15 fps (every ~67ms).
    _frameTimer = Timer.periodic(const Duration(milliseconds: 67), (_) {
      if (video.readyState >= 2) {
        // HAVE_CURRENT_DATA
        onFrame(PoseInput(
          width: video.videoWidth.toDouble(),
          height: video.videoHeight.toDouble(),
          platformData: video,
        ));
      }
    });
  }

  @override
  Future<void> stopFrameStream() async {
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  @override
  Size get previewSize {
    final v = _video;
    if (v != null && v.videoWidth > 0) {
      return Size(v.videoWidth.toDouble(), v.videoHeight.toDouble());
    }
    return const Size(640, 480);
  }

  @override
  bool get isFrontCamera => true; // Web defaults to user-facing camera.

  @override
  void dispose() {
    _frameTimer?.cancel();
    final video = _video;
    if (video != null) {
      final stream = video.srcObject;
      if (stream != null) {
        (stream as web.MediaStream)
            .getTracks()
            .toDart
            .forEach((track) => track.stop());
      }
      video.srcObject = null;
    }
    _video = null;
    _initialized = false;
  }
}
