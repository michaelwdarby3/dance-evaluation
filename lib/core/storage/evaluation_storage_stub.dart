import 'evaluation_storage.dart';

EvaluationStorage createEvaluationStorage() => _NoOpEvaluationStorage();

/// No-op storage for platforms without localStorage.
class _NoOpEvaluationStorage extends EvaluationStorage {
  @override
  void save(String key, String json) {}

  @override
  Map<String, String> loadAll() => {};

  @override
  void delete(String key) {}
}
