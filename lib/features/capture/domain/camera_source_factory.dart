export 'camera_source_stub.dart'
    if (dart.library.js_interop) 'camera_source_web.dart'
    if (dart.library.io) 'camera_source_mobile.dart';
