import 'dart:convert';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/result_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

EvaluationResult _makeResult({
  String id = 'test-1',
  double score = 85.0,
  String? referenceName = 'Basic Groove',
  String? coaching = 'Keep practicing!',
}) {
  return EvaluationResult(
    id: id,
    overallScore: score,
    dimensions: [
      DimensionScore(
        dimension: EvalDimension.timing,
        score: 82,
        summary: 'Good rhythm',
      ),
      DimensionScore(
        dimension: EvalDimension.technique,
        score: 88,
        summary: 'Clean execution',
      ),
    ],
    jointFeedback: [],
    drills: [],
    createdAt: DateTime(2026, 3, 25, 14, 30),
    style: DanceStyle.hipHop,
    referenceName: referenceName,
    coachingSummary: coaching,
  );
}

void main() {
  group('ResultFormatter', () {
    group('formatResultAsText', () {
      test('produces human-readable summary', () {
        final result = _makeResult();
        final text = ResultFormatter.formatResultAsText(result);

        expect(text, contains('Dance Evaluation Results'));
        expect(text, contains('Score: 85/100'));
        expect(text, contains('Style: hipHop'));
        expect(text, contains('Reference: Basic Groove'));
        expect(text, contains('3/25/2026 14:30'));
        expect(text, contains('timing: 82'));
        expect(text, contains('technique: 88'));
        expect(text, contains('Coaching: Keep practicing!'));
      });

      test('uses style name when referenceName is null', () {
        final result = _makeResult(referenceName: null);
        final text = ResultFormatter.formatResultAsText(result);

        expect(text, contains('Reference: hipHop'));
      });

      test('omits coaching when null', () {
        final result = _makeResult(coaching: null);
        final text = ResultFormatter.formatResultAsText(result);

        expect(text, isNot(contains('Coaching:')));
      });
    });

    group('exportAllAsJson / parseImportJson round-trip', () {
      test('round-trips a list of results', () {
        final results = [
          _makeResult(id: 'a', score: 70),
          _makeResult(id: 'b', score: 90),
        ];

        final json = ResultFormatter.exportAllAsJson(results);
        final parsed = ResultFormatter.parseImportJson(json);

        expect(parsed.length, 2);
        expect(parsed[0].id, 'a');
        expect(parsed[0].overallScore, 70);
        expect(parsed[1].id, 'b');
        expect(parsed[1].overallScore, 90);
      });

      test('exported JSON has version and exportedAt', () {
        final json = ResultFormatter.exportAllAsJson([_makeResult()]);
        final map = jsonDecode(json) as Map<String, dynamic>;

        expect(map['version'], 1);
        expect(map['exportedAt'], isA<String>());
        expect(map['results'], isA<List>());
      });
    });

    group('parseImportJson', () {
      test('parses single result object', () {
        final result = _makeResult();
        final json = jsonEncode(result.toJson());
        final parsed = ResultFormatter.parseImportJson(json);

        expect(parsed.length, 1);
        expect(parsed[0].id, 'test-1');
      });

      test('parses bulk export with results array', () {
        final json = jsonEncode({
          'version': 1,
          'results': [_makeResult(id: 'x').toJson()],
        });
        final parsed = ResultFormatter.parseImportJson(json);

        expect(parsed.length, 1);
        expect(parsed[0].id, 'x');
      });

      test('throws FormatException on invalid JSON', () {
        expect(
          () => ResultFormatter.parseImportJson('not json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException when results is not an array', () {
        final json = jsonEncode({'results': 'not an array'});
        expect(
          () => ResultFormatter.parseImportJson(json),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles empty results array', () {
        final json = jsonEncode({'version': 1, 'results': []});
        final parsed = ResultFormatter.parseImportJson(json);

        expect(parsed, isEmpty);
      });
    });
  });
}
