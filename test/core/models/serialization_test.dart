import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

List<Landmark> _makeLandmarks({double x = 0.5, double y = 0.5}) {
  return List.generate(
    33,
    (i) => Landmark(
      x: x + i * 0.01,
      y: y + i * 0.005,
      z: i * 0.002,
      visibility: 0.9 + i * 0.001,
    ),
  );
}

void main() {
  group('Landmark serialization', () {
    test('toJson produces correct keys', () {
      const lm = Landmark(x: 0.1, y: 0.2, z: 0.3, visibility: 0.95);
      final json = lm.toJson();

      expect(json['x'], 0.1);
      expect(json['y'], 0.2);
      expect(json['z'], 0.3);
      expect(json['v'], 0.95);
    });

    test('fromJson parses all fields', () {
      final json = {'x': 0.1, 'y': 0.2, 'z': 0.3, 'v': 0.95};
      final lm = Landmark.fromJson(json);

      expect(lm.x, 0.1);
      expect(lm.y, 0.2);
      expect(lm.z, 0.3);
      expect(lm.visibility, 0.95);
    });

    test('fromJson defaults visibility to 0.0 when missing', () {
      final json = {'x': 0.1, 'y': 0.2, 'z': 0.3};
      final lm = Landmark.fromJson(json);

      expect(lm.visibility, 0.0);
    });

    test('roundtrip preserves values', () {
      const original = Landmark(x: 0.123, y: 0.456, z: -0.789, visibility: 0.99);
      final restored = Landmark.fromJson(original.toJson());

      expect(restored.x, original.x);
      expect(restored.y, original.y);
      expect(restored.z, original.z);
      expect(restored.visibility, original.visibility);
    });

    test('fromJson handles integer values', () {
      final json = {'x': 1, 'y': 0, 'z': -1, 'v': 1};
      final lm = Landmark.fromJson(json);

      expect(lm.x, 1.0);
      expect(lm.y, 0.0);
      expect(lm.z, -1.0);
      expect(lm.visibility, 1.0);
    });
  });

  group('PoseFrame serialization', () {
    test('toJson produces ts and lm keys', () {
      final frame = PoseFrame(
        timestamp: const Duration(milliseconds: 1500),
        landmarks: _makeLandmarks(),
      );
      final json = frame.toJson();

      expect(json['ts'], 1500);
      expect(json['lm'], isA<List>());
      expect((json['lm'] as List).length, 33);
    });

    test('fromJson parses timestamp and landmarks', () {
      final frame = PoseFrame(
        timestamp: const Duration(milliseconds: 750),
        landmarks: _makeLandmarks(),
      );
      final json = frame.toJson();
      final restored = PoseFrame.fromJson(json);

      expect(restored.timestamp, const Duration(milliseconds: 750));
      expect(restored.landmarks.length, 33);
    });

    test('roundtrip preserves landmark values', () {
      final original = PoseFrame(
        timestamp: const Duration(milliseconds: 250),
        landmarks: _makeLandmarks(x: 0.3, y: 0.7),
      );
      final restored = PoseFrame.fromJson(original.toJson());

      for (var i = 0; i < 33; i++) {
        expect(restored.landmarks[i].x, original.landmarks[i].x);
        expect(restored.landmarks[i].y, original.landmarks[i].y);
        expect(restored.landmarks[i].z, original.landmarks[i].z);
        expect(restored.landmarks[i].visibility, original.landmarks[i].visibility);
      }
    });
  });

  group('PoseSequence serialization', () {
    test('toJson produces all expected keys', () {
      final seq = PoseSequence(
        frames: [
          PoseFrame(timestamp: Duration.zero, landmarks: _makeLandmarks()),
          PoseFrame(
            timestamp: const Duration(milliseconds: 100),
            landmarks: _makeLandmarks(),
          ),
        ],
        fps: 10.0,
        duration: const Duration(seconds: 1),
        label: 'test_seq',
      );
      final json = seq.toJson();

      expect(json['fps'], 10.0);
      expect(json['duration_ms'], 1000);
      expect(json['label'], 'test_seq');
      expect((json['frames'] as List).length, 2);
    });

    test('fromJson parses all fields', () {
      final seq = PoseSequence(
        frames: [
          PoseFrame(timestamp: Duration.zero, landmarks: _makeLandmarks()),
        ],
        fps: 15.0,
        duration: const Duration(milliseconds: 2500),
        label: 'my_label',
      );
      final restored = PoseSequence.fromJson(seq.toJson());

      expect(restored.fps, 15.0);
      expect(restored.duration, const Duration(milliseconds: 2500));
      expect(restored.label, 'my_label');
      expect(restored.frames.length, 1);
    });

    test('fromJson handles null label', () {
      final seq = PoseSequence(
        frames: [
          PoseFrame(timestamp: Duration.zero, landmarks: _makeLandmarks()),
        ],
        fps: 10.0,
        duration: const Duration(seconds: 1),
      );
      final restored = PoseSequence.fromJson(seq.toJson());

      expect(restored.label, isNull);
    });

    test('roundtrip preserves frame data', () {
      final original = PoseSequence(
        frames: [
          PoseFrame(
            timestamp: Duration.zero,
            landmarks: _makeLandmarks(x: 0.1, y: 0.2),
          ),
          PoseFrame(
            timestamp: const Duration(milliseconds: 500),
            landmarks: _makeLandmarks(x: 0.3, y: 0.4),
          ),
        ],
        fps: 20.0,
        duration: const Duration(milliseconds: 500),
        label: 'roundtrip',
      );
      final restored = PoseSequence.fromJson(original.toJson());

      expect(restored.frames.length, 2);
      expect(restored.frames[0].timestamp, Duration.zero);
      expect(restored.frames[1].timestamp, const Duration(milliseconds: 500));
      expect(restored.frames[0].landmarks[0].x, original.frames[0].landmarks[0].x);
      expect(restored.frames[1].landmarks[0].x, original.frames[1].landmarks[0].x);
    });

    test('empty frames list roundtrips', () {
      final seq = PoseSequence(
        frames: const [],
        fps: 10.0,
        duration: Duration.zero,
      );
      final restored = PoseSequence.fromJson(seq.toJson());

      expect(restored.frames, isEmpty);
      expect(restored.fps, 10.0);
    });
  });
}
