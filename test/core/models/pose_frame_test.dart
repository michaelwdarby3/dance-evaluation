import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

Landmark _lm(double x, double y, double z) =>
    Landmark(x: x, y: y, z: z, visibility: 1.0);

List<Landmark> _make33Landmarks() =>
    List<Landmark>.generate(33, (i) => _lm(i.toDouble(), 0, 0));

void main() {
  group('PoseFrame constructor', () {
    test('accepts exactly 33 landmarks', () {
      expect(
        () => PoseFrame(
          timestamp: Duration.zero,
          landmarks: _make33Landmarks(),
        ),
        returnsNormally,
      );
    });

    test('assertion fails with fewer than 33 landmarks', () {
      expect(
        () => PoseFrame(
          timestamp: Duration.zero,
          landmarks: List.generate(32, (i) => _lm(0, 0, 0)),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertion fails with more than 33 landmarks', () {
      expect(
        () => PoseFrame(
          timestamp: Duration.zero,
          landmarks: List.generate(34, (i) => _lm(0, 0, 0)),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('PoseFrame.landmarkAt', () {
    test('returns the correct landmark by index', () {
      final landmarks = _make33Landmarks();
      final frame = PoseFrame(timestamp: Duration.zero, landmarks: landmarks);

      expect(frame.landmarkAt(0).x, closeTo(0.0, 0.001));
      expect(frame.landmarkAt(10).x, closeTo(10.0, 0.001));
      expect(frame.landmarkAt(32).x, closeTo(32.0, 0.001));
    });
  });

  group('PoseFrame.angleBetween', () {
    test('computes known 90-degree angle', () {
      final landmarks = _make33Landmarks();
      // Place three specific landmarks forming a right angle.
      // Index 0 at (0,0,0), index 1 at (1,0,0) (vertex), index 2 at (1,1,0).
      landmarks[0] = _lm(0, 0, 0);
      landmarks[1] = _lm(1, 0, 0);
      landmarks[2] = _lm(1, 1, 0);
      final frame = PoseFrame(timestamp: Duration.zero, landmarks: landmarks);

      expect(frame.angleBetween(0, 1, 2), closeTo(90.0, 0.01));
    });

    test('computes known 180-degree angle (straight line)', () {
      final landmarks = _make33Landmarks();
      landmarks[0] = _lm(0, 0, 0);
      landmarks[1] = _lm(1, 0, 0);
      landmarks[2] = _lm(2, 0, 0);
      final frame = PoseFrame(timestamp: Duration.zero, landmarks: landmarks);

      expect(frame.angleBetween(0, 1, 2), closeTo(180.0, 0.01));
    });

    test('returns 0.0 when a segment has zero length', () {
      final landmarks = _make33Landmarks();
      // Vertex and one point are the same, causing zero-length vector.
      landmarks[0] = _lm(5, 5, 5);
      landmarks[1] = _lm(5, 5, 5); // vertex = same as a
      landmarks[2] = _lm(8, 8, 8);
      final frame = PoseFrame(timestamp: Duration.zero, landmarks: landmarks);

      expect(frame.angleBetween(0, 1, 2), closeTo(0.0, 0.01));
    });
  });
}
