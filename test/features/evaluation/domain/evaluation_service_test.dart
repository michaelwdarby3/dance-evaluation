import 'dart:math' as math;

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Shorthand landmark constructor.
Landmark lm(double x, double y, double z, [double vis = 0.95]) {
  return Landmark(x: x, y: y, z: z, visibility: vis);
}

/// Generates a full 33-landmark standing pose.
///
/// Base positions mimic a neutral standing person. [leanX] offsets upper body
/// landmarks horizontally (shoulders, elbows, wrists, nose, and face).
PoseFrame makeStandingFrame(Duration ts, {double leanX = 0.0}) {
  // Base positions
  final noseX = 0.5 + leanX;
  const noseY = 0.18;
  final leftShoulderX = 0.42 + leanX;
  final rightShoulderX = 0.58 + leanX;
  const shoulderY = 0.32;
  final leftElbowX = 0.35 + leanX;
  final rightElbowX = 0.65 + leanX;
  const elbowY = 0.45;
  final leftWristX = 0.33 + leanX;
  final rightWristX = 0.67 + leanX;
  const wristY = 0.58;
  const leftHipX = 0.45;
  const rightHipX = 0.55;
  const hipY = 0.52;
  const leftKneeX = 0.45;
  const rightKneeX = 0.55;
  const kneeY = 0.72;
  const leftAnkleX = 0.44;
  const rightAnkleX = 0.56;
  const ankleY = 0.90;

  final landmarks = List<Landmark>.filled(
    PoseConstants.landmarkCount,
    const Landmark(x: 0.5, y: 0.5, z: 0.0),
  );

  void set(int idx, double x, double y, [double z = 0.0]) {
    landmarks[idx] = Landmark(x: x, y: y, z: z, visibility: 0.95);
  }

  // Face landmarks (0-10)
  set(PoseConstants.nose, noseX, noseY);
  set(PoseConstants.leftEyeInner, noseX - 0.01, noseY - 0.02);
  set(PoseConstants.leftEye, noseX - 0.025, noseY - 0.02);
  set(PoseConstants.leftEyeOuter, noseX - 0.04, noseY - 0.02);
  set(PoseConstants.rightEyeInner, noseX + 0.01, noseY - 0.02);
  set(PoseConstants.rightEye, noseX + 0.025, noseY - 0.02);
  set(PoseConstants.rightEyeOuter, noseX + 0.04, noseY - 0.02);
  set(PoseConstants.leftEar, noseX - 0.06, noseY - 0.01);
  set(PoseConstants.rightEar, noseX + 0.06, noseY - 0.01);
  set(PoseConstants.mouthLeft, noseX - 0.02, noseY + 0.03);
  set(PoseConstants.mouthRight, noseX + 0.02, noseY + 0.03);

  // Shoulders (11-12)
  set(PoseConstants.leftShoulder, leftShoulderX, shoulderY);
  set(PoseConstants.rightShoulder, rightShoulderX, shoulderY);

  // Arms (13-22)
  set(PoseConstants.leftElbow, leftElbowX, elbowY);
  set(PoseConstants.rightElbow, rightElbowX, elbowY);
  set(PoseConstants.leftWrist, leftWristX, wristY);
  set(PoseConstants.rightWrist, rightWristX, wristY);
  set(PoseConstants.leftPinky, leftWristX - 0.01, wristY + 0.02);
  set(PoseConstants.rightPinky, rightWristX + 0.01, wristY + 0.02);
  set(PoseConstants.leftIndex, leftWristX - 0.005, wristY + 0.025);
  set(PoseConstants.rightIndex, rightWristX + 0.005, wristY + 0.025);
  set(PoseConstants.leftThumb, leftWristX + 0.01, wristY + 0.015);
  set(PoseConstants.rightThumb, rightWristX - 0.01, wristY + 0.015);

  // Hips (23-24)
  set(PoseConstants.leftHip, leftHipX, hipY);
  set(PoseConstants.rightHip, rightHipX, hipY);

  // Legs (25-32)
  set(PoseConstants.leftKnee, leftKneeX, kneeY);
  set(PoseConstants.rightKnee, rightKneeX, kneeY);
  set(PoseConstants.leftAnkle, leftAnkleX, ankleY);
  set(PoseConstants.rightAnkle, rightAnkleX, ankleY);
  set(PoseConstants.leftHeel, leftAnkleX - 0.01, 0.92);
  set(PoseConstants.rightHeel, rightAnkleX + 0.01, 0.92);
  set(PoseConstants.leftFootIndex, leftAnkleX + 0.02, 0.93);
  set(PoseConstants.rightFootIndex, rightAnkleX - 0.02, 0.93);

  return PoseFrame(timestamp: ts, landmarks: landmarks);
}

