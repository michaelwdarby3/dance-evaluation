/// Platform-agnostic storage for evaluation history.
abstract class EvaluationStorage {
  /// Optional async initialization (e.g. resolving file paths on mobile).
  Future<void> initialize() async {}

  /// Saves an evaluation result JSON string under the given key.
  void save(String key, String json);

  /// Loads all saved evaluations as key -> JSON string pairs.
  Map<String, String> loadAll();

  /// Deletes an evaluation by key.
  void delete(String key);
}
