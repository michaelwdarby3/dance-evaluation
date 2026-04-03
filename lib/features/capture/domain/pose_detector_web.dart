import 'dart:async';
import 'dart:js_interop';

import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:web/web.dart' as web;

import 'pose_detector.dart';

/// Creates the web (MediaPipe JS) pose detector.
PoseDetector createPoseDetector() => WebPoseDetector();

/// JS interop for pose_bridge.js — use extension type to preserve `this`.
@JS('poseBridge')
external _PoseBridge? get _poseBridge;

extension type _PoseBridge._(JSObject _) implements JSObject {
  external JSBoolean isReady();
  external JSAny? detectPose(web.HTMLVideoElement video);
  external JSAny? detectMultiPose(web.HTMLVideoElement video);
}

class WebPoseDetector implements PoseDetector {
  bool _disposed = false;

  Future<void> _waitForBridge() async {
    // Wait up to 10 seconds for the JS bridge to initialise.
    for (var i = 0; i < 100; i++) {
      final bridge = _poseBridge;
      if (bridge != null && bridge.isReady().toDart) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('MediaPipe Pose JS bridge failed to initialize');
  }

  @override
  Future<PoseFrame?> detectPose(PoseInput input) async {
    if (_disposed) return null;

    await _waitForBridge();

    final video = input.platformData as web.HTMLVideoElement;
    final resultJs = _poseBridge!.detectPose(video);
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
  Future<List<PoseFrame>> detectMultiPose(PoseInput input) async {
    if (_disposed) return [];

    await _waitForBridge();

    final video = input.platformData as web.HTMLVideoElement;
    final resultJs = _poseBridge!.detectMultiPose(video);
    if (resultJs == null) return [];

    final personsJs = resultJs as JSArray;
    final persons = <PoseFrame>[];

    for (var p = 0; p < personsJs.length; p++) {
      final landmarksJs = personsJs[p] as JSArray;
      if (landmarksJs.length < 33) continue;

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

      persons.add(PoseFrame(landmarks: landmarks, timestamp: Duration.zero));
    }

    return persons;
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
