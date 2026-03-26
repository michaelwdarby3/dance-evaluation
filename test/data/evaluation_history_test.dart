import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';

class _InMemoryStorage extends EvaluationStorage {
  final _store = <String, String>{};

  @override
  void save(String key, String json) => _store[key] = json;

  @override
  Map<String, String> loadAll() => Map.of(_store);

  @override
  void delete(String key) => _store.remove(key);
}

EvaluationResult _makeResult({
  String id = 'test_1',
  double score = 75.0,
  DateTime? createdAt,
  DanceStyle style = DanceStyle.hipHop,
  String? referenceName,
}) {
  return EvaluationResult(
    id: id,
    overallScore: score,
    dimensions: [
      const DimensionScore(
        dimension: EvalDimension.timing,
        score: 80,
        summary: 'Good timing',
      ),
      const DimensionScore(
        dimension: EvalDimension.technique,
        score: 70,
        summary: 'Decent technique',
      ),
    ],
    jointFeedback: [
      const JointFeedback(
        jointName: 'leftElbow',
        landmarkIndices: [11, 13, 15],
        score: 55,
        issue: 'Arm too low',
        correction: 'Raise your left arm higher',
      ),
    ],
    drills: const [],
    createdAt: createdAt ?? DateTime(2026, 3, 21, 10, 0),
    style: style,
    referenceName: referenceName,
  );
}

void main() {
  group('EvaluationResult JSON', () {
    test('roundtrips through toJson/fromJson', () {
      final original = _makeResult(referenceName: 'Hip Hop Basic');
      final json = original.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.overallScore, original.overallScore);
      expect(restored.style, original.style);
      expect(restored.referenceName, 'Hip Hop Basic');
      expect(restored.dimensions.length, 2);
      expect(restored.dimensions[0].dimension, EvalDimension.timing);
      expect(restored.dimensions[0].score, 80);
      expect(restored.jointFeedback.length, 1);
      expect(restored.jointFeedback[0].jointName, 'leftElbow');
      expect(restored.jointFeedback[0].landmarkIndices, [11, 13, 15]);
      expect(restored.createdAt, original.createdAt);
    });

    test('roundtrips through JSON string encoding', () {
      final original = _makeResult();
      final jsonStr = jsonEncode(original.toJson());
      final restored =
          EvaluationResult.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.id, original.id);
      expect(restored.overallScore, original.overallScore);
    });

    test('handles null referenceName', () {
      final result = _makeResult(referenceName: null);
      final json = result.toJson();
      final restored = EvaluationResult.fromJson(json);

      expect(restored.referenceName, isNull);
    });
  });

  group('EvaluationHistoryRepository', () {
    late _InMemoryStorage storage;
    late EvaluationHistoryRepository repo;

    setUp(() {
      storage = _InMemoryStorage();
      repo = EvaluationHistoryRepository(storage: storage);
    });

    test('starts empty', () {
      expect(repo.listAll(), isEmpty);
    });

    test('save and load a result', () {
      final result = _makeResult();
      repo.save(result);

      final loaded = repo.listAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'test_1');
      expect(loaded.first.overallScore, 75.0);
    });

    test('load by ID', () {
      repo.save(_makeResult(id: 'a'));
      repo.save(_makeResult(id: 'b', score: 90));

      final found = repo.load('b');
      expect(found, isNotNull);
      expect(found!.overallScore, 90);
    });

    test('load by ID returns null for missing', () {
      expect(repo.load('nonexistent'), isNull);
    });

    test('delete removes result', () {
      repo.save(_makeResult(id: 'del_me'));
      expect(repo.listAll(), hasLength(1));

      repo.delete('del_me');
      expect(repo.listAll(), isEmpty);
    });

    test('results sorted newest first', () {
      repo.save(_makeResult(
        id: 'old',
        createdAt: DateTime(2026, 1, 1),
      ));
      repo.save(_makeResult(
        id: 'new',
        createdAt: DateTime(2026, 3, 21),
      ));

      final results = repo.listAll();
      expect(results.first.id, 'new');
      expect(results.last.id, 'old');
    });

    test('listByStyle filters correctly', () {
      repo.save(_makeResult(id: 'hh', style: DanceStyle.hipHop));
      repo.save(_makeResult(id: 'kp', style: DanceStyle.kPop));

      final hipHop = repo.listByStyle('hipHop');
      expect(hipHop, hasLength(1));
      expect(hipHop.first.id, 'hh');
    });

    test('listByReference filters correctly', () {
      repo.save(_makeResult(id: 'a', referenceName: 'Hip Hop Basic'));
      repo.save(_makeResult(id: 'b', referenceName: 'K-Pop Intro'));
      repo.save(_makeResult(id: 'c', referenceName: 'Hip Hop Basic'));

      final filtered = repo.listByReference('Hip Hop Basic');
      expect(filtered, hasLength(2));
      expect(filtered.every((r) => r.referenceName == 'Hip Hop Basic'), isTrue);
    });

    test('listByReference returns empty for no matches', () {
      repo.save(_makeResult(id: 'a', referenceName: 'Hip Hop Basic'));
      expect(repo.listByReference('Nonexistent'), isEmpty);
    });

    test('clearAll removes everything', () {
      repo.save(_makeResult(id: 'a'));
      repo.save(_makeResult(id: 'b'));
      expect(repo.listAll(), hasLength(2));

      repo.clearAll();
      expect(repo.listAll(), isEmpty);
    });

    test('importAll adds new results and skips duplicates', () {
      repo.save(_makeResult(id: 'existing', score: 60));

      final imported = repo.importAll([
        _makeResult(id: 'existing', score: 99), // duplicate — skip
        _makeResult(id: 'new_one', score: 80),
      ]);

      expect(imported, 1);
      final all = repo.listAll();
      expect(all, hasLength(2));
      // Original should be unchanged.
      expect(all.firstWhere((r) => r.id == 'existing').overallScore, 60);
      expect(all.firstWhere((r) => r.id == 'new_one').overallScore, 80);
    });

    test('importAll with empty list returns 0', () {
      expect(repo.importAll([]), 0);
    });

    test('skips corrupted entries', () {
      storage.save('good', jsonEncode(_makeResult().toJson()));
      storage.save('bad', '{invalid json!!!');

      final results = repo.listAll();
      expect(results, hasLength(1));
    });
  });
}
