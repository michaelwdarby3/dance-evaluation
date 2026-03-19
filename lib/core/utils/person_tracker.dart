import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Tracks persons across frames using hip-midpoint centroid matching.
class PersonTracker {
  /// Centroids from the previous frame, keyed by person ID.
  final Map<int, _Centroid> _previousCentroids = {};

  /// Next available person ID.
  int _nextId = 0;

  /// Maximum distance (in normalized coords) to match a person across frames.
  static const double _maxMatchDistance = 0.3;

  /// Assigns stable person IDs to a list of detected [PoseFrame]s in a single
  /// frame. Returns a map of personId → PoseFrame.
  Map<int, PoseFrame> track(List<PoseFrame> detections) {
    if (detections.isEmpty) return {};

    final currentCentroids =
        detections.map((d) => _computeCentroid(d)).toList();

    final Map<int, PoseFrame> result = {};

    if (_previousCentroids.isEmpty) {
      // First frame: assign new IDs to all detections.
      for (var i = 0; i < detections.length; i++) {
        final id = _nextId++;
        result[id] = detections[i];
        _previousCentroids[id] = currentCentroids[i];
      }
      return result;
    }

    // Match current detections to previous centroids by nearest distance.
    final prevEntries = _previousCentroids.entries.toList();
    final matched = <int>{};
    final usedDetections = <int>{};

    // Build distance matrix and greedily match closest pairs.
    final distances = <(double dist, int prevIdx, int detIdx)>[];
    for (var pi = 0; pi < prevEntries.length; pi++) {
      for (var di = 0; di < currentCentroids.length; di++) {
        final d = _distance(prevEntries[pi].value, currentCentroids[di]);
        distances.add((d, pi, di));
      }
    }
    distances.sort((a, b) => a.$1.compareTo(b.$1));

    for (final (dist, prevIdx, detIdx) in distances) {
      if (matched.contains(prevIdx) || usedDetections.contains(detIdx)) {
        continue;
      }
      if (dist > _maxMatchDistance) break;

      final personId = prevEntries[prevIdx].key;
      result[personId] = detections[detIdx];
      matched.add(prevIdx);
      usedDetections.add(detIdx);
    }

    // Assign new IDs to unmatched detections.
    for (var di = 0; di < detections.length; di++) {
      if (!usedDetections.contains(di)) {
        final id = _nextId++;
        result[id] = detections[di];
      }
    }

    // Update previous centroids.
    _previousCentroids.clear();
    for (final entry in result.entries) {
      final di = detections.indexOf(entry.value);
      if (di >= 0) {
        _previousCentroids[entry.key] = currentCentroids[di];
      }
    }

    return result;
  }

  /// Resets all tracking state.
  void reset() {
    _previousCentroids.clear();
    _nextId = 0;
  }

  static _Centroid _computeCentroid(PoseFrame frame) {
    final lh = frame.landmarks[PoseConstants.leftHip];
    final rh = frame.landmarks[PoseConstants.rightHip];
    return _Centroid(
      x: (lh.x + rh.x) / 2,
      y: (lh.y + rh.y) / 2,
    );
  }

  static double _distance(_Centroid a, _Centroid b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _Centroid {
  const _Centroid({required this.x, required this.y});
  final double x;
  final double y;
}
