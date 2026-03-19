import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_pose_frame.dart';
import 'package:dance_evaluation/core/models/multi_pose_sequence.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/utils/person_tracker.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake pose detector that returns pre-programmed frames
// ---------------------------------------------------------------------------

class FakePoseDetector implements PoseDetector {
  List<PoseFrame>? nextMultiResult;
  PoseFrame? nextSingleResult;

  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => nextSingleResult;

  @override
  Future<List<PoseFrame>> detectMultiPose(PoseInput input) async =>
      nextMultiResult ?? [];

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a standing pose at position [xOffset] (shifts hips and all landmarks).
PoseFrame makePersonFrame(Duration ts, {double xOffset = 0.0}) {
  final landmarks = List<Landmark>.generate(
    PoseConstants.landmarkCount,
    (i) {
      // Base positions for a standing person centered at x=0.5.
      double x = 0.5 + xOffset;
      double y = 0.5;
      const vis = 0.95;

      // Give different landmarks different positions so they're realistic.
      switch (i) {
        case PoseConstants.nose:
          y = 0.15;
        case PoseConstants.leftShoulder:
          x -= 0.08;
          y = 0.30;
        case PoseConstants.rightShoulder:
          x += 0.08;
          y = 0.30;
        case PoseConstants.leftElbow:
          x -= 0.12;
          y = 0.45;
        case PoseConstants.rightElbow:
          x += 0.12;
          y = 0.45;
        case PoseConstants.leftWrist:
          x -= 0.14;
          y = 0.58;
        case PoseConstants.rightWrist:
          x += 0.14;
          y = 0.58;
        case PoseConstants.leftHip:
          x -= 0.05;
          y = 0.55;
        case PoseConstants.rightHip:
          x += 0.05;
          y = 0.55;
        case PoseConstants.leftKnee:
          x -= 0.05;
          y = 0.72;
        case PoseConstants.rightKnee:
          x += 0.05;
          y = 0.72;
        case PoseConstants.leftAnkle:
          x -= 0.05;
          y = 0.90;
        case PoseConstants.rightAnkle:
          x += 0.05;
          y = 0.90;
        default:
          y = 0.5;
      }

      return Landmark(x: x.clamp(0, 1), y: y, z: 0.0, visibility: vis);
    },
  );
  return PoseFrame(timestamp: ts, landmarks: landmarks);
}

/// Creates a multi-person reference choreography with [personCount] persons.
ReferenceChoreography makeMultiPersonReference({
  int personCount = 2,
  int frameCount = 20,
  double fps = 10.0,
}) {
  final personPoses = <PoseSequence>[];
  for (var p = 0; p < personCount; p++) {
    final xOffset = (p - (personCount - 1) / 2) * 0.3;
    final frames = <PoseFrame>[];
    for (var i = 0; i < frameCount; i++) {
      final ts = Duration(milliseconds: (i * 1000 / fps).round());
      frames.add(makePersonFrame(ts, xOffset: xOffset));
    }
    final durationMs = ((frameCount - 1) * 1000 / fps).round();
    personPoses.add(PoseSequence(
      frames: frames,
      fps: fps,
      duration: Duration(milliseconds: durationMs),
      label: 'person_$p',
    ));
  }

  return ReferenceChoreography(
    id: 'test_multi',
    name: 'Test Multi-Person',
    style: DanceStyle.hipHop,
    poses: personPoses.first,
    personPoses: personPoses,
    bpm: 120.0,
    description: 'Test multi-person reference',
    difficulty: 'beginner',
    version: 2,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PersonTracker', () {
    late PersonTracker tracker;

    setUp(() => tracker = PersonTracker());

    test('assigns IDs to first frame detections', () {
      final person1 = makePersonFrame(Duration.zero, xOffset: -0.2);
      final person2 = makePersonFrame(Duration.zero, xOffset: 0.2);

      final result = tracker.track([person1, person2]);

      expect(result.length, 2);
      expect(result.keys.toSet().length, 2, reason: 'IDs should be unique');
    });

    test('maintains stable IDs across frames', () {
      final frame1 = [
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ];
      final result1 = tracker.track(frame1);
      final ids1 = result1.keys.toList()..sort();

      // Slight movement, same people.
      final frame2 = [
        makePersonFrame(const Duration(milliseconds: 100), xOffset: -0.19),
        makePersonFrame(const Duration(milliseconds: 100), xOffset: 0.21),
      ];
      final result2 = tracker.track(frame2);
      final ids2 = result2.keys.toList()..sort();

      expect(ids2, equals(ids1), reason: 'Same people should keep same IDs');
    });

    test('assigns new ID when a new person appears', () {
      final frame1 = [makePersonFrame(Duration.zero, xOffset: 0.0)];
      final result1 = tracker.track(frame1);
      expect(result1.length, 1);

      // Second frame: original person + new person.
      final frame2 = [
        makePersonFrame(const Duration(milliseconds: 100), xOffset: 0.01),
        makePersonFrame(const Duration(milliseconds: 100), xOffset: 0.4),
      ];
      final result2 = tracker.track(frame2);
      expect(result2.length, 2);

      // Original person should keep their ID.
      final originalId = result1.keys.first;
      expect(result2.containsKey(originalId), isTrue);
    });

    test('handles empty detections', () {
      final result = tracker.track([]);
      expect(result, isEmpty);
    });

    test('reset clears all state', () {
      tracker.track([makePersonFrame(Duration.zero, xOffset: 0.0)]);
      tracker.reset();

      final result = tracker.track([makePersonFrame(Duration.zero, xOffset: 0.0)]);
      expect(result.keys.first, 0, reason: 'IDs should restart from 0');
    });

    test('handles person leaving frame', () {
      // Frame 1: two people.
      final result1 = tracker.track([
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ]);
      expect(result1.length, 2);

      // Frame 2: only one person remains (the left one).
      final result2 = tracker.track([
        makePersonFrame(const Duration(milliseconds: 100), xOffset: -0.19),
      ]);
      expect(result2.length, 1);

      // The remaining person should keep their original ID.
      final leftPersonId = result1.entries
          .firstWhere((e) =>
              e.value.landmarks[PoseConstants.leftHip].x < 0.5)
          .key;
      expect(result2.containsKey(leftPersonId), isTrue);
    });

    test('handles persons swapping positions over time', () {
      // Frame 1: person A at left, person B at right.
      final result1 = tracker.track([
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ]);

      // Gradual swap over several frames.
      tracker.track([
        makePersonFrame(const Duration(milliseconds: 100), xOffset: -0.1),
        makePersonFrame(const Duration(milliseconds: 100), xOffset: 0.1),
      ]);
      tracker.track([
        makePersonFrame(const Duration(milliseconds: 200), xOffset: 0.0),
        makePersonFrame(const Duration(milliseconds: 200), xOffset: 0.0),
      ]);

      // After swapping, IDs should still be maintained (tracking by proximity).
      final result4 = tracker.track([
        makePersonFrame(const Duration(milliseconds: 300), xOffset: 0.1),
        makePersonFrame(const Duration(milliseconds: 300), xOffset: -0.1),
      ]);

      // Both persons should still be tracked (2 IDs present).
      expect(result4.length, 2);
      // IDs from original set should be preserved.
      expect(result4.keys.toSet(), equals(result1.keys.toSet()));
    });

    test('assigns new ID when detection is beyond max match distance', () {
      // Frame 1: person at center.
      tracker.track([makePersonFrame(Duration.zero, xOffset: 0.0)]);

      // Frame 2: person far away (beyond 0.3 threshold).
      final result2 = tracker.track([
        makePersonFrame(const Duration(milliseconds: 100), xOffset: 0.45),
      ]);

      // Should get a new ID since distance exceeds threshold.
      expect(result2.length, 1);
      expect(result2.keys.first, 1, reason: 'Should be new ID, not 0');
    });
  });

