import 'dart:convert';

import 'package:dance_evaluation/core/models/evaluation_result.dart';

/// Pure-Dart formatting and serialization for evaluation results.
class ResultFormatter {
  ResultFormatter._();

  /// Formats a single evaluation result as a human-readable text summary.
  static String formatResultAsText(EvaluationResult result) {
    final buf = StringBuffer();
    buf.writeln('Dance Evaluation Results');
    buf.writeln('========================');

    final refLabel = result.referenceName ?? result.style.name;
    buf.writeln(
      'Score: ${result.overallScore.round()}/100 | '
      'Style: ${result.style.name} | '
      'Reference: $refLabel',
    );

    final d = result.createdAt;
    buf.writeln(
      'Date: ${d.month}/${d.day}/${d.year} '
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}',
    );

    buf.writeln();
    buf.writeln('Dimensions:');
    for (final dim in result.dimensions) {
      buf.writeln(
        '  ${dim.dimension.name}: ${dim.score.round()} — ${dim.summary}',
      );
    }

    if (result.coachingSummary != null &&
        result.coachingSummary!.isNotEmpty) {
      buf.writeln();
      buf.writeln('Coaching: ${result.coachingSummary}');
    }

    return buf.toString().trimRight();
  }

  /// Serializes a list of evaluation results to a versioned JSON string.
  static String exportAllAsJson(List<EvaluationResult> results) {
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'results': results.map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parses imported JSON, accepting either a single result object or a
  /// bulk export with `{"results": [...]}`.
  ///
  /// Throws [FormatException] on invalid input.
  static List<EvaluationResult> parseImportJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('Invalid JSON');
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('results')) {
        final list = decoded['results'];
        if (list is! List) {
          throw const FormatException('"results" must be an array');
        }
        return list
            .map((e) => EvaluationResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // Single result object.
      return [EvaluationResult.fromJson(decoded)];
    }

    throw const FormatException('Expected a JSON object');
  }
}
