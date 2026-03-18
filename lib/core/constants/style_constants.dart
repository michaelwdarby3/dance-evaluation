/// Dance styles supported by the evaluation system.
enum DanceStyle { hipHop, kPop, contemporary, freestyle }

/// Evaluation dimensions scored independently then combined.
enum EvalDimension { timing, technique, expression, spatialAwareness }

/// Per-dimension weights for a given dance style.
class StyleWeights {
  const StyleWeights(this.weights);

  /// Weight per dimension. Values should sum to 1.0.
  final Map<EvalDimension, double> weights;

  /// Convenience accessor that returns 0.0 for missing dimensions.
  double operator [](EvalDimension d) => weights[d] ?? 0.0;

  /// Returns the weighted overall score given per-dimension raw scores.
  double weightedScore(Map<EvalDimension, double> scores) {
    var total = 0.0;
    for (final entry in weights.entries) {
      total += entry.value * (scores[entry.key] ?? 0.0);
    }
    return total;
  }
}

/// Default weight profiles per dance style.
class StyleProfiles {
  StyleProfiles._();

  static const Map<DanceStyle, StyleWeights> styleProfiles = {
    DanceStyle.hipHop: StyleWeights({
      EvalDimension.timing: 0.30,
      EvalDimension.technique: 0.30,
      EvalDimension.expression: 0.20,
      EvalDimension.spatialAwareness: 0.20,
    }),
    DanceStyle.kPop: StyleWeights({
      EvalDimension.timing: 0.25,
      EvalDimension.technique: 0.35,
      EvalDimension.expression: 0.15,
      EvalDimension.spatialAwareness: 0.25,
    }),
    DanceStyle.contemporary: StyleWeights({
      EvalDimension.timing: 0.20,
      EvalDimension.technique: 0.25,
      EvalDimension.expression: 0.35,
      EvalDimension.spatialAwareness: 0.20,
    }),
    DanceStyle.freestyle: StyleWeights({
      EvalDimension.timing: 0.25,
      EvalDimension.technique: 0.25,
      EvalDimension.expression: 0.25,
      EvalDimension.spatialAwareness: 0.25,
    }),
  };
}
