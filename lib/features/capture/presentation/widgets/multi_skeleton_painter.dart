import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';

/// Paints skeleton overlays for multiple tracked persons, each in a
/// distinct color.
class MultiSkeletonPainter extends CustomPainter {
  MultiSkeletonPainter({
    required this.trackedPersons,
    required this.imageSize,
    this.rotationDegrees = 0,
    this.isFrontCamera = true,
  });

  final Map<int, PoseFrame> trackedPersons;
  final Size imageSize;
  final int rotationDegrees;
  final bool isFrontCamera;

  static const List<Color> _personColors = [
    Color(0xFF00E5FF), // cyan
    Color(0xFFFF4081), // pink
    Color(0xFF69F0AE), // green
    Color(0xFFFFAB40), // amber
    Color(0xFFB388FF), // purple
  ];

  @override
  void paint(Canvas canvas, Size size) {
    var colorIndex = 0;

    for (final entry in trackedPersons.entries) {
      final frame = entry.value;
      final color = _personColors[colorIndex % _personColors.length];
      colorIndex++;

      final landmarkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final bonePaint = Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      for (final (start, end) in PoseConstants.boneConnections) {
        final startLm = frame.landmarks[start];
        final endLm = frame.landmarks[end];
        if (startLm.visibility <= 0.5 || endLm.visibility <= 0.5) continue;

        final startOffset = _transformPoint(startLm, size);
        final endOffset = _transformPoint(endLm, size);
        canvas.drawLine(startOffset, endOffset, bonePaint);
      }

      for (final lm in frame.landmarks) {
        if (lm.visibility <= 0.5) continue;
        final offset = _transformPoint(lm, size);
        canvas.drawCircle(offset, 6.0, landmarkPaint);
      }
    }
  }

  Offset _transformPoint(Landmark lm, Size canvasSize) {
    double x = lm.x * imageSize.width;
    double y = lm.y * imageSize.height;

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

    final bool isRotated = rotationDegrees == 90 || rotationDegrees == 270;
    final double effectiveWidth =
        isRotated ? imageSize.height : imageSize.width;
    final double effectiveHeight =
        isRotated ? imageSize.width : imageSize.height;

    final scaleX = canvasSize.width / effectiveWidth;
    final scaleY = canvasSize.height / effectiveHeight;
    x *= scaleX;
    y *= scaleY;

    if (isFrontCamera) {
      x = canvasSize.width - x;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant MultiSkeletonPainter oldDelegate) => true;
}