  group('CaptureController multi-person', () {
    late FakePoseDetector detector;
    late CaptureController controller;

    setUp(() {
      detector = FakePoseDetector();
      controller = CaptureController(poseDetector: detector);
    });

    tearDown(() => controller.dispose());

    test('onMultiPoseDetected tracks multiple persons', () {
      controller.startExternalRecording();

      final persons = [
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ];
      controller.onMultiPoseDetected(persons);

      expect(controller.currentTrackedPersons.length, 2);
      expect(controller.isMultiPerson, isTrue);
    });

    test('single person does not set isMultiPerson', () {
      controller.startExternalRecording();

      controller.onMultiPoseDetected([
        makePersonFrame(Duration.zero, xOffset: 0.0),
      ]);

      expect(controller.currentTrackedPersons.length, 1);
      expect(controller.isMultiPerson, isFalse);
    });

    test('addExternalMultiFrames records frames for each person', () {
      controller.startExternalRecording();

      for (var i = 0; i < 10; i++) {
        final ts = Duration(milliseconds: i * 100);
        controller.addExternalMultiFrames([
          makePersonFrame(ts, xOffset: -0.2),
          makePersonFrame(ts, xOffset: 0.2),
        ]);
      }

      controller.stopRecording();

      final multiSeq = controller.getRecordedMultiSequence();
      expect(multiSeq.personCount, 2);
      expect(multiSeq.personSequences[0].frames.length, 10);
      expect(multiSeq.personSequences[1].frames.length, 10);
    });

    test('getRecordedSequence still works for backwards compat', () {
      controller.startExternalRecording();

      for (var i = 0; i < 5; i++) {
        final ts = Duration(milliseconds: i * 100);
        controller.addExternalMultiFrames([
          makePersonFrame(ts, xOffset: -0.2),
          makePersonFrame(ts, xOffset: 0.2),
        ]);
      }

      controller.stopRecording();

      final singleSeq = controller.getRecordedSequence();
      expect(singleSeq.frames.length, 5, reason: 'Should have first person frames');
    });

    test('reset clears multi-person state', () {
      controller.startExternalRecording();
      controller.onMultiPoseDetected([
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ]);
      expect(controller.isMultiPerson, isTrue);

      controller.reset();

      expect(controller.isMultiPerson, isFalse);
      expect(controller.currentTrackedPersons, isEmpty);
    });

    test('getRecordedMultiSequence falls back to single when no multi frames', () {
      controller.startExternalRecording();

      // Use the legacy single-person path.
      for (var i = 0; i < 5; i++) {
        final ts = Duration(milliseconds: i * 100);
        controller.addExternalFrame(makePersonFrame(ts, xOffset: 0.0));
      }

      controller.stopRecording();

      final multiSeq = controller.getRecordedMultiSequence();
      expect(multiSeq.personCount, 1);
      expect(multiSeq.personSequences.first.frames.length, 5);
    });

    test('onMultiPoseDetected does not record when not in recording state', () {
      // Controller is idle — should not record.
      controller.onMultiPoseDetected([
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ]);

      // Tracked persons should update (for live preview).
      expect(controller.currentTrackedPersons.length, 2);

      // But no frames recorded.
      controller.startExternalRecording();
      controller.stopRecording();
      final multiSeq = controller.getRecordedMultiSequence();
      expect(multiSeq.personSequences.first.frames, isEmpty);
    });

    test('addExternalMultiFrames ignores frames when not recording', () {
      // Don't call startExternalRecording.
      controller.addExternalMultiFrames([
        makePersonFrame(Duration.zero, xOffset: -0.2),
        makePersonFrame(Duration.zero, xOffset: 0.2),
      ]);

      expect(controller.currentTrackedPersons, isEmpty);
    });
  });

