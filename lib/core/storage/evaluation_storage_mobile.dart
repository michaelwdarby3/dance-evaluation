import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'evaluation_storage.dart';

EvaluationStorage createEvaluationStorage() => MobileEvaluationStorage();

/// Persists evaluation results as JSON files in the app's documents directory.
class MobileEvaluationStorage extends EvaluationStorage {
  static const _dirName = 'evaluation_history';

  Directory? _dir;

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final appDir = await getApplicationDocumentsDirectory();
    _dir = Directory('${appDir.path}/$_dirName');
    if (!_dir!.existsSync()) {
      _dir!.createSync(recursive: true);
    }
    return _dir!;
  }

  @override
  void save(String key, String json) {
    if (_dir == null) {
      final home = Directory.systemTemp;
      _dir = Directory('${home.path}/$_dirName');
      if (!_dir!.existsSync()) {
        _dir!.createSync(recursive: true);
      }
    }
    File('${_dir!.path}/$key.json').writeAsStringSync(json);
  }

  @override
  Map<String, String> loadAll() {
    final result = <String, String>{};
    try {
      if (_dir == null || !_dir!.existsSync()) return result;

      for (final file in _dir!.listSync()) {
        if (file is File && file.path.endsWith('.json')) {
          final key = file.uri.pathSegments.last.replaceAll('.json', '');
          result[key] = file.readAsStringSync();
        }
      }
    } catch (_) {}
    return result;
  }

  @override
  void delete(String key) {
    if (_dir == null) return;
    final file = File('${_dir!.path}/$key.json');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  @override
  Future<void> initialize() async {
    await _getDir();
  }
}
