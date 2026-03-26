import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sharing_service.dart';

SharingService createSharingService() => WebSharingService();

class WebSharingService implements SharingService {
  @override
  Future<void> shareText(String text) async {
    await web.window.navigator.clipboard.writeText(text).toDart;
  }

  @override
  Future<void> saveJsonFile(String jsonString, String fileName) async {
    final bytes = utf8.encode(jsonString);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();

    web.URL.revokeObjectURL(url);
  }

  @override
  Future<String?> pickJsonFile() async {
    final completer = Completer<String?>();

    final input =
        web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.json,application/json';

    input.addEventListener(
      'change',
      (web.Event e) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0)!;
          final reader = web.FileReader();
          reader.addEventListener(
            'load',
            (web.Event _) {
              completer.complete(reader.result as String?);
            }.toJS,
          );
          reader.readAsText(file);
        } else {
          completer.complete(null);
        }
      }.toJS,
    );

    input.addEventListener(
      'cancel',
      (web.Event e) {
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    input.click();
    return completer.future;
  }
}
