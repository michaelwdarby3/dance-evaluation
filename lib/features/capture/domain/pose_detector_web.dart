import 'dart:async';
import 'dart:js_interop';

import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:web/web.dart' as web;

import 'pose_detector.dart';

/// Creates the web (MediaPipe JS) pose detector.
PoseDetector createPoseDetector() => WebPoseDetector();

/// JS interop bindings for the pose bridge in web/pose_bridge.js.
@JS('poseBridge.isReady')
external JSFunction? get _isReadyFn;

@JS('poseBridge.detectPose')
external JSPromise<JSAny?> _jsDetectPose(web.HTMLVideoElement video);

class WebPoseDetector implements PoseDetector {
  bool _disposed = false;

  Future<void> _waitForBridge() async {
    // Wait up to 10 seconds for the JS bridge to initialise.
    for (var i = 0; i < 100; i++) {
      if (_isReadyFn != null) {
        final ready = (_isReadyFn!).callAsFunction() as JSBoolean;
        if (ready.toDart) return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('MediaPipe Pose JS bridge failed to initialize');
  }

  @override
  Future<PoseFrame?> detectPose(PoseInput input) async {
    if (_disposed) return null;

    await _waitForBridge();

    final video = input.platformData as web.HTMLVideoElement;
    final resultJs = await _jsDetectPose(video).toDart;
    if (resultJs == null) return null;

    final landmarksJs = resultJs as JSArray;
    if (landmarksJs.length < 33) return null;

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

    return PoseFrame(landmarks: landmarks, timestamp: Duration.zero);
  }

  @override
  void dispose() {
    _disposed = true;
  }
}

@JS()
@anonymous
extension type _JsLandmark._(JSObject _) implements JSObject {
  external JSNumber get x;
  external JSNumber get y;
  external JSNumber get z;
  external JSNumber get visibility;
}
