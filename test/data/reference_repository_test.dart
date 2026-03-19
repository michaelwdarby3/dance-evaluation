import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/storage/reference_storage.dart';
import 'package:dance_evaluation/data/reference_repository.dart';

/// In-memory fake storage for testing persistence.
class FakeReferenceStorage extends ReferenceStorage {
  final Map<String, String> _store = {};

  @override
  void save(String key, String json) => _store[key] = json;

  @override
  Map<String, String> loadAll() => Map.of(_store);

  @override
  void delete(String key) => _store.remove(key);
}

ReferenceChoreography _makeRef({String id = 'test_ref'}) {
  final frames = List.generate(5, (i) {
    return PoseFrame(
      timestamp: Duration(milliseconds: i * 100),
      landmarks: List.generate(
        33,
        (_) => const Landmark(x: 0.5, y: 0.5, z: 0, visibility: 0.9),
      ),
    );
  });

  return ReferenceChoreography(
    id: id,
    name: 'Test Reference',
    style: DanceStyle.hipHop,
    poses: PoseSequence(
      frames: frames,
      fps: 10.0,
      duration: const Duration(milliseconds: 400),
    ),
    bpm: 120.0,
    description: 'A test reference',
    difficulty: 'beginner',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReferenceRepository repo;

  setUp(() {
    repo = ReferenceRepository();
  });

  group('ReferenceRepository', () {
    group('save and load user references', () {
      test('save returns a key ending in .json', () {
        final ref = _makeRef(id: 'my_dance');
        final key = repo.save(ref);

        expect(key, 'my_dance.json');
      });

      test('load returns a saved user reference by key', () async {
        final ref = _makeRef(id: 'my_dance');
        final key = repo.save(ref);

        final loaded = await repo.load(key);

        expect(loaded.id, 'my_dance');
        expect(loaded.name, 'Test Reference');
        expect(loaded.poses.frames.length, 5);
      });

      test('user references take priority over asset cache', () async {
        // Save two references with different IDs to the same key slot.
        final ref1 = _makeRef(id: 'dance_v1');
        final key = repo.save(ref1);

        // Overwrite with a new reference at the same id.
        final ref2 = ReferenceChoreography(
          id: 'dance_v1',
          name: 'Updated Reference',
          style: DanceStyle.kPop,
          poses: ref1.poses,
          bpm: 140.0,
          description: 'Updated',
          difficulty: 'intermediate',
        );
        repo.save(ref2);

        final loaded = await repo.load(key);

        expect(loaded.name, 'Updated Reference');
        expect(loaded.style, DanceStyle.kPop);
      });

      test('multiple user references can coexist', () async {
        repo.save(_makeRef(id: 'ref_a'));
        repo.save(_makeRef(id: 'ref_b'));
        repo.save(_makeRef(id: 'ref_c'));

        final a = await repo.load('ref_a.json');
        final b = await repo.load('ref_b.json');
        final c = await repo.load('ref_c.json');

        expect(a.id, 'ref_a');
        expect(b.id, 'ref_b');
        expect(c.id, 'ref_c');
      });
    });

    group('listAvailable', () {
      test('includes user-created references', () async {
        repo.save(_makeRef(id: 'user_ref_1'));
        repo.save(_makeRef(id: 'user_ref_2'));

        final available = await repo.listAvailable();

        expect(available, contains('user_ref_1.json'));
        expect(available, contains('user_ref_2.json'));
      });

      test('user references appear before bundled assets', () async {
        repo.save(_makeRef(id: 'user_ref'));

        final available = await repo.listAvailable();

        // User ref should be first.
        expect(available.first, 'user_ref.json');
      });

      test('returns only user refs when no asset manifest is available', () async {
        // With TestWidgetsFlutterBinding and no assets registered,
        // the manifest lookup will fail — should gracefully return user refs.
        repo.save(_makeRef(id: 'only_user'));

        final available = await repo.listAvailable();

        expect(available, contains('only_user.json'));
      });
    });

    group('listAll', () {
      test('returns full ReferenceChoreography objects for user refs', () async {
        repo.save(_makeRef(id: 'full_ref'));

        final all = await repo.listAll();

        expect(all.length, greaterThanOrEqualTo(1));
        final found = all.firstWhere((r) => r.id == 'full_ref');
        expect(found.name, 'Test Reference');
        expect(found.poses.frames.length, 5);
      });
    });

    group('key normalization', () {
      test('load finds user ref by id without .json extension', () async {
        // This is the actual flow: ReferenceListScreen passes ref.id
        // (e.g. "my_dance") through a query param, and _EvaluationLoader
        // calls repo.load("my_dance"). The repo must find the user ref
        // saved under "my_dance.json".
        final ref = _makeRef(id: 'my_dance');
        repo.save(ref);

        final loaded = await repo.load('my_dance');

        expect(loaded.id, 'my_dance');
        expect(loaded.name, 'Test Reference');
      });

      test('load works with .json extension too', () async {
        final ref = _makeRef(id: 'my_dance');
        repo.save(ref);

        final loaded = await repo.load('my_dance.json');

        expect(loaded.id, 'my_dance');
      });

      test('load without .json uses cache on second call', () async {
        final ref = _makeRef(id: 'cached');
        repo.save(ref);

        // First load normalizes and caches.
        await repo.load('cached');
        // Second load should hit cache, not throw.
        final loaded = await repo.load('cached');

        expect(loaded.id, 'cached');
      });
    });

    group('load error handling', () {
      test('loading a non-existent key throws', () async {
        expect(
          () => repo.load('nonexistent_ref.json'),
          throwsA(anything),
        );
      });
    });

    group('caching', () {
      test('save then load does not hit asset bundle', () async {
        // If we save a user ref, loading it should return the in-memory
        // version without going through rootBundle.
        final ref = _makeRef(id: 'cached_ref');
        repo.save(ref);

        // This should not throw even though no asset file exists.
        final loaded = await repo.load('cached_ref.json');
        expect(loaded.id, 'cached_ref');
      });
    });

    group('persistence', () {
      late FakeReferenceStorage storage;

      setUp(() {
        storage = FakeReferenceStorage();
      });

      test('save persists to storage', () {
        final repo = ReferenceRepository(storage: storage);
        final ref = _makeRef(id: 'persisted_ref');
        repo.save(ref);

        // Storage should have the serialized reference.
        expect(storage.loadAll(), contains('persisted_ref.json'));
        final json = jsonDecode(storage.loadAll()['persisted_ref.json']!)
            as Map<String, dynamic>;
        expect(json['id'], 'persisted_ref');
        expect(json['name'], 'Test Reference');
      });

      test('new repo loads persisted references from storage', () async {
        // Save via first repo instance.
        final repo1 = ReferenceRepository(storage: storage);
        repo1.save(_makeRef(id: 'survive_refresh'));

        // Create a new repo (simulates page refresh).
        final repo2 = ReferenceRepository(storage: storage);
        final loaded = await repo2.load('survive_refresh');

        expect(loaded.id, 'survive_refresh');
        expect(loaded.name, 'Test Reference');
        expect(loaded.poses.frames.length, 5);
      });

      test('persisted refs appear in listAvailable', () async {
        final repo1 = ReferenceRepository(storage: storage);
        repo1.save(_makeRef(id: 'listed_ref'));

        final repo2 = ReferenceRepository(storage: storage);
        final available = await repo2.listAvailable();

        expect(available, contains('listed_ref.json'));
      });

      test('delete removes from storage and memory', () async {
        final repo = ReferenceRepository(storage: storage);
        repo.save(_makeRef(id: 'doomed_ref'));

        expect(storage.loadAll(), contains('doomed_ref.json'));

        repo.delete('doomed_ref');

        expect(storage.loadAll(), isNot(contains('doomed_ref.json')));
        expect(
          () => repo.load('doomed_ref'),
          throwsA(anything),
        );
      });

      test('persisted ref survives roundtrip with all fields', () async {
        final repo1 = ReferenceRepository(storage: storage);
        repo1.save(ReferenceChoreography(
          id: 'roundtrip',
          name: 'Roundtrip Test',
          style: DanceStyle.kPop,
          poses: PoseSequence(
            frames: [
              PoseFrame(
                timestamp: Duration.zero,
                landmarks: List.generate(
                  33,
                  (_) => const Landmark(x: 0.3, y: 0.7, z: 0.1, visibility: 0.95),
                ),
              ),
            ],
            fps: 30.0,
            duration: Duration.zero,
          ),
          bpm: 140.0,
          description: 'Testing persistence',
          difficulty: 'advanced',
        ));

        final repo2 = ReferenceRepository(storage: storage);
        final loaded = await repo2.load('roundtrip');

        expect(loaded.id, 'roundtrip');
        expect(loaded.name, 'Roundtrip Test');
        expect(loaded.style, DanceStyle.kPop);
        expect(loaded.bpm, 140.0);
        expect(loaded.difficulty, 'advanced');
        expect(loaded.poses.fps, 30.0);
        expect(loaded.poses.frames.first.landmarks[0].x, closeTo(0.3, 0.001));
      });

      test('corrupted storage does not crash', () async {
        // Write invalid JSON to storage.
        storage.save('bad_ref.json', 'not valid json {{{');

        final repo = ReferenceRepository(storage: storage);
        // Should not throw — corrupted storage is silently skipped.
        final available = await repo.listAvailable();

        // bad_ref may or may not appear, but no crash.
        expect(available, isA<List<String>>());
      });
    });
  });
}
