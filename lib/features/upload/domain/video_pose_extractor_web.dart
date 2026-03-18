import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'video_pose_extractor.dart';

VideoPoseExtractor createVideoPoseExtractor() => WebVideoPoseExtractor();

/// JS interop for pose_bridge.js detectPoseAtTime.
@JS('poseBridge.detectPoseAtTime')
external JSPromise<JSAny?> _jsDetectPoseAtTime(
    web.HTMLVideoElement video, JSNumber timestampMs);

@JS('poseBridge.isReady')
external JSFunction? get _isReadyFn;

@JS()
@anonymous
extension type _JsLandmark._(JSObject _) implements JSObject {
  external JSNumber get x;
  external JSNumber get y;
  external JSNumber get z;
  external JSNumber get visibility;
}

class WebVideoPoseExtractor implements VideoPoseExtractor {
  static const double _extractionFps = 10.0;

  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async {
    // Wait for MediaPipe bridge to be ready.
    await _waitForBridge();

    // Create a hidden video element and load the file.
    final video =
        web.document.createElement('video') as web.HTMLVideoElement;
    video.src = videoUrl;
    video.muted = true;
    video.playsInline = true;
    video.preload = 'auto';

    // Wait for metadata to load so we know the duration.
    await _waitForEvent(video, 'loadeddata');

    final totalSeconds = video.duration;
    if (totalSeconds.isNaN || totalSeconds.isInfinite || totalSeconds <= 0) {
      throw Exception('Could not determine video duration');
    }

    final totalDuration = Duration(
      milliseconds: (totalSeconds * 1000).round(),
    );
    final stepSeconds = 1.0 / _extractionFps;

    var currentTime = 0.0;

    while (currentTime < totalSeconds) {
      // Seek to the target time.
      video.currentTime = currentTime;
      await _waitForEvent(video, 'seeked');

      // Run pose detection at this frame.
      final timestampMs = (currentTime * 1000).roundToDouble();
      final resultJs =
          await _jsDetectPoseAtTime(video, timestampMs.toJS).toDart;

      if (resultJs != null) {
        final landmarksJs = resultJs as JSArray;
        if (landmarksJs.length >= 33) {
          final landmarks = <Landmark>[];
          for (var i = 0; i < 33; i++) {
            final lm = landmarksJs[i] as _JsLandmark;
            landmarks.add(Landmark(
              x: lm.x.toDartDouble,
              y: lm.y.toDartDouble,
              z: lm.z.toDartDouble,
              visibility: lm.visibility.toDartDouble,
            ));
          }
          onFrame(PoseFrame(
            landmarks: landmarks,
            timestamp: Duration(milliseconds: timestampMs.round()),
          ));
        }
      }

      currentTime += stepSeconds;
      onProgress((currentTime / totalSeconds).clamp(0.0, 1.0));
    }

    // Clean up.
    video.src = '';
    web.URL.revokeObjectURL(videoUrl);

    return totalDuration;
  }

  Future<void> _waitForBridge() async {
    for (var i = 0; i < 100; i++) {
      if (_isReadyFn != null) {
        final ready = (_isReadyFn!).callAsFunction() as JSBoolean;
        if (ready.toDart) return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('MediaPipe Pose JS bridge failed to initialize');
  }

  Future<void> _waitForEvent(web.HTMLVideoElement video, String event) {
    final completer = Completer<void>();
    late final JSFunction listener;
    listener = (web.Event e) {
      completer.complete();
      video.removeEventListener(event, listener);
    }.toJS;
    video.addEventListener(event, listener);
    return completer.future;
  }

  @override
  void dispose() {}
}
