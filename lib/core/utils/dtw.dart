import 'dart:math' as math;

import '../models/pose_frame.dart';
import '../models/pose_sequence.dart';
import 'pose_math.dart';

/// Result of a Dynamic Time Warping computation.
class DtwResult {
  const DtwResult({
    required this.distance,
    required this.normalizedDistance,
    required this.warpingPath,
  });

  /// Total accumulated DTW cost.
  final double distance;

  /// Distance divided by the warping path length, giving a per-step average.
  final double normalizedDistance;

  /// Pairs of aligned frame indices: (referenceIndex, userIndex).
  final List<(int, int)> warpingPath;
}

/// Computes Dynamic Time Warping between two [PoseSequence]s.
///
/// The optional [distanceFunction] defines the cost between two frames.
/// Defaults to [PoseMath.poseDistance].
DtwResult computeDtw(
  PoseSequence reference,
  PoseSequence user, {
  double Function(PoseFrame, PoseFrame)? distanceFunction,
}) {
  final dist = distanceFunction ?? PoseMath.poseDistance;

  final n = reference.frames.length;
  final m = user.frames.length;

  if (n == 0 || m == 0) {
    return const DtwResult(
      distance: double.infinity,
      normalizedDistance: double.infinity,
      warpingPath: [],
    );
  }

  // Build the full cost matrix.
  // cost[i][j] = minimum accumulated cost to align reference[0..i] with user[0..j].
  final cost = List.generate(n, (_) => List.filled(m, 0.0));

  cost[0][0] = dist(reference.frames[0], user.frames[0]);

  // First column.
  for (var i = 1; i < n; i++) {
    cost[i][0] = cost[i - 1][0] + dist(reference.frames[i], user.frames[0]);
  }

  // First row.
  for (var j = 1; j < m; j++) {
    cost[0][j] = cost[0][j - 1] + dist(reference.frames[0], user.frames[j]);
  }

  // Fill the rest.
  for (var i = 1; i < n; i++) {
    for (var j = 1; j < m; j++) {
      final d = dist(reference.frames[i], user.frames[j]);
      cost[i][j] = d +
          math.min(
            cost[i - 1][j],
            math.min(cost[i][j - 1], cost[i - 1][j - 1]),
          );
    }
  }

  // Backtrack to find the optimal warping path.
  final path = <(int, int)>[];
  var i = n - 1;
  var j = m - 1;
  path.add((i, j));

  while (i > 0 || j > 0) {
    if (i == 0) {
      j--;
    } else if (j == 0) {
      i--;
    } else {
      final diag = cost[i - 1][j - 1];
      final left = cost[i][j - 1];
      final up = cost[i - 1][j];

      if (diag <= left && diag <= up) {
        i--;
        j--;
      } else if (up <= left) {
        i--;
      } else {
        j--;
      }
    }
    path.add((i, j));
  }

  // Path was built end-to-start; reverse it.
  final warpingPath = path.reversed.toList();
  final totalDistance = cost[n - 1][m - 1];

  return DtwResult(
    distance: totalDistance,
    normalizedDistance: totalDistance / warpingPath.length,
    warpingPath: warpingPath,
  );
}

/// Convenience function that returns just the warping path
/// (aligned frame index pairs) between two sequences.
List<(int, int)> alignSequences(PoseSequence reference, PoseSequence user) {
  return computeDtw(reference, user).warpingPath;
}