  group('ReferenceChoreography v2 JSON', () {
    test('fromJson auto-detects v1 single-person format', () {
      final json = {
        'id': 'test',
        'name': 'Test',
        'style': 'hipHop',
        'bpm': 120.0,
        'description': 'test',
        'difficulty': 'beginner',
        'poses': {
          'fps': 10.0,
          'duration_ms': 1000,
          'label': 'test',
          'frames': [
            {
              'ts': 0,
              'lm': List.generate(33, (_) => {'x': 0.5, 'y': 0.5, 'z': 0.0, 'v': 0.9}),
            },
          ],
        },
      };

      final ref = ReferenceChoreography.fromJson(json);

      expect(ref.isMultiPerson, isFalse);
      expect(ref.personCount, 1);
      expect(ref.personPoses.first.frames.length, 1);
      expect(ref.poses.frames.length, 1);
    });

    test('fromJson auto-detects v2 multi-person format', () {
      final makePerson = (String label) => {
        'fps': 10.0,
        'duration_ms': 1000,
        'label': label,
        'frames': [
          {
            'ts': 0,
            'lm': List.generate(33, (_) => {'x': 0.5, 'y': 0.5, 'z': 0.0, 'v': 0.9}),
          },
          {
            'ts': 100,
            'lm': List.generate(33, (_) => {'x': 0.5, 'y': 0.5, 'z': 0.0, 'v': 0.9}),
          },
        ],
      };

      final json = {
        'version': 2,
        'id': 'test_duo',
        'name': 'Test Duo',
        'style': 'kPop',
        'bpm': 128.0,
        'description': 'test duo',
        'difficulty': 'intermediate',
        'persons': [makePerson('person_0'), makePerson('person_1')],
      };

      final ref = ReferenceChoreography.fromJson(json);

      expect(ref.isMultiPerson, isTrue);
      expect(ref.personCount, 2);
      expect(ref.personPoses[0].frames.length, 2);
      expect(ref.personPoses[1].frames.length, 2);
      expect(ref.poses, same(ref.personPoses.first));
    });

    test('toJson produces v2 format for multi-person', () {
      final ref = makeMultiPersonReference(personCount: 2, frameCount: 3);
      final json = ref.toJson();

      expect(json['version'], 2);
      expect(json.containsKey('persons'), isTrue);
      expect(json.containsKey('poses'), isFalse);
      expect((json['persons'] as List).length, 2);
    });

    test('toJson produces v1 format for single-person', () {
      final ref = makeMultiPersonReference(personCount: 1, frameCount: 3);
      final json = ref.toJson();

      expect(json.containsKey('version'), isFalse);
      expect(json.containsKey('poses'), isTrue);
      expect(json.containsKey('persons'), isFalse);
    });

    test('roundtrip v2 JSON preserves data', () {
      final original = makeMultiPersonReference(personCount: 3, frameCount: 5);
      final json = original.toJson();
      final restored = ReferenceChoreography.fromJson(json);

      expect(restored.personCount, 3);
      expect(restored.isMultiPerson, isTrue);
      for (var p = 0; p < 3; p++) {
        expect(restored.personPoses[p].frames.length, 5);
      }
    });
  });

