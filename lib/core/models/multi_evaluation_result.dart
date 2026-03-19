import 'evaluation_result.dart';

/// Evaluation result for a multi-person performance.
class MultiPersonEvaluationResult {
  const MultiPersonEvaluationResult({
    required this.personResults,
    required this.overallScore,
  });

  /// Per-person evaluation results, indexed by person ID.
  final List<EvaluationResult> personResults;

  /// Aggregate score across all persons.
  final double overallScore;

  /// Number of evaluated persons.
  int get personCount => personResults.length;

  /// Whether this is effectively a single-person result.
  bool get isSinglePerson => personResults.length == 1;

  @override
  String toString() =>
      'MultiPersonEvaluationResult(persons: $personCount, overall: $overallScore)';
}
