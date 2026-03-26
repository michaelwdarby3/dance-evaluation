import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';

/// Static catalog of drill recommendations mapped to joint + dimension + score range.
class DrillCatalog {
  DrillCatalog._();

  static const _drills = <_DrillEntry>[
    // Timing drills
    _DrillEntry(
      drillId: 'timing_clap',
      name: 'Beat Clap Drill',
      description: 'Clap along to the beat of a song, then add simple steps on each beat.',
      targetJoint: 'general',
      targetDimension: EvalDimension.timing,
      maxScore: 60,
    ),
    _DrillEntry(
      drillId: 'timing_metronome',
      name: 'Metronome Step Practice',
      description: 'Step left-right to a metronome at 80 BPM, gradually increasing to match the reference tempo.',
      targetJoint: 'general',
      targetDimension: EvalDimension.timing,
      maxScore: 40,
    ),
    _DrillEntry(
      drillId: 'timing_slow_mirror',
      name: 'Slow-Motion Mirror',
      description: 'Play the reference at 0.5x speed and follow along, focusing on hitting each beat precisely.',
      targetJoint: 'general',
      targetDimension: EvalDimension.timing,
      maxScore: 80,
    ),

    // Technique — upper body
    _DrillEntry(
      drillId: 'tech_shoulder_iso',
      name: 'Shoulder Isolation Drill',
      description: 'Alternate lifting each shoulder independently, 8 counts per side.',
      targetJoint: 'leftShoulder',
      targetDimension: EvalDimension.technique,
      maxScore: 70,
    ),
    _DrillEntry(
      drillId: 'tech_arm_circles',
      name: 'Arm Extension Circles',
      description: 'Full arm circles with straight elbows, focusing on range of motion.',
      targetJoint: 'leftElbow',
      targetDimension: EvalDimension.technique,
      maxScore: 70,
    ),
    _DrillEntry(
      drillId: 'tech_elbow_control',
      name: 'Elbow Angle Control',
      description: 'Practice holding arm positions at 45, 90, and 135 degrees, checking in a mirror.',
      targetJoint: 'rightElbow',
      targetDimension: EvalDimension.technique,
      maxScore: 60,
    ),
    _DrillEntry(
      drillId: 'tech_wrist_pop',
      name: 'Wrist Pop Drill',
      description: 'Snap wrists to sharp angles on each beat — builds hand precision.',
      targetJoint: 'leftWrist',
      targetDimension: EvalDimension.technique,
      maxScore: 70,
    ),

    // Technique — lower body
    _DrillEntry(
      drillId: 'tech_knee_bounce',
      name: 'Knee Bounce Drill',
      description: 'Small rhythmic knee bends in place, keeping core engaged and back straight.',
      targetJoint: 'leftKnee',
      targetDimension: EvalDimension.technique,
      maxScore: 70,
    ),
    _DrillEntry(
      drillId: 'tech_hip_square',
      name: 'Hip Square Isolation',
      description: 'Move hips in a square pattern (front-right-back-left), keeping shoulders still.',
      targetJoint: 'leftHip',
      targetDimension: EvalDimension.technique,
      maxScore: 60,
    ),
    _DrillEntry(
      drillId: 'tech_ankle_flex',
      name: 'Ankle Flex & Point',
      description: 'Seated ankle flexion-extension to improve foot articulation in transitions.',
      targetJoint: 'leftAnkle',
      targetDimension: EvalDimension.technique,
      maxScore: 70,
    ),

    // Expression drills
    _DrillEntry(
      drillId: 'expr_dynamics',
      name: 'Dynamic Range Exercise',
      description: 'Alternate between big, exaggerated movements and tight, controlled ones every 4 counts.',
      targetJoint: 'general',
      targetDimension: EvalDimension.expression,
      maxScore: 60,
    ),
    _DrillEntry(
      drillId: 'expr_energy_levels',
      name: 'Energy Level Scale',
      description: 'Dance the same 8-count at energy levels 1-5, learning to modulate intensity.',
      targetJoint: 'general',
      targetDimension: EvalDimension.expression,
      maxScore: 80,
    ),
    _DrillEntry(
      drillId: 'expr_freeze_hit',
      name: 'Freeze & Hit Drill',
      description: 'Alternate between sharp freeze poses and explosive movement bursts.',
      targetJoint: 'general',
      targetDimension: EvalDimension.expression,
      maxScore: 50,
    ),

    // Spatial awareness drills
    _DrillEntry(
      drillId: 'spatial_box',
      name: 'Box Step Drill',
      description: 'Step in a precise 2x2 box pattern, focusing on consistent step size.',
      targetJoint: 'general',
      targetDimension: EvalDimension.spatialAwareness,
      maxScore: 60,
    ),
    _DrillEntry(
      drillId: 'spatial_mirror_match',
      name: 'Mirror Match Practice',
      description: 'Stand in front of a mirror and match exact arm/leg positions from reference screenshots.',
      targetJoint: 'general',
      targetDimension: EvalDimension.spatialAwareness,
      maxScore: 70,
    ),
    _DrillEntry(
      drillId: 'spatial_level_changes',
      name: 'Level Change Drill',
      description: 'Practice smooth transitions between standing, crouching, and floor positions.',
      targetJoint: 'general',
      targetDimension: EvalDimension.spatialAwareness,
      maxScore: 50,
    ),
  ];

