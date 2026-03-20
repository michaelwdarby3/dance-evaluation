import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'reference_storage.dart';

ReferenceStorage createReferenceStorage() => MobileReferenceStorage();

/// Persists references as JSON files in the app's documents directory.
class MobileReferenceStorage extends ReferenceStorage {
  static const _dirName = 'user_references';

  Directory? _refDir;

  Future<Directory> _getDir() async {
    if (_refDir != null) return _refDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _refDir = Directory('${appDir.path}/$_dirName');
    if (!_refDir!.existsSync()) {
      _refDir!.createSync(recursive: true);
    }
    return _refDir!;
  }

  @override
  void save(String key, String json) {
    // Use sync I/O since the interface is synchronous.
    // _refDir should already be initialized by loadAll() at startup.
    if (_refDir == null) {
      // Fallback: create dir synchronously.
      final home = Directory.systemTemp;
      _refDir = Directory('${home.path}/$_dirName');
      if (!_refDir!.existsSync()) {
        _refDir!.createSync(recursive: true);
      }
    }
    File('${_refDir!.path}/$key').writeAsStringSync(json);
  }

  @override
  Map<String, String> loadAll() {
    final result = <String, String>{};
    try {
      // Initialize _refDir synchronously for first load.
      // path_provider is async, so we use a known Android path.
      if (_refDir == null) {
        // Trigger async init in background, but for now scan if dir exists.
        return result;
      }
      if (!_refDir!.existsSync()) return result;

      for (final file in _refDir!.listSync()) {
        if (file is File && file.path.endsWith('.json')) {
          final key = file.uri.pathSegments.last;
          result[key] = file.readAsStringSync();
        }
      }
    } catch (_) {
      // Storage may be corrupted or inaccessible.
    }
    return result;
  }

  @override
  void delete(String key) {
    if (_refDir == null) return;
    final file = File('${_refDir!.path}/$key');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// Must be called once at startup to initialize the directory path.
  Future<void> initialize() async {
    await _getDir();
  }
}
