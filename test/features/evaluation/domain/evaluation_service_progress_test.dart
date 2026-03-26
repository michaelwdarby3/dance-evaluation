import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/models/multi_pose_sequence.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';

PoseFrame _makeFrame(Duration ts, {double x = 0.5, double vis = 0.95}) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      33,
      (j) => Landmark(x: x + j * 0.01, y: 0.5 + j * 0.005, z: 0, visibility: vis),
    ),
  );
}

ReferenceChoreography _makeRef({int frameCount = 10}) {
  final frames = List.generate(frameCount, (i) {
    return _makeFrame(Duration(milliseconds: i * 100));
  });
  return ReferenceChoreography(
    id: 'test',
    name: 'Test',
    style: DanceStyle.hipHop,
    poses: PoseSequence(
      frames: frames,
      fps: 10.0,
      duration: Duration(milliseconds: (frameCount - 1) * 100),
    ),
    bpm: 120.0,
    description: 'Test',
    difficulty: 'beginner',
  );
}

PoseSequence _makeUserSequence({int frameCount = 10, double vis = 0.95}) {
  return PoseSequence(
    frames: List.generate(frameCount, (i) {
      return _makeFrame(Duration(milliseconds: i * 100), vis: vis);
    }),
    fps: 10.0,
    duration: Duration(milliseconds: (frameCount - 1) * 100),
  );
}

void main() {
  late EvaluationService service;

  setUp(() {
    service = EvaluationService();
  });

  group('onProgress callback', () {
    test('evaluate calls onProgress with increasing values', () async {
      final stages = <String>[];
      final progresses = <double>[];

      await service.evaluate(
        _makeUserSequence(),
        _makeRef(),
        onProgress: (stage, progress) {
          stages.add(stage);
          progresses.add(progress);
        },
      );

      expect(stages, isNotEmpty);
      expect(stages.first, contains('Normalizing'));
      expect(stages.last, contains('Complete'));

      // Progress values should be monotonically increasing.
      for (var i = 1; i < progresses.length; i++) {
        expect(progresses[i], greaterThanOrEqualTo(progresses[i - 1]));
      }

      // Should reach 1.0.
      expect(progresses.last, 1.0);
    });

    test('evaluate works without onProgress callback', () async {
      final result = await service.evaluate(
        _makeUserSequence(),
        _makeRef(),
      );

      expect(result.overallScore, inInclusiveRange(0, 100));
    });

    test('evaluateMulti calls onProgress', () async {
      final stages = <String>[];

      final ref = _makeRef();
      final multi = await service.evaluateMulti(
        // Wrap in multi with single person — takes the shortcut path.
        _makeUserSequence().asMulti(),
        ref,
        onProgress: (stage, progress) {
          stages.add(stage);
        },
      );

      expect(multi.personResults, isNotEmpty);
      expect(stages, isNotEmpty);
    });
  });

  group('confidence filtering', () {
    test('low confidence frames are filtered out', () async {
      // Mix high and low confidence frames.
      final frames = <PoseFrame>[
        _makeFrame(const Duration(milliseconds: 0), vis: 0.9),   // keep
        _makeFrame(const Duration(milliseconds: 100), vis: 0.1), // drop
        _makeFrame(const Duration(milliseconds: 200), vis: 0.9), // keep
        _makeFrame(const Duration(milliseconds: 300), vis: 0.05),// drop
        _makeFrame(const Duration(milliseconds: 400), vis: 0.9), // keep
      ];
      final userSeq = PoseSequence(
        frames: frames,
        fps: 10.0,
        duration: const Duration(milliseconds: 400),
      );

      service.minConfidence = 0.3;
      final result = await service.evaluate(userSeq, _makeRef(frameCount: 5));

      // Should still produce a valid result.
      expect(result.overallScore, inInclusiveRange(0, 100));
    });

    test('minConfidence of 0 keeps all frames', () async {
      service.minConfidence = 0.0;
      final result = await service.evaluate(
        _makeUserSequence(vis: 0.01),
        _makeRef(),
      );

      expect(result.overallScore, inInclusiveRange(0, 100));
    });

    test('filtering returns original if all frames would be removed', () async {
      service.minConfidence = 0.99;
      final result = await service.evaluate(
        _makeUserSequence(vis: 0.1),
        _makeRef(),
      );

      // Falls back to original sequence, so still produces a result.
      expect(result.overallScore, inInclusiveRange(0, 100));
    });
  });

  group('drill wiring', () {
    test('evaluate returns drills for weak performance', () async {
      // Use very different user vs reference to get low scores.
      final ref = _makeRef(frameCount: 10);
      final userSeq = PoseSequence(
        frames: List.generate(10, (i) {
          return PoseFrame(
            timestamp: Duration(milliseconds: i * 100),
            landmarks: List.generate(
              33,
              (_) => const Landmark(x: 0.9, y: 0.9, z: 0, visibility: 0.9),
            ),
          );
        }),
        fps: 10.0,
        duration: const Duration(milliseconds: 900),
      );

      final result = await service.evaluate(userSeq, ref);

      // With poor scores, drill catalog should recommend drills.
      expect(result.drills, isNotEmpty);
      for (final drill in result.drills) {
        expect(drill.name, isNotEmpty);
        expect(drill.description, isNotEmpty);
      }
    });
  });
}

extension on PoseSequence {
  /// Wraps this single-person sequence as a MultiPoseSequence.
  MultiPoseSequence asMulti() {
    return MultiPoseSequence.fromSingle(this);
  }
}
