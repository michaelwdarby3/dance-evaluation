export 'pose_detector_stub.dart'
    if (dart.library.js_interop) 'pose_detector_web.dart'
    if (dart.library.io) 'pose_detector_mobile.dart';
