import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'video_file_picker.dart';

VideoFilePicker createVideoFilePicker() => WebVideoFilePicker();

class WebVideoFilePicker implements VideoFilePicker {
  @override
  Future<String?> pickVideo() async {
    final completer = Completer<String?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'video/*';

    input.addEventListener(
      'change',
      (web.Event e) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0)!;
          final url = web.URL.createObjectURL(file);
          completer.complete(url);
        } else {
          completer.complete(null);
        }
      }.toJS,
    );

    // Also handle cancel (user closes the dialog without selecting).
    input.addEventListener(
      'cancel',
      (web.Event e) {
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    input.click();
    return completer.future;
  }

  @override
  void dispose() {}
}
