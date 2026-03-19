import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'reference_storage.dart';

const _prefix = 'dance_eval_ref_';

ReferenceStorage createReferenceStorage() => WebReferenceStorage();

class WebReferenceStorage extends ReferenceStorage {
  @override
  void save(String key, String json) {
    web.window.localStorage.setItem('$_prefix$key', json);
  }

  @override
  Map<String, String> loadAll() {
    final storage = web.window.localStorage;
    final result = <String, String>{};

    for (var i = 0; i < storage.length; i++) {
      final rawKey = storage.key(i);
      if (rawKey != null && rawKey.startsWith(_prefix)) {
        final value = storage.getItem(rawKey);
        if (value != null) {
          result[rawKey.substring(_prefix.length)] = value;
        }
      }
    }

    return result;
  }

  @override
  void delete(String key) {
    web.window.localStorage.removeItem('$_prefix$key');
  }
}