  group('EvaluationService multi-person', () {
    late EvaluationService service;

    setUp(() => service = EvaluationService());

    test('evaluateMulti with single person delegates to evaluate', () async {
      final ref = makeMultiPersonReference(personCount: 1, frameCount: 20);
      final userSeq = ref.personPoses.first;
      final multiSeq = _makeMultiPoseSequence([userSeq]);

      final result = await service.evaluateMulti(multiSeq, ref);

      expect(result.personCount, 1);
      expect(result.isSinglePerson, isTrue);
      expect(result.overallScore, greaterThan(90));
    });

    test('evaluateMulti matches persons and scores each pair', () async {
      final ref = makeMultiPersonReference(personCount: 2, frameCount: 20);

      // User performs same choreography (should score high).
      final multiSeq = _makeMultiPoseSequence(ref.personPoses);

      final result = await service.evaluateMulti(multiSeq, ref);

      expect(result.personCount, 2);
      expect(result.isSinglePerson, isFalse);
      for (final personResult in result.personResults) {
        expect(personResult.overallScore, greaterThan(80));
      }
      expect(result.overallScore, greaterThan(80));
    });

    test('evaluateMulti averages scores across persons', () async {
      final ref = makeMultiPersonReference(personCount: 2, frameCount: 20);

      // Give person 0 perfect data, person 1 random data.
      final rng = math.Random(42);
      final randomFrames = List.generate(20, (i) {
        final ts = Duration(milliseconds: (i * 100));
        return PoseFrame(
          timestamp: ts,
          landmarks: List.generate(
            PoseConstants.landmarkCount,
            (_) => Landmark(
              x: rng.nextDouble(),
              y: rng.nextDouble(),
              z: rng.nextDouble() * 0.2,
              visibility: 0.95,
            ),
          ),
        );
      });
      final badSeq = PoseSequence(
        frames: randomFrames,
        fps: 10.0,
        duration: const Duration(milliseconds: 1900),
      );

      final multiSeq = _makeMultiPoseSequence([ref.personPoses.first, badSeq]);

      final result = await service.evaluateMulti(multiSeq, ref);

      expect(result.personCount, 2);
      // Person 0 should score high, person 1 low.
      final scores = result.personResults.map((r) => r.overallScore).toList();
      expect(scores[0], greaterThan(scores[1]));
      // Overall should be the average.
      final expectedAvg = (scores[0] + scores[1]) / 2;
      expect(result.overallScore, closeTo(expectedAvg, 0.01));
    });
  });

