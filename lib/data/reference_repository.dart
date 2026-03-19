import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/models/reference_choreography.dart';
import '../core/storage/reference_storage.dart';

/// Loads [ReferenceChoreography] definitions from JSON asset files and
/// user-created references persisted via [ReferenceStorage].
class ReferenceRepository {
  ReferenceRepository({AssetBundle? bundle, ReferenceStorage? storage})
      : _bundle = bundle ?? rootBundle,
        _storage = storage;

  final AssetBundle _bundle;
  final ReferenceStorage? _storage;

  /// Bundled asset references (loaded on demand).
  final Map<String, ReferenceChoreography> _assetCache = {};

  /// User-created references (in-memory + persisted to storage).
  final Map<String, ReferenceChoreography> _userRefs = {};

  /// Whether persisted references have been loaded from storage.
  bool _storageLoaded = false;

  /// Loads persisted references from storage into memory.
  /// Called automatically on first access, but can be called eagerly.
  void loadFromStorage() {
    if (_storageLoaded || _storage == null) return;
    _storageLoaded = true;

    try {
      final saved = _storage!.loadAll();
      for (final entry in saved.entries) {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        _userRefs[entry.key] = ReferenceChoreography.fromJson(json);
      }
    } catch (_) {
      // Storage may be corrupted — proceed with empty user refs.
    }
  }

  /// Loads a reference by its key.
  ///
  /// Checks user-created references first, then bundled assets.
  Future<ReferenceChoreography> load(String key) async {
    loadFromStorage();

    // Normalize key to always include .json extension.
    final normalizedKey = key.endsWith('.json') ? key : '$key.json';

    if (_userRefs.containsKey(normalizedKey)) return _userRefs[normalizedKey]!;
    if (_assetCache.containsKey(normalizedKey)) {
      return _assetCache[normalizedKey]!;
    }

    final raw = await _bundle.loadString('assets/references/$normalizedKey');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final ref = ReferenceChoreography.fromJson(json);
    _assetCache[normalizedKey] = ref;
    return ref;
  }

  /// Saves a user-created reference. Returns the key used to retrieve it.
  String save(ReferenceChoreography ref) {
    final key = '${ref.id}.json';
    _userRefs[key] = ref;

    // Persist to storage.
    _storage?.save(key, jsonEncode(ref.toJson()));

    return key;
  }

  /// Deletes a user-created reference by key.
  void delete(String key) {
    final normalizedKey = key.endsWith('.json') ? key : '$key.json';
    _userRefs.remove(normalizedKey);
    _storage?.delete(normalizedKey);
  }

  /// Lists all available reference keys (user-created + bundled assets).
  Future<List<String>> listAvailable() async {
    loadFromStorage();

    const prefix = 'assets/references/';
    final assetKeys = <String>[];

    try {
      // Modern Flutter uses AssetManifest.bin via loadStructuredData.
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final allAssets = manifest.listAssets();
      for (final path in allAssets) {
        if (path.startsWith(prefix) && path.endsWith('.json')) {
          assetKeys.add(path.substring(prefix.length));
        }
      }
    } catch (_) {
      // Fallback: try legacy AssetManifest.json.
      try {
        final manifestJson =
            await _bundle.loadString('AssetManifest.json');
        final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
        for (final k in manifest.keys) {
          if (k.startsWith(prefix) && k.endsWith('.json')) {
            assetKeys.add(k.substring(prefix.length));
          }
        }
      } catch (_) {
        // No manifest available — return only user refs.
      }
    }

    // User refs first, then bundled.
    return [..._userRefs.keys, ...assetKeys];
  }

  /// Lists all loaded/saved references with their metadata (no I/O for
  /// user refs, loads from assets for bundled ones).
  Future<List<ReferenceChoreography>> listAll() async {
    final keys = await listAvailable();
    final results = <ReferenceChoreography>[];
    for (final key in keys) {
      results.add(await load(key));
    }
    return results;
  }
}
