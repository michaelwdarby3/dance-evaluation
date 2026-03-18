import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Paints a skeleton overlay on top of the camera preview.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.currentFrame,
    required this.imageSize,
    this.rotationDegrees = 0,
    this.isFrontCamera = true,
  });

  final PoseFrame? currentFrame;
  final Size imageSize;
  final int rotationDegrees;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = currentFrame;
    if (frame == null) return;

    final landmarkPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw bone connections.
    for (final (start, end) in PoseConstants.boneConnections) {
      final startLm = frame.landmarks[start];
      final endLm = frame.landmarks[end];
      if (startLm.visibility <= 0.5 || endLm.visibility <= 0.5) continue;

      final startOffset = _transformPoint(startLm, size);
      final endOffset = _transformPoint(endLm, size);
      canvas.drawLine(startOffset, endOffset, bonePaint);
    }

    // Draw landmark dots.
    for (final lm in frame.landmarks) {
      if (lm.visibility <= 0.5) continue;
      final offset = _transformPoint(lm, size);
      canvas.drawCircle(offset, 6.0, landmarkPaint);
    }
  }

  /// Converts a normalized landmark position to canvas coordinates,
  /// accounting for camera rotation and mirroring for front camera.
  Offset _transformPoint(Landmark lm, Size canvasSize) {
    double x = lm.x * imageSize.width;
    double y = lm.y * imageSize.height;

    // Apply rotation.
    switch (rotationDegrees) {
      case 90:
        final temp = x;
        x = y;
        y = imageSize.width - temp;
      case 180:
        x = imageSize.width - x;
        y = imageSize.height - y;
      case 270:
        final temp = x;
        x = imageSize.height - y;
        y = temp;
      default:
        break;
    }

    // Determine the effective image dimensions after rotation.
    final bool isRotated = rotationDegrees == 90 || rotationDegrees == 270;
    final double effectiveWidth =
        isRotated ? imageSize.height : imageSize.width;
    final double effectiveHeight =
        isRotated ? imageSize.width : imageSize.height;

    // Scale to canvas size.
    final scaleX = canvasSize.width / effectiveWidth;
    final scaleY = canvasSize.height / effectiveHeight;
    x *= scaleX;
    y *= scaleY;

    // Mirror for front camera.
    if (isFrontCamera) {
      x = canvasSize.width - x;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) => true;
}
