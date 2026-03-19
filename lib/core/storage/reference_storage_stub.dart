import 'reference_storage.dart';

ReferenceStorage createReferenceStorage() => _NoOpReferenceStorage();

/// No-op storage for platforms without localStorage.
class _NoOpReferenceStorage extends ReferenceStorage {
  @override
  void save(String key, String json) {}

  @override
  Map<String, String> loadAll() => {};

  @override
  void delete(String key) {}
}
