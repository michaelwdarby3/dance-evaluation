"""Drill recommendation catalog and matching algorithm.

Ported from lib/features/evaluation/domain/drill_catalog.dart.
"""

from dataclasses import dataclass


@dataclass
class DrillEntry:
    drill_id: str
    name: str
    description: str
    target_joint: str
    target_dimension: str
    max_score: float


@dataclass
class DrillRecommendation:
    drill_id: str
    name: str
    description: str
    target_joint: str
    target_dimension: str
    priority: int


_DRILLS: list[DrillEntry] = [
    # Timing drills
    DrillEntry("timing_clap", "Beat Clap Drill",
               "Clap along to the beat of a song, then add simple steps on each beat.",
               "general", "timing", 60),
    DrillEntry("timing_metronome", "Metronome Step Practice",
               "Step left-right to a metronome at 80 BPM, gradually increasing to match the reference tempo.",
               "general", "timing", 40),
    DrillEntry("timing_slow_mirror", "Slow-Motion Mirror",
               "Play the reference at 0.5x speed and follow along, focusing on hitting each beat precisely.",
               "general", "timing", 80),
    # Technique — upper body
    DrillEntry("tech_shoulder_iso", "Shoulder Isolation Drill",
               "Alternate lifting each shoulder independently, 8 counts per side.",
               "leftShoulder", "technique", 70),
    DrillEntry("tech_arm_circles", "Arm Extension Circles",
               "Full arm circles with straight elbows, focusing on range of motion.",
               "leftElbow", "technique", 70),
    DrillEntry("tech_elbow_control", "Elbow Angle Control",
               "Practice holding arm positions at 45, 90, and 135 degrees, checking in a mirror.",
               "rightElbow", "technique", 60),
    DrillEntry("tech_wrist_pop", "Wrist Pop Drill",
               "Snap wrists to sharp angles on each beat \u2014 builds hand precision.",
               "leftWrist", "technique", 70),
    # Technique — lower body
    DrillEntry("tech_knee_bounce", "Knee Bounce Drill",
               "Small rhythmic knee bends in place, keeping core engaged and back straight.",
               "leftKnee", "technique", 70),
    DrillEntry("tech_hip_square", "Hip Square Isolation",
               "Move hips in a square pattern (front-right-back-left), keeping shoulders still.",
               "leftHip", "technique", 60),
    DrillEntry("tech_ankle_flex", "Ankle Flex & Point",
               "Seated ankle flexion-extension to improve foot articulation in transitions.",
               "leftAnkle", "technique", 70),
    # Expression drills
    DrillEntry("expr_dynamics", "Dynamic Range Exercise",
               "Alternate between big, exaggerated movements and tight, controlled ones every 4 counts.",
               "general", "expression", 60),
    DrillEntry("expr_energy_levels", "Energy Level Scale",
               "Dance the same 8-count at energy levels 1-5, learning to modulate intensity.",
               "general", "expression", 80),
    DrillEntry("expr_freeze_hit", "Freeze & Hit Drill",
               "Alternate between sharp freeze poses and explosive movement bursts.",
               "general", "expression", 50),
    # Spatial awareness drills
    DrillEntry("spatial_box", "Box Step Drill",
               "Step in a precise 2x2 box pattern, focusing on consistent step size.",
               "general", "spatialAwareness", 60),
    DrillEntry("spatial_mirror_match", "Mirror Match Practice",
               "Stand in front of a mirror and match exact arm/leg positions from reference screenshots.",
               "general", "spatialAwareness", 70),
    DrillEntry("spatial_level_changes", "Level Change Drill",
               "Practice smooth transitions between standing, crouching, and floor positions.",
               "general", "spatialAwareness", 50),
]


def recommend_drills(
    dimension_scores: dict[str, float],
    joint_feedback: list[dict],
) -> list[DrillRecommendation]:
    """Recommend up to 5 drills based on weak dimensions and joints.

    Args:
        dimension_scores: {"timing": 72.5, "technique": 45.0, ...}
        joint_feedback: [{"joint_name": "leftElbow", "score": 38.0}, ...]
    """
    recommendations: list[DrillRecommendation] = []
    priority = 1
    seen_ids: set[str] = set()

    # Weak dimensions and joints (score < 70), sorted worst-first.
    weak_dims = sorted(
        [(d, s) for d, s in dimension_scores.items() if s < 70],
        key=lambda x: x[1],
    )
    weak_joints = sorted(
        [j for j in joint_feedback if j["score"] < 70],
        key=lambda j: j["score"],
    )

    # Phase 1: top 3 weak joints -> match technique drills.
    for joint in weak_joints[:3]:
        for entry in _DRILLS:
            if (
                entry.target_dimension == "technique"
                and _joint_matches(entry.target_joint, joint["joint_name"])
                and joint["score"] <= entry.max_score
                and entry.drill_id not in seen_ids
            ):
                seen_ids.add(entry.drill_id)
                recommendations.append(DrillRecommendation(
                    drill_id=entry.drill_id,
                    name=entry.name,
                    description=entry.description,
                    target_joint=joint["joint_name"],
                    target_dimension=entry.target_dimension,
                    priority=priority,
                ))
                priority += 1
                break

    # Phase 2: weak non-technique dimensions -> match dimension drills.
    for dim, score in weak_dims:
        if dim == "technique":
            continue
        for entry in _DRILLS:
            if (
                entry.target_dimension == dim
                and score <= entry.max_score
                and entry.drill_id not in seen_ids
            ):
                seen_ids.add(entry.drill_id)
                recommendations.append(DrillRecommendation(
                    drill_id=entry.drill_id,
                    name=entry.name,
                    description=entry.description,
                    target_joint=entry.target_joint,
                    target_dimension=entry.target_dimension,
                    priority=priority,
                ))
                priority += 1
                break

    return recommendations[:5]


def _joint_matches(drill_joint: str, feedback_joint: str) -> bool:
    if drill_joint == "general":
        return True
    drill_base = drill_joint.replace("left", "").replace("right", "").lower()
    feedback_base = feedback_joint.replace("left", "").replace("right", "").lower()
    return drill_base == feedback_base