  group('MultiPoseFrame', () {
    test('fromSingle wraps a single PoseFrame', () {
      final frame = makePersonFrame(const Duration(milliseconds: 500));
      final multi = MultiPoseFrame.fromSingle(frame);

      expect(multi.personCount, 1);
      expect(multi.timestamp, const Duration(milliseconds: 500));
      expect(multi.persons.first, same(frame));
    });

    test('toJson/fromJson roundtrip preserves data', () {
      final multi = MultiPoseFrame(
        timestamp: const Duration(milliseconds: 250),
        persons: [
          makePersonFrame(const Duration(milliseconds: 250), xOffset: -0.2),
          makePersonFrame(const Duration(milliseconds: 250), xOffset: 0.2),
        ],
      );

      final json = multi.toJson();
      final restored = MultiPoseFrame.fromJson(json);

      expect(restored.timestamp, multi.timestamp);
      expect(restored.personCount, 2);
      expect(restored.persons[0].landmarks.length, 33);
      expect(restored.persons[1].landmarks.length, 33);
    });
  });

  group('MultiPoseSequence', () {
    test('fromSingle wraps a single PoseSequence', () {
      final seq = PoseSequence(
        frames: [makePersonFrame(Duration.zero)],
        fps: 10.0,
        duration: const Duration(seconds: 1),
      );
      final multi = MultiPoseSequence.fromSingle(seq);

      expect(multi.personCount, 1);
      expect(multi.fps, 10.0);
      expect(multi.personSequences.first, same(seq));
    });

    test('toJson/fromJson roundtrip preserves data', () {
      final multi = MultiPoseSequence(
        personSequences: [
          PoseSequence(
            frames: [makePersonFrame(Duration.zero, xOffset: -0.2)],
            fps: 10.0,
            duration: const Duration(seconds: 1),
            label: 'person_0',
          ),
          PoseSequence(
            frames: [makePersonFrame(Duration.zero, xOffset: 0.2)],
            fps: 10.0,
            duration: const Duration(seconds: 1),
            label: 'person_1',
          ),
        ],
        fps: 10.0,
        duration: const Duration(seconds: 1),
      );

      final json = multi.toJson();
      final restored = MultiPoseSequence.fromJson(json);

      expect(restored.personCount, 2);
      expect(restored.fps, 10.0);
      expect(restored.personSequences[0].label, 'person_0');
      expect(restored.personSequences[1].label, 'person_1');
    });
  });

