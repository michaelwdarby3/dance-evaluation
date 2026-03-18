import 'dart:math' as math;

import '../../core/constants/pose_constants.dart';
import '../../core/constants/style_constants.dart';
import '../../core/models/pose_frame.dart';
import '../../core/models/pose_sequence.dart';
import '../../core/models/reference_choreography.dart';

/// Returns a hardcoded reference choreography for a basic hip-hop two-step
/// bounce pattern. Useful for testing evaluation and DTW alignment.
///
/// 30 frames at 15 fps (2 seconds):
///  - Frames 0-9:   Standing with slight left lean, left arm up.
///  - Frames 10-19: Transition to right lean, right arm up.
///  - Frames 20-29: Return to center.
ReferenceChoreography getHipHopBasicReference() {
  final frames = <PoseFrame>[];

  for (var i = 0; i < 30; i++) {
    final t = Duration(milliseconds: (i * (1000 / 15)).round());

    double leanX;
    double leftArmAngle;
    double rightArmAngle;

    if (i < 10) {
      // Phase 1: left lean, left arm raised.
      final progress = i / 9.0;
      leanX = -0.04 * progress;
      leftArmAngle = 45.0 + 90.0 * progress; // 45 -> 135 degrees
      rightArmAngle = 45.0 - 15.0 * progress; // 45 -> 30 degrees
    } else if (i < 20) {
      // Phase 2: transition to right lean, right arm raised.
      final progress = (i - 10) / 9.0;
      leanX = -0.04 + 0.08 * progress; // -0.04 -> +0.04
      leftArmAngle = 135.0 - 105.0 * progress; // 135 -> 30 degrees
      rightArmAngle = 30.0 + 105.0 * progress; // 30 -> 135 degrees
    } else {
      // Phase 3: return to center.
      final progress = (i - 20) / 9.0;
      leanX = 0.04 * (1.0 - progress); // 0.04 -> 0
      leftArmAngle = 30.0 + 15.0 * progress; // 30 -> 45 degrees
      rightArmAngle = 135.0 - 90.0 * progress; // 135 -> 45 degrees
    }

    frames.add(_makeFrame(t, leanX, leftArmAngle, rightArmAngle));
  }

  return ReferenceChoreography(
    id: 'hip_hop_basic_001',
    name: 'Basic Hip Hop Two-Step',
    style: DanceStyle.hipHop,
    poses: PoseSequence(
      frames: frames,
      fps: 15.0,
      duration: const Duration(seconds: 2),
      label: 'hip_hop_basic',
    ),
    bpm: 100.0,
    description:
        'A simple hip-hop two-step bounce with alternating arm raises and '
        'lateral weight shifts. Great for beginners learning rhythm and '
        'body isolation.',
    difficulty: 'beginner',
  );
}

/// Generates a full 33-landmark [PoseFrame] from a base standing pose,
/// modified by lean and arm angle parameters.
///
/// - [ts]: timestamp for this frame.
/// - [leanX]: lateral offset applied to the upper body (negative = left).
/// - [leftArmAngle]: angle of the left arm from the body in degrees
///   (0 = arm down at side, 180 = straight up).
/// - [rightArmAngle]: angle of the right arm from the body in degrees.
PoseFrame _makeFrame(
  Duration ts,
  double leanX,
  double leftArmAngle,
  double rightArmAngle,
) {
  // --- Base standing pose (normalized 0-1 coordinates) ---
  // x: 0.5 = center, y: 0 = top, 1 = bottom, z: ~0 for most landmarks.

  // Slight bounce: vertical shift based on lean magnitude.
  final bounce = leanX.abs() * 0.3;

  // Convert arm angles to radians for position calculation.
  final leftArmRad = leftArmAngle * (math.pi / 180.0);
  final rightArmRad = rightArmAngle * (math.pi / 180.0);

  // -- Torso key points --
  final shoulderY = 0.32 + bounce * 0.02;
  final hipY = 0.52 + bounce * 0.03;

  final leftShoulderX = 0.42 + leanX;
  final rightShoulderX = 0.58 + leanX;
  final leftHipX = 0.45;
  final rightHipX = 0.55;

  // -- Arm positions derived from angles --
  // Left arm: shoulder is anchor, elbow at ~0.12 distance, wrist at ~0.12 further.
  const armSegment = 0.12;
  final leftElbowX = leftShoulderX - math.sin(leftArmRad) * armSegment;
  final leftElbowY = shoulderY + math.cos(leftArmRad) * armSegment;
  final leftWristX = leftElbowX - math.sin(leftArmRad) * armSegment;
  final leftWristY = leftElbowY + math.cos(leftArmRad) * armSegment;

  final rightElbowX = rightShoulderX + math.sin(rightArmRad) * armSegment;
  final rightElbowY = shoulderY + math.cos(rightArmRad) * armSegment;
  final rightWristX = rightElbowX + math.sin(rightArmRad) * armSegment;
  final rightWristY = rightElbowY + math.cos(rightArmRad) * armSegment;

  // -- Head position follows upper body lean --
  final noseX = 0.50 + leanX * 1.2;
  const noseY = 0.18;

  // -- Leg positions (relatively stable, slight knee bend on bounce) --
  final kneeBend = bounce * 0.04;
  const leftKneeX = 0.45;
  final leftKneeY = 0.72 + kneeBend;
  const rightKneeX = 0.55;
  final rightKneeY = 0.72 + kneeBend;
  const leftAnkleX = 0.44;
  const leftAnkleY = 0.90;
  const rightAnkleX = 0.56;
  const rightAnkleY = 0.90;

  // Build all 33 landmarks in BlazePose order.
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
  set(PoseConstants.leftElbow, leftElbowX, leftElbowY);
  set(PoseConstants.rightElbow, rightElbowX, rightElbowY);
  set(PoseConstants.leftWrist, leftWristX, leftWristY);
  set(PoseConstants.rightWrist, rightWristX, rightWristY);
  set(PoseConstants.leftPinky, leftWristX - 0.01, leftWristY + 0.02);
  set(PoseConstants.rightPinky, rightWristX + 0.01, rightWristY + 0.02);
  set(PoseConstants.leftIndex, leftWristX - 0.005, leftWristY + 0.025);
  set(PoseConstants.rightIndex, rightWristX + 0.005, rightWristY + 0.025);
  set(PoseConstants.leftThumb, leftWristX + 0.01, leftWristY + 0.015);
  set(PoseConstants.rightThumb, rightWristX - 0.01, rightWristY + 0.015);

  // Hips (23-24)
  set(PoseConstants.leftHip, leftHipX, hipY);
  set(PoseConstants.rightHip, rightHipX, hipY);

  // Legs (25-32)
  set(PoseConstants.leftKnee, leftKneeX, leftKneeY);
  set(PoseConstants.rightKnee, rightKneeX, rightKneeY);
  set(PoseConstants.leftAnkle, leftAnkleX, leftAnkleY);
  set(PoseConstants.rightAnkle, rightAnkleX, rightAnkleY);
  set(PoseConstants.leftHeel, leftAnkleX - 0.01, 0.92);
  set(PoseConstants.rightHeel, rightAnkleX + 0.01, 0.92);
  set(PoseConstants.leftFootIndex, leftAnkleX + 0.02, 0.93);
  set(PoseConstants.rightFootIndex, rightAnkleX - 0.02, 0.93);

  return PoseFrame(timestamp: ts, landmarks: landmarks);
}