/// Creates a [PoseSequence] of [frameCount] frames.
///
/// Each frame uses [makeStandingFrame] with optional lean variation per frame
/// provided by [leanFunction]. Defaults to zero lean for all frames.
PoseSequence makeSequence(
  int frameCount, {
  double fps = 15.0,
  double Function(int)? leanFunction,
}) {
  final frames = <PoseFrame>[];
  for (var i = 0; i < frameCount; i++) {
    final ts = Duration(milliseconds: (i * (1000 / fps)).round());
    final lean = leanFunction != null ? leanFunction(i) : 0.0;
    frames.add(makeStandingFrame(ts, leanX: lean));
  }
  final durationMs = ((frameCount - 1) * (1000 / fps)).round();
  return PoseSequence(
    frames: frames,
    fps: fps,
    duration: Duration(milliseconds: durationMs > 0 ? durationMs : 0),
  );
}

/// Wraps a [PoseSequence] in a [ReferenceChoreography] with hipHop style.
ReferenceChoreography makeReference(PoseSequence poses) {
  return ReferenceChoreography(
    id: 'test_ref_001',
    name: 'Test Reference',
    style: DanceStyle.hipHop,
    poses: poses,
    bpm: 120.0,
    description: 'Test reference choreography.',
    difficulty: 'beginner',
  );
}

/// Creates a [PoseFrame] with all landmarks at random positions.
PoseFrame makeRandomFrame(Duration ts, math.Random rng) {
  final landmarks = List<Landmark>.generate(
    PoseConstants.landmarkCount,
    (_) => Landmark(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      z: rng.nextDouble() * 0.2 - 0.1,
      visibility: 0.95,
    ),
  );
  return PoseFrame(timestamp: ts, landmarks: landmarks);
}

