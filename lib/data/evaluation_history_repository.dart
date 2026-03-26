import 'dart:convert';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage.dart';

/// Repository for persisting and querying evaluation history.
class EvaluationHistoryRepository {
  EvaluationHistoryRepository({required EvaluationStorage storage})
      : _storage = storage;

  final EvaluationStorage _storage;
  List<EvaluationResult>? _cache;

  /// Saves an evaluation result to persistent storage.
  void save(EvaluationResult result) {
    _storage.save(result.id, jsonEncode(result.toJson()));
    _cache = null; // Invalidate cache.
  }

  /// Loads all evaluation results, sorted by date (newest first).
  List<EvaluationResult> listAll() {
    if (_cache != null) return _cache!;

    final entries = _storage.loadAll();
    final results = <EvaluationResult>[];

    for (final json in entries.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        results.add(EvaluationResult.fromJson(map));
      } catch (_) {
        // Skip corrupted entries.
      }
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = results;
    return results;
  }

  /// Loads a single result by ID, or null if not found.
  EvaluationResult? load(String id) {
    return listAll().where((r) => r.id == id).firstOrNull;
  }

  /// Deletes a result by ID.
  void delete(String id) {
    _storage.delete(id);
    _cache = null;
  }

  /// Returns results filtered by dance style.
  List<EvaluationResult> listByStyle(String styleName) {
    return listAll().where((r) => r.style.name == styleName).toList();
  }

  /// Imports results, skipping any whose ID already exists.
  /// Returns the number of newly imported results.
  int importAll(List<EvaluationResult> results) {
    final existing = listAll().map((r) => r.id).toSet();
    var imported = 0;
    for (final result in results) {
      if (!existing.contains(result.id)) {
        _storage.save(result.id, jsonEncode(result.toJson()));
        imported++;
      }
    }
    if (imported > 0) _cache = null;
    return imported;
  }

  /// Deletes all evaluation history.
  void clearAll() {
    for (final result in listAll()) {
      _storage.delete(result.id);
    }
    _cache = null;
  }
}
