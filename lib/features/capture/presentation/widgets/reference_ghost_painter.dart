import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

/// Paints a semi-transparent "ghost" skeleton from a reference sequence,
/// mirrored so the user can follow along as if looking in a mirror.
class ReferenceGhostPainter extends CustomPainter {
  ReferenceGhostPainter({
    required this.referenceSequence,
    required this.elapsed,
    required this.canvasSize,
    this.color = const Color(0xFFBB86FC),
    this.opacity = 0.5,
    this.mirror = false,
  });

  final PoseSequence referenceSequence;
  final Duration elapsed;
  final Size canvasSize;
  final Color color;
  final double opacity;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _frameAtTime(elapsed);
    if (frame == null) return;

    final bonePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.15)
      ..style = PaintingStyle.fill;

    // Draw bone connections.
    for (final (start, end) in PoseConstants.boneConnections) {
      final startLm = frame.landmarks[start];
      final endLm = frame.landmarks[end];
      if (startLm.visibility <= 0.3 || endLm.visibility <= 0.3) continue;

      final startOffset = _toCanvas(startLm, size);
      final endOffset = _toCanvas(endLm, size);
      canvas.drawLine(startOffset, endOffset, bonePaint);
    }

    // Draw joints with glow.
    for (final lm in frame.landmarks) {
      if (lm.visibility <= 0.3) continue;
      final offset = _toCanvas(lm, size);
      canvas.drawCircle(offset, 10.0, glowPaint);
      canvas.drawCircle(offset, 5.0, jointPaint);
    }
  }

  /// Maps a normalized landmark to canvas coordinates, optionally mirrored.
  Offset _toCanvas(Landmark lm, Size size) {
    final x = mirror ? (1.0 - lm.x) * size.width : lm.x * size.width;
    final y = lm.y * size.height;
    return Offset(x, y);
  }

  /// Finds the reference frame closest to the given elapsed time.
  PoseFrame? _frameAtTime(Duration time) {
    final frames = referenceSequence.frames;
    if (frames.isEmpty) return null;

    final targetMs = time.inMilliseconds;
    final durationMs = referenceSequence.duration.inMilliseconds;

    // If elapsed exceeds reference duration, hold the last frame.
    if (durationMs > 0 && targetMs >= durationMs) return frames.last;

    // Binary search for nearest frame.
    int lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timestamp.inMilliseconds < targetMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // Check if previous frame is closer.
    if (lo > 0) {
      final prevDiff =
          (frames[lo - 1].timestamp.inMilliseconds - targetMs).abs();
      final currDiff =
          (frames[lo].timestamp.inMilliseconds - targetMs).abs();
      if (prevDiff < currDiff) return frames[lo - 1];
    }

    return frames[lo];
  }

  @override
  bool shouldRepaint(covariant ReferenceGhostPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed || oldDelegate.mirror != mirror;
}