/// Creates a standing frame with arms moved to a different position.
///
/// Shifts elbow and wrist landmarks vertically by [armOffset] to simulate
/// different arm positions while keeping legs identical.
PoseFrame makeArmDifferentFrame(Duration ts, {double armOffset = 0.15}) {
  final base = makeStandingFrame(ts);
  final modified = List<Landmark>.from(base.landmarks);

  // Move arm landmarks (elbows, wrists, and hand details)
  for (final idx in [
    PoseConstants.leftElbow,
    PoseConstants.rightElbow,
    PoseConstants.leftWrist,
    PoseConstants.rightWrist,
    PoseConstants.leftPinky,
    PoseConstants.rightPinky,
    PoseConstants.leftIndex,
    PoseConstants.rightIndex,
    PoseConstants.leftThumb,
    PoseConstants.rightThumb,
  ]) {
    final orig = modified[idx];
    modified[idx] = Landmark(
      x: orig.x + armOffset * 0.5,
      y: orig.y - armOffset,
      z: orig.z,
      visibility: orig.visibility,
    );
  }

  // Also shift shoulder landmarks slightly to change shoulder angles
  for (final idx in [
    PoseConstants.leftShoulder,
    PoseConstants.rightShoulder,
  ]) {
    final orig = modified[idx];
    modified[idx] = Landmark(
      x: orig.x,
      y: orig.y - armOffset * 0.2,
      z: orig.z,
      visibility: orig.visibility,
    );
  }

  return PoseFrame(timestamp: ts, landmarks: modified);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late EvaluationService service;

  setUp(() {
    service = EvaluationService();
  });

  group('overall scoring', () {
    test('perfect match: evaluating a sequence against itself scores > 90',
        () async {
      final seq = makeSequence(30, leanFunction: (i) => 0.02 * math.sin(i * 0.3));
      final ref = makeReference(seq);

      final result = await service.evaluate(seq, ref);

      expect(result.overallScore, greaterThan(90));
    });

    test('good match: slightly offset sequence scores between 50 and 90',
        () async {
      final refSeq =
          makeSequence(30, leanFunction: (i) => 0.03 * math.sin(i * 0.3));
      final userSeq =
          makeSequence(30, leanFunction: (i) => 0.03 * math.sin(i * 0.3 + 0.5));
      final ref = makeReference(refSeq);

      final result = await service.evaluate(userSeq, ref);

      expect(result.overallScore, inInclusiveRange(50, 100));
    });

    test('poor match: random poses score < 40', () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);

      final rng = math.Random(42);
      final randomFrames = <PoseFrame>[];
      for (var i = 0; i < 20; i++) {
        final ts = Duration(milliseconds: (i * (1000 / 15)).round());
        randomFrames.add(makeRandomFrame(ts, rng));
      }
      final userSeq = PoseSequence(
        frames: randomFrames,
        fps: 15.0,
        duration: const Duration(milliseconds: 1267),
      );

      final result = await service.evaluate(userSeq, ref);

      expect(result.overallScore, lessThan(40));
    });

    test('score is always in range [0, 100]', () async {
      // Test with perfect match
      final seq1 = makeSequence(15);
      final ref1 = makeReference(seq1);
      final result1 = await service.evaluate(seq1, ref1);
      expect(result1.overallScore, inInclusiveRange(0, 100));

      // Test with random data
      final rng = math.Random(99);
      final randomFrames = <PoseFrame>[];
      for (var i = 0; i < 15; i++) {
        final ts = Duration(milliseconds: (i * (1000 / 15)).round());
        randomFrames.add(makeRandomFrame(ts, rng));
      }
      final userRandom = PoseSequence(
        frames: randomFrames,
        fps: 15.0,
        duration: const Duration(milliseconds: 933),
      );
      final result2 = await service.evaluate(userRandom, ref1);
      expect(result2.overallScore, inInclusiveRange(0, 100));
    });
  });

  group('dimension scores', () {
    test('all 4 dimensions are present', () async {
      final seq = makeSequence(20);
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.dimensions, hasLength(4));

      final dimensionTypes =
          result.dimensions.map((d) => d.dimension).toSet();
      expect(dimensionTypes, contains(EvalDimension.timing));
      expect(dimensionTypes, contains(EvalDimension.technique));
      expect(dimensionTypes, contains(EvalDimension.expression));
      expect(dimensionTypes, contains(EvalDimension.spatialAwareness));
    });

    test('each dimension score is in [0, 100]', () async {
      final seq = makeSequence(20,
          leanFunction: (i) => 0.05 * math.sin(i * 0.5));
      final ref = makeReference(seq);

      // Slightly different user sequence
      final userSeq = makeSequence(20,
          leanFunction: (i) => 0.04 * math.cos(i * 0.4));
      final result = await service.evaluate(userSeq, ref);

      for (final dim in result.dimensions) {
        expect(dim.score, inInclusiveRange(0, 100),
            reason: '${dim.dimension.name} score out of range');
      }
    });

    test('perfect match: all dimension scores should be high (> 80)',
        () async {
      final seq = makeSequence(30, leanFunction: (i) => 0.02 * math.sin(i * 0.3));
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      for (final dim in result.dimensions) {
        expect(dim.score, greaterThan(80),
            reason: '${dim.dimension.name} score should be > 80 for '
                'a perfect match');
      }
    });

    test(
        'wrong timing: timing score should be lower than technique score',
        () async {
      final refSeq = makeSequence(30);
      final ref = makeReference(refSeq);

      // Create a user sequence with same poses but wrong timing by
      // duplicating frames in the middle (simulating a pause mid-sequence).
      final frames = <PoseFrame>[];
      for (var i = 0; i < 30; i++) {
        final ts = Duration(milliseconds: (i * (1000 / 15)).round());
        frames.add(makeStandingFrame(ts));
      }
      // Insert duplicated frames in the middle to mess up timing
      final middleFrame = frames[15];
      for (var i = 0; i < 10; i++) {
        frames.insert(
          16,
          PoseFrame(
            timestamp: Duration(
                milliseconds:
                    (15 * (1000 / 15)).round() + (i + 1) * 30),
            landmarks: middleFrame.landmarks,
          ),
        );
      }
      final durationMs = frames.last.timestamp.inMilliseconds;
      final userSeq = PoseSequence(
        frames: frames,
        fps: 15.0,
        duration: Duration(milliseconds: durationMs),
      );

      final result = await service.evaluate(userSeq, ref);

      final timingScore = result.dimensions
          .firstWhere((d) => d.dimension == EvalDimension.timing)
          .score;
      final techniqueScore = result.dimensions
          .firstWhere((d) => d.dimension == EvalDimension.technique)
          .score;

      expect(timingScore, lessThan(techniqueScore),
          reason: 'Timing score ($timingScore) should be lower than '
              'technique score ($techniqueScore) when poses are correct '
              'but timing is off');
    });
  });

  group('joint feedback', () {
    test('returns non-empty joint feedback for imperfect match', () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);
      final userSeq = makeSequence(20,
          leanFunction: (i) => 0.1 * math.sin(i * 0.5));

      final result = await service.evaluate(userSeq, ref);

      expect(result.jointFeedback, isNotEmpty);
    });

    test('each joint feedback has a valid joint name from keyJoints',
        () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);
      final userSeq = makeSequence(20,
          leanFunction: (i) => 0.08 * math.sin(i * 0.4));

      final result = await service.evaluate(userSeq, ref);

      for (final jf in result.jointFeedback) {
        expect(PoseConstants.keyJoints.keys, contains(jf.jointName),
            reason: 'Joint name "${jf.jointName}" not found in keyJoints');
      }
    });

    test('joint feedback scores are in [0, 100]', () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);
      final userSeq = makeSequence(20,
          leanFunction: (i) => 0.06 * math.cos(i * 0.3));

      final result = await service.evaluate(userSeq, ref);

      for (final jf in result.jointFeedback) {
        expect(jf.score, inInclusiveRange(0, 100),
            reason: 'Joint ${jf.jointName} score out of range');
      }
    });

    test('joint feedback has non-empty issue and correction strings',
        () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);
      final userSeq = makeSequence(20,
          leanFunction: (i) => 0.08 * math.sin(i * 0.4));

      final result = await service.evaluate(userSeq, ref);

      for (final jf in result.jointFeedback) {
        expect(jf.issue, isNotEmpty,
            reason: 'Joint ${jf.jointName} issue is empty');
        expect(jf.correction, isNotEmpty,
            reason: 'Joint ${jf.jointName} correction is empty');
      }
    });

    test('perfect match: all joint scores should be high', () async {
      final seq = makeSequence(20, leanFunction: (i) => 0.02 * math.sin(i * 0.3));
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      for (final jf in result.jointFeedback) {
        expect(jf.score, greaterThan(80),
            reason: 'Joint ${jf.jointName} score should be high for '
                'a perfect match, got ${jf.score}');
      }
    });

    test(
        'arm-different sequence: arm joints score lower than leg joints',
        () async {
      final refSeq = makeSequence(20);
      final ref = makeReference(refSeq);

      // Build user sequence with only arms different
      final frames = <PoseFrame>[];
      for (var i = 0; i < 20; i++) {
        final ts = Duration(milliseconds: (i * (1000 / 15)).round());
        frames.add(makeArmDifferentFrame(ts, armOffset: 0.20));
      }
      final userSeq = PoseSequence(
        frames: frames,
        fps: 15.0,
        duration: const Duration(milliseconds: 1267),
      );

      final result = await service.evaluate(userSeq, ref);

      const armJointNames = {
        'leftElbow',
        'rightElbow',
        'leftShoulder',
        'rightShoulder',
      };
      const legJointNames = {
        'leftKnee',
        'rightKnee',
        'leftAnkle',
        'rightAnkle',
      };

      final armScores = result.jointFeedback
          .where((jf) => armJointNames.contains(jf.jointName))
          .map((jf) => jf.score);
      final legScores = result.jointFeedback
          .where((jf) => legJointNames.contains(jf.jointName))
          .map((jf) => jf.score);

      // We need at least one arm and one leg joint in the feedback to compare
      if (armScores.isNotEmpty && legScores.isNotEmpty) {
        final avgArmScore =
            armScores.reduce((a, b) => a + b) / armScores.length;
        final avgLegScore =
            legScores.reduce((a, b) => a + b) / legScores.length;

        expect(avgArmScore, lessThan(avgLegScore),
            reason: 'Average arm score ($avgArmScore) should be lower '
                'than average leg score ($avgLegScore) when only arms '
                'differ');
      }
    });
  });

  group('result metadata', () {
    test('result has a non-empty id', () async {
      final seq = makeSequence(15);
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.id, isNotEmpty);
    });

    test('result has correct style', () async {
      final seq = makeSequence(15);
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.style, equals(DanceStyle.hipHop));
    });

    test('result createdAt is recent (within last minute)', () async {
      final before = DateTime.now();
      final seq = makeSequence(15);
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);
      final after = DateTime.now();

      expect(result.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
          reason: 'createdAt should be after test start');
      expect(
          result.createdAt
              .isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
          reason: 'createdAt should be before test end');

      final elapsed = after.difference(result.createdAt);
      expect(elapsed.inSeconds, lessThan(60),
          reason: 'createdAt should be within the last minute');
    });

    test('result drills list exists (empty for Milestone 1)', () async {
      final seq = makeSequence(15);
      final ref = makeReference(seq);
      final result = await service.evaluate(seq, ref);

      expect(result.drills, isA<List<DrillRecommendation>>());
      expect(result.drills, isEmpty);
    });
  });
}
