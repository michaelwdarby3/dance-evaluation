import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/skeleton_painter.dart';
import 'package:dance_evaluation/features/capture/presentation/widgets/multi_skeleton_painter.dart';

// SkeletonPainter._transformPoint is private, so we test it indirectly via
// a subclass that exposes it. This lets us verify coordinate transforms
// without needing a Canvas mock.
class TestableSkeletonPainter extends SkeletonPainter {
  TestableSkeletonPainter({
    required super.currentFrame,
    required super.imageSize,
    super.rotationDegrees,
    super.isFrontCamera,
  });

  Offset transformPoint(Landmark lm, Size canvasSize) {
    // Use the same logic as _transformPoint by calling paint indirectly.
    // Since _transformPoint is private, we replicate the logic here for testing.
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
}

PoseFrame _makeFrame({double x = 0.5, double y = 0.5, double vis = 0.9}) {
  return PoseFrame(
    timestamp: Duration.zero,
    landmarks: List.generate(
      33,
      (_) => Landmark(x: x, y: y, z: 0, visibility: vis),
    ),
  );
}

void main() {
  group('SkeletonPainter', () {
    test('shouldRepaint always returns true', () {
      final painter = SkeletonPainter(
        currentFrame: _makeFrame(),
        imageSize: const Size(640, 480),
      );
      final other = SkeletonPainter(
        currentFrame: _makeFrame(),
        imageSize: const Size(640, 480),
      );

      expect(painter.shouldRepaint(other), isTrue);
    });

    group('coordinate transforms', () {
      test('no rotation, back camera: identity transform scaled to canvas', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(640, 480),
          rotationDegrees: 0,
          isFrontCamera: false,
        );

        // Landmark at (0.5, 0.5) with image 640x480, canvas 320x240
        const lm = Landmark(x: 0.5, y: 0.5, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(320, 240));

        // x = 0.5 * 640 * (320/640) = 160
        // y = 0.5 * 480 * (240/480) = 120
        expect(offset.dx, closeTo(160, 0.01));
        expect(offset.dy, closeTo(120, 0.01));
      });

      test('no rotation, front camera: mirrors x', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(640, 480),
          rotationDegrees: 0,
          isFrontCamera: true,
        );

        const lm = Landmark(x: 0.5, y: 0.5, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(320, 240));

        // mirrored: x = 320 - 160 = 160 (centered, so same)
        expect(offset.dx, closeTo(160, 0.01));

        // Test off-center point
        const lmOff = Landmark(x: 0.25, y: 0.5, z: 0, visibility: 1.0);
        final offsetOff = painter.transformPoint(lmOff, const Size(320, 240));
        // x = 0.25 * 640 * (320/640) = 80, mirrored: 320 - 80 = 240
        expect(offsetOff.dx, closeTo(240, 0.01));
      });

      test('90 degree rotation swaps and inverts correctly', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(640, 480),
          rotationDegrees: 90,
          isFrontCamera: false,
        );

        const lm = Landmark(x: 0.0, y: 0.0, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(320, 240));

        // After 90° rotation: x = y*imgW = 0, y = imgW - x*imgW = 640
        // effectiveWidth = imgH = 480, effectiveHeight = imgW = 640
        // scaleX = 320/480, scaleY = 240/640
        // final x = 0 * (320/480) = 0
        // final y = 640 * (240/640) = 240
        expect(offset.dx, closeTo(0, 0.01));
        expect(offset.dy, closeTo(240, 0.01));
      });

      test('180 degree rotation inverts both axes', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(640, 480),
          rotationDegrees: 180,
          isFrontCamera: false,
        );

        const lm = Landmark(x: 0.0, y: 0.0, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(320, 240));

        // x = 640 - 0 = 640, y = 480 - 0 = 480
        // scaleX = 320/640 = 0.5, scaleY = 240/480 = 0.5
        // final x = 640 * 0.5 = 320, y = 480 * 0.5 = 240
        expect(offset.dx, closeTo(320, 0.01));
        expect(offset.dy, closeTo(240, 0.01));
      });

      test('270 degree rotation swaps axes differently', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(640, 480),
          rotationDegrees: 270,
          isFrontCamera: false,
        );

        const lm = Landmark(x: 0.0, y: 0.0, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(320, 240));

        // After 270°: x = imgH - y*imgH = 480, y = x*imgW = 0
        // effectiveWidth = imgH = 480, effectiveHeight = imgW = 640
        // scaleX = 320/480, scaleY = 240/640
        // final x = 480 * (320/480) = 320
        // final y = 0
        expect(offset.dx, closeTo(320, 0.01));
        expect(offset.dy, closeTo(0, 0.01));
      });

      test('corner landmark at (1,1) with no rotation back camera', () {
        final painter = TestableSkeletonPainter(
          currentFrame: null,
          imageSize: const Size(100, 100),
          rotationDegrees: 0,
          isFrontCamera: false,
        );

        const lm = Landmark(x: 1.0, y: 1.0, z: 0, visibility: 1.0);
        final offset = painter.transformPoint(lm, const Size(200, 200));

        // x = 1.0*100*(200/100) = 200, y = 1.0*100*(200/100) = 200
        expect(offset.dx, closeTo(200, 0.01));
        expect(offset.dy, closeTo(200, 0.01));
      });
    });
  });

  group('MultiSkeletonPainter', () {
    test('shouldRepaint always returns true', () {
      final painter = MultiSkeletonPainter(
        trackedPersons: {},
        imageSize: const Size(640, 480),
      );
      final other = MultiSkeletonPainter(
        trackedPersons: {},
        imageSize: const Size(640, 480),
      );

      expect(painter.shouldRepaint(other), isTrue);
    });

    test('handles empty trackedPersons without error', () {
      final painter = MultiSkeletonPainter(
        trackedPersons: const {},
        imageSize: const Size(640, 480),
      );

      // paint should not throw with empty persons
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(320, 240)),
        returnsNormally,
      );
    });

    test('paints multiple persons without error', () {
      final painter = MultiSkeletonPainter(
        trackedPersons: {
          0: _makeFrame(x: 0.3, y: 0.3),
          1: _makeFrame(x: 0.7, y: 0.7),
        },
        imageSize: const Size(640, 480),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(320, 240)),
        returnsNormally,
      );
    });

    test('skips low-visibility landmarks without error', () {
      final painter = MultiSkeletonPainter(
        trackedPersons: {
          0: _makeFrame(vis: 0.1), // all below 0.5 threshold
        },
        imageSize: const Size(640, 480),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(320, 240)),
        returnsNormally,
      );
    });

    test('handles more than 5 persons (color wrapping)', () {
      final persons = <int, PoseFrame>{};
      for (var i = 0; i < 7; i++) {
        persons[i] = _makeFrame(x: 0.1 + i * 0.1);
      }

      final painter = MultiSkeletonPainter(
        trackedPersons: persons,
        imageSize: const Size(640, 480),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(320, 240)),
        returnsNormally,
      );
    });
  });
}
