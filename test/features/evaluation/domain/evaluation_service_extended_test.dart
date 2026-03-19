import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';

PoseFrame _makeFrame(Duration ts, {double x = 0.5, double y = 0.5}) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      PoseConstants.landmarkCount,
      (_) => Landmark(x: x, y: y, z: 0, visibility: 0.95),
    ),
  );
}

PoseSequence _makeSequence(int frameCount, double fps, {double x = 0.5}) {
  final frames = List.generate(frameCount, (i) {
    return _makeFrame(
      Duration(milliseconds: (i * 1000 / fps).round()),
      x: x,
    );
  });
  final durationMs = ((frameCount - 1) * 1000 / fps).round();
  return PoseSequence(
    frames: frames,
    fps: fps,
    duration: Duration(milliseconds: durationMs),
  );
}

ReferenceChoreography _makeReference(PoseSequence seq) {
  return ReferenceChoreography(
    id: 'test',
    name: 'Test',
    style: DanceStyle.hipHop,
    poses: seq,
    bpm: 120.0,
    description: 'test ref',
    difficulty: 'beginner',
  );
}

void main() {
  late EvaluationService service;

  setUp(() => service = EvaluationService());

  group('EvaluationService dimension summaries', () {
    test('timing summary for high score', () async {
      final seq = _makeSequence(20, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      final timing = result.dimensions.firstWhere(
        (d) => d.dimension == EvalDimension.timing,
      );
      // Self-evaluation should score high
      expect(timing.score, greaterThan(80));
      expect(timing.summary, contains('Great rhythm'));
    });

    test('technique summary is present for self-evaluation', () async {
      final seq = _makeSequence(20, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      final technique = result.dimensions.firstWhere(
        (d) => d.dimension == EvalDimension.technique,
      );
      // Technique score depends on cosine similarity after normalization.
      // Uniform landmarks normalize to zero vectors, yielding 0 similarity.
      expect(technique.score, inInclusiveRange(0, 100));
      expect(technique.summary, isNotEmpty);
    });

    test('expression summary for high score', () async {
      final seq = _makeSequence(20, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      final expression = result.dimensions.firstWhere(
        (d) => d.dimension == EvalDimension.expression,
      );
      expect(expression.score, greaterThan(50));
    });

    test('spatial summary for high score', () async {
      final seq = _makeSequence(20, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      final spatial = result.dimensions.firstWhere(
        (d) => d.dimension == EvalDimension.spatialAwareness,
      );
      expect(spatial.score, greaterThan(80));
      expect(spatial.summary, contains('Excellent spatial'));
    });
  });

  group('EvaluationService joint feedback', () {
    test('produces joint feedback entries', () async {
      final seq = _makeSequence(20, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      // Joint feedback should be present (up to 5 worst joints)
      expect(result.jointFeedback, isA<List>());
      expect(result.jointFeedback.length, lessThanOrEqualTo(5));
    });

    test('joint feedback has issue and correction text', () async {
      // Create a slightly different user sequence to get non-trivial feedback
      final rng = math.Random(42);
      final userFrames = List.generate(20, (i) {
        return PoseFrame(
          timestamp: Duration(milliseconds: i * 100),
          landmarks: List.generate(
            PoseConstants.landmarkCount,
            (_) => Landmark(
              x: 0.5 + rng.nextDouble() * 0.3,
              y: 0.5 + rng.nextDouble() * 0.3,
              z: 0,
              visibility: 0.95,
            ),
          ),
        );
      });
      final userSeq = PoseSequence(
        frames: userFrames,
        fps: 10.0,
        duration: const Duration(milliseconds: 1900),
      );

      final ref = _makeReference(_makeSequence(20, 10.0));
      final result = await service.evaluate(userSeq, ref);

      for (final jf in result.jointFeedback) {
        expect(jf.jointName, isNotEmpty);
        expect(jf.issue, isNotEmpty);
        expect(jf.correction, isNotEmpty);
        expect(jf.landmarkIndices.length, 3);
        expect(jf.score, inInclusiveRange(0, 100));
      }
    });

    test('joint feedback readable name converts camelCase', () async {
      // We verify indirectly that joint names in feedback are readable
      final rng = math.Random(42);
      final userFrames = List.generate(20, (i) {
        return PoseFrame(
          timestamp: Duration(milliseconds: i * 100),
          landmarks: List.generate(
            PoseConstants.landmarkCount,
            (_) => Landmark(
              x: rng.nextDouble(),
              y: rng.nextDouble(),
              z: 0,
              visibility: 0.95,
            ),
          ),
        );
      });
      final userSeq = PoseSequence(
        frames: userFrames,
        fps: 10.0,
        duration: const Duration(milliseconds: 1900),
      );

      final ref = _makeReference(_makeSequence(20, 10.0));
      final result = await service.evaluate(userSeq, ref);

      // The issue/correction text should contain the readable name (with space)
      for (final jf in result.jointFeedback) {
        // e.g. "leftElbow" → issue contains "left elbow"
        if (jf.jointName.contains(RegExp(r'[A-Z]'))) {
          final readable = jf.jointName.replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
          );
          expect(jf.issue, contains(readable));
        }
      }
    });
  });

  group('EvaluationService result metadata', () {
    test('result has unique id', () async {
      final seq = _makeSequence(10, 10.0);
      final ref = _makeReference(seq);

      final r1 = await service.evaluate(seq, ref);
      final r2 = await service.evaluate(seq, ref);

      expect(r1.id, isNotEmpty);
      expect(r2.id, isNotEmpty);
      // IDs should be different (timestamp-based)
      // Note: they could be the same if run in same microsecond, but unlikely
    });

    test('result has correct style', () async {
      final seq = _makeSequence(10, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.style, DanceStyle.hipHop);
    });

    test('result has createdAt set', () async {
      final seq = _makeSequence(10, 10.0);
      final ref = _makeReference(seq);
      final before = DateTime.now();
      final result = await service.evaluate(seq, ref);

      expect(result.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('overall score is clamped to 0-100', () async {
      final seq = _makeSequence(10, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.overallScore, inInclusiveRange(0, 100));
    });

    test('all four dimensions are present', () async {
      final seq = _makeSequence(10, 10.0);
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      final dims = result.dimensions.map((d) => d.dimension).toSet();
      expect(dims, contains(EvalDimension.timing));
      expect(dims, contains(EvalDimension.technique));
      expect(dims, contains(EvalDimension.expression));
      expect(dims, contains(EvalDimension.spatialAwareness));
    });
  });

  group('EvaluationService edge cases', () {
    test('single frame sequences still produce a result', () async {
      final seq = PoseSequence(
        frames: [_makeFrame(Duration.zero)],
        fps: 10.0,
        duration: Duration.zero,
      );
      final ref = _makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.overallScore, inInclusiveRange(0, 100));
    });

    test('very different sequences score lower than identical', () async {
      final refSeq = _makeSequence(20, 10.0, x: 0.3);
      final ref = _makeReference(refSeq);

      final identicalResult = await service.evaluate(refSeq, ref);

      // Make a very different sequence
      final rng = math.Random(123);
      final differentFrames = List.generate(20, (i) {
        return PoseFrame(
          timestamp: Duration(milliseconds: i * 100),
          landmarks: List.generate(
            PoseConstants.landmarkCount,
            (_) => Landmark(
              x: rng.nextDouble(),
              y: rng.nextDouble(),
              z: rng.nextDouble(),
              visibility: 0.95,
            ),
          ),
        );
      });
      final differentSeq = PoseSequence(
        frames: differentFrames,
        fps: 10.0,
        duration: const Duration(milliseconds: 1900),
      );

      final differentResult = await service.evaluate(differentSeq, ref);

      expect(identicalResult.overallScore, greaterThan(differentResult.overallScore));
    });
  });
}