  /// Recommends drills based on dimension scores and joint feedback.
  static List<DrillRecommendation> recommend({
    required List<DimensionScore> dimensions,
    required List<JointFeedback> jointFeedback,
  }) {
    final recommendations = <DrillRecommendation>[];
    var priority = 1;

    // Find weak dimensions (score < 70).
    final weakDimensions = dimensions
        .where((d) => d.score < 70)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    // Find weak joints.
    final weakJoints = jointFeedback
        .where((j) => j.score < 70)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    // Match joint-specific drills first.
    for (final joint in weakJoints.take(3)) {
      for (final entry in _drills) {
        if (entry.targetDimension == EvalDimension.technique &&
            _jointMatches(entry.targetJoint, joint.jointName) &&
            joint.score <= entry.maxScore) {
          // Avoid duplicates (e.g. leftElbow and rightElbow matching the same drill).
          if (recommendations.any((r) => r.drillId == entry.drillId)) continue;
          recommendations.add(DrillRecommendation(
            drillId: entry.drillId,
            name: entry.name,
            description: entry.description,
            targetJoint: joint.jointName,
            targetDimension: entry.targetDimension,
            priority: priority++,
          ));
          break;
        }
      }
    }

    // Add dimension-level drills.
    for (final dim in weakDimensions) {
      if (dim.dimension == EvalDimension.technique) continue; // Covered above.
      for (final entry in _drills) {
        if (entry.targetDimension == dim.dimension &&
            dim.score <= entry.maxScore) {
          // Avoid duplicates.
          if (recommendations.any((r) => r.drillId == entry.drillId)) continue;
          recommendations.add(DrillRecommendation(
            drillId: entry.drillId,
            name: entry.name,
            description: entry.description,
            targetJoint: entry.targetJoint,
            targetDimension: entry.targetDimension,
            priority: priority++,
          ));
          break;
        }
      }
    }

    return recommendations.take(5).toList();
  }

  /// Check if a drill's target joint matches the feedback joint.
  /// "general" matches everything; "left*" matches both left and right variants.
  static bool _jointMatches(String drillJoint, String feedbackJoint) {
    if (drillJoint == 'general') return true;
    // Normalize by stripping left/right prefix.
    final drillBase = drillJoint
        .replaceFirst('left', '')
        .replaceFirst('right', '')
        .toLowerCase();
    final feedbackBase = feedbackJoint
        .replaceFirst('left', '')
        .replaceFirst('right', '')
        .toLowerCase();
    return drillBase == feedbackBase;
  }
}

class _DrillEntry {
  const _DrillEntry({
    required this.drillId,
    required this.name,
    required this.description,
    required this.targetJoint,
    required this.targetDimension,
    required this.maxScore,
  });

  final String drillId;
  final String name;
  final String description;
  final String targetJoint;
  final EvalDimension targetDimension;
  /// Drill is recommended when the score is at or below this threshold.
  final double maxScore;
}