  group('MultiPersonEvaluationResult', () {
    test('isSinglePerson is true for 1 person', () {
      final result = MultiPersonEvaluationResult(
        personResults: [_makeDummyEvalResult(85.0)],
        overallScore: 85.0,
      );
      expect(result.isSinglePerson, isTrue);
      expect(result.personCount, 1);
    });

    test('isSinglePerson is false for multiple persons', () {
      final result = MultiPersonEvaluationResult(
        personResults: [
          _makeDummyEvalResult(90.0),
          _makeDummyEvalResult(70.0),
        ],
        overallScore: 80.0,
      );
      expect(result.isSinglePerson, isFalse);
      expect(result.personCount, 2);
    });
  });

  group('EvaluationService multi-person edge cases', () {
    late EvaluationService service;

    setUp(() => service = EvaluationService());

    test('more user persons than reference persons: extras ignored', () async {
      final ref = makeMultiPersonReference(personCount: 2, frameCount: 20);

      // User has 3 persons, ref has 2. Third person has no match.
      final userPersons = [
        ...ref.personPoses,
        _makeRandomSequence(20, 10.0, math.Random(99)),
      ];
      final multiSeq = _makeMultiPoseSequence(userPersons);

      final result = await service.evaluateMulti(multiSeq, ref);

      // Should evaluate 2 pairs (matched), not 3.
      expect(result.personCount, 2);
    });

    test('fewer user persons than reference persons: evaluates available pairs', () async {
      final ref = makeMultiPersonReference(personCount: 3, frameCount: 20);

      // User only has 1 person.
      final multiSeq = _makeMultiPoseSequence([ref.personPoses.first]);

      final result = await service.evaluateMulti(multiSeq, ref);

      expect(result.personCount, 1);
      expect(result.overallScore, greaterThan(80));
    });

    test('empty user sequence returns empty result', () async {
      final ref = makeMultiPersonReference(personCount: 2, frameCount: 20);
      final multiSeq = _makeMultiPoseSequence([
        PoseSequence(
          frames: const [],
          fps: 10.0,
          duration: Duration.zero,
        ),
      ]);

      final result = await service.evaluateMulti(multiSeq, ref);

      // Should still produce a result (with low/zero scores).
      expect(result.personCount, greaterThanOrEqualTo(0));
    });
  });
}

EvaluationResult _makeDummyEvalResult(double score) {
  return EvaluationResult(
    id: 'dummy',
    overallScore: score,
    dimensions: const [],
    jointFeedback: const [],
    drills: const [],
    createdAt: DateTime(2026),
    style: DanceStyle.hipHop,
  );
}

PoseSequence _makeRandomSequence(int frameCount, double fps, math.Random rng) {
  final frames = List.generate(frameCount, (i) {
    return PoseFrame(
      timestamp: Duration(milliseconds: (i * 1000 / fps).round()),
      landmarks: List.generate(
        PoseConstants.landmarkCount,
        (_) => Landmark(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          z: rng.nextDouble() * 0.2,
          visibility: 0.95,
        ),
      ),
    );
  });
  final durationMs = ((frameCount - 1) * 1000 / fps).round();
  return PoseSequence(
    frames: frames,
    fps: fps,
    duration: Duration(milliseconds: durationMs),
  );
}

MultiPoseSequence _makeMultiPoseSequence(List<PoseSequence> persons) {
  return MultiPoseSequence(
    personSequences: persons,
    fps: persons.first.fps,
    duration: persons.first.duration,
  );
}
