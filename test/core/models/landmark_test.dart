import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Landmark constructor', () {
    test('stores x, y, z values', () {
      final lm = Landmark(x: 1.0, y: 2.0, z: 3.0);
      expect(lm.x, closeTo(1.0, 0.001));
      expect(lm.y, closeTo(2.0, 0.001));
      expect(lm.z, closeTo(3.0, 0.001));
    });

    test('default visibility is 0.0', () {
      final lm = Landmark(x: 0, y: 0, z: 0);
      expect(lm.visibility, closeTo(0.0, 0.001));
    });

    test('custom visibility is stored', () {
      final lm = Landmark(x: 0, y: 0, z: 0, visibility: 0.95);
      expect(lm.visibility, closeTo(0.95, 0.001));
    });
  });

  group('Landmark.copyWith', () {
    test('preserves unchanged values', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith();

      expect(copy.x, closeTo(original.x, 0.001));
      expect(copy.y, closeTo(original.y, 0.001));
      expect(copy.z, closeTo(original.z, 0.001));
      expect(copy.visibility, closeTo(original.visibility, 0.001));
    });

    test('overrides only x', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith(x: 10.0);

      expect(copy.x, closeTo(10.0, 0.001));
      expect(copy.y, closeTo(2.0, 0.001));
      expect(copy.z, closeTo(3.0, 0.001));
      expect(copy.visibility, closeTo(0.9, 0.001));
    });

    test('overrides only y', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith(y: 20.0);

      expect(copy.y, closeTo(20.0, 0.001));
      expect(copy.x, closeTo(1.0, 0.001));
    });

    test('overrides only z', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith(z: 30.0);

      expect(copy.z, closeTo(30.0, 0.001));
      expect(copy.x, closeTo(1.0, 0.001));
    });

    test('overrides only visibility', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith(visibility: 0.1);

      expect(copy.visibility, closeTo(0.1, 0.001));
      expect(copy.x, closeTo(1.0, 0.001));
      expect(copy.y, closeTo(2.0, 0.001));
      expect(copy.z, closeTo(3.0, 0.001));
    });

    test('overrides all values', () {
      final original = Landmark(x: 1.0, y: 2.0, z: 3.0, visibility: 0.9);
      final copy = original.copyWith(x: 10, y: 20, z: 30, visibility: 0.5);

      expect(copy.x, closeTo(10.0, 0.001));
      expect(copy.y, closeTo(20.0, 0.001));
      expect(copy.z, closeTo(30.0, 0.001));
      expect(copy.visibility, closeTo(0.5, 0.001));
    });
  });

  group('Landmark.toString', () {
    test('produces readable output', () {
      final lm = Landmark(x: 0.123456, y: 0.789, z: 0.0, visibility: 0.95);
      final str = lm.toString();
      expect(str, contains('Landmark'));
      expect(str, contains('0.123'));
      expect(str, contains('0.789'));
    });
  });
}
