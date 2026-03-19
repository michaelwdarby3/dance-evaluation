/// Platform-agnostic storage for user-created references.
abstract class ReferenceStorage {
  /// Saves a reference JSON string under the given key.
  void save(String key, String json);

  /// Loads all saved references as key → JSON string pairs.
  Map<String, String> loadAll();

  /// Deletes a reference by key.
  void delete(String key);
}
