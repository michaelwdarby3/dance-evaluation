export 'reference_storage_stub.dart'
    if (dart.library.js_interop) 'reference_storage_web.dart'
    if (dart.library.io) 'reference_storage_mobile.dart';
