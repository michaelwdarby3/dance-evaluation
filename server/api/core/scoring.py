"""Evaluation scoring engine — 4 dimension scores, joint analysis, feedback.

Ported from lib/features/evaluation/domain/evaluation_service.dart.
"""

import math
import time
from dataclasses import dataclass, field

import numpy as np

from .constants import KEY_JOINTS, STYLE_WEIGHTS
from .dtw import DtwResult, compute_dtw
from .pose_math import (
    angle_between,
    cosine_similarity,
    normalize_pose,
    pose_distance,
    pose_to_vector,
)


@dataclass
class DimensionScore:
    dimension: str
    score: float
    summary: str


@dataclass
class JointFeedbackItem:
    joint_name: str
    landmark_indices: list[int]
    score: float
    issue: str
    correction: str


@dataclass
class EvaluationResult:
    id: str
    overall_score: float
    dimensions: list[DimensionScore]
    joint_feedback: list[JointFeedbackItem]
    created_at: str
    style: str
    timing_insights: list[str] = field(default_factory=list)
    joint_insights: list[str] = field(default_factory=list)
    coaching_summary: str | None = None
    drills: list = field(default_factory=list)


# Maximum DTW distance that maps to a score of 0.
_MAX_DISTANCE = 50.0


def evaluate(
    user_frames: list[np.ndarray],
    ref_frames: list[np.ndarray],
    style: str,
    min_confidence: float = 0.3,
) -> EvaluationResult:
    """Run the full evaluation pipeline.

    Args:
        user_frames: List of (33, 4) arrays from user performance.
        ref_frames: List of (33, 4) arrays from reference choreography.
        style: Dance style key (e.g. "hipHop", "kPop").
        min_confidence: Drop user frames below this avg visibility.

    Returns:
        EvaluationResult with scores and feedback.
    """
    # Normalize
    ref_norm = [normalize_pose(f) for f in ref_frames]
    user_filtered = _filter_by_confidence(user_frames, min_confidence)
    user_norm = [normalize_pose(f) for f in user_filtered]

    # DTW
    dtw_result = compute_dtw(ref_norm, user_norm)
    path = dtw_result.warping_path

    # Score dimensions
    timing = _score_timing(path, len(ref_norm), len(user_norm))
    technique = _score_technique(ref_norm, user_norm, path)
    expression = _score_expression(ref_norm, user_norm)
    spatial = _score_spatial(dtw_result.normalized_distance)

    # Weighted overall
    weights = STYLE_WEIGHTS.get(style, STYLE_WEIGHTS["freestyle"])
    dim_scores = {
        "timing": timing,
        "technique": technique,
        "expression": expression,
        "spatialAwareness": spatial,
    }
    overall = sum(weights.get(d, 0) * dim_scores[d] for d in dim_scores)
    overall = max(0.0, min(100.0, overall))

    # Joint analysis
    joint_feedback = _analyze_joints(ref_norm, user_norm, path)

    # Detailed feedback and drill recommendations
    from .feedback import generate_feedback
    from .drills import recommend_drills

    dim_scores_dict = {
        "timing": round(timing, 2),
        "technique": round(technique, 2),
        "expression": round(expression, 2),
        "spatialAwareness": round(spatial, 2),
    }

    feedback = generate_feedback(
        ref_norm, user_norm, path, round(overall, 2), dim_scores_dict
    )

    drills = recommend_drills(
        dim_scores_dict,
        [{"joint_name": jf.joint_name, "score": jf.score} for jf in joint_feedback],
    )

    eval_id = hex(int(time.time() * 1_000_000))[2:]

    return EvaluationResult(
        id=eval_id,
        overall_score=round(overall, 2),
        dimensions=[
            DimensionScore("timing", round(timing, 2), _timing_summary(timing)),
            DimensionScore("technique", round(technique, 2), _technique_summary(technique)),
            DimensionScore("expression", round(expression, 2), _expression_summary(expression)),
            DimensionScore("spatialAwareness", round(spatial, 2), _spatial_summary(spatial)),
        ],
        joint_feedback=joint_feedback,
        created_at=time.strftime("%Y-%m-%dT%H:%M:%S"),
        style=style,
        timing_insights=feedback.timing_insights,
        joint_insights=feedback.joint_insights,
        coaching_summary=feedback.coaching_summary,
        drills=drills,
    )


# ---------------------------------------------------------------------------
# Confidence filtering
# ---------------------------------------------------------------------------


def _filter_by_confidence(
    frames: list[np.ndarray], threshold: float
) -> list[np.ndarray]:
    if threshold <= 0:
        return frames
    filtered = [
        f for f in frames if f.shape[0] > 0 and float(np.mean(f[:, 3])) >= threshold
    ]
    return filtered if filtered else frames


# ---------------------------------------------------------------------------
# Dimension scoring
# ---------------------------------------------------------------------------


def _score_timing(
    path: list[tuple[int, int]], ref_len: int, user_len: int
) -> float:
    """How close the warping path is to a straight diagonal."""
    if not path:
        return 0.0

    ideal_slope = (user_len - 1) / (ref_len - 1) if ref_len > 1 else 1.0
    total_deviation = sum(abs(ui - ri * ideal_slope) for ri, ui in path)
    avg_deviation = total_deviation / len(path)
    max_dev = max(ref_len / 2, 1)
    return max(0.0, min(100.0, (1 - avg_deviation / max_dev) * 100))


def _score_technique(
    ref: list[np.ndarray],
    user: list[np.ndarray],
    path: list[tuple[int, int]],
) -> float:
    """Average cosine similarity of aligned poses."""
    if not path:
        return 0.0

    total_sim = 0.0
    for ri, ui in path:
        ref_vec = pose_to_vector(ref[ri])
        user_vec = pose_to_vector(user[ui])
        total_sim += cosine_similarity(ref_vec, user_vec)

    avg_sim = total_sim / len(path)
    # Map [0.5, 1.0] -> [0, 100]
    return max(0.0, min(100.0, (avg_sim - 0.5) * 200))


def _score_expression(
    ref: list[np.ndarray], user: list[np.ndarray]
) -> float:
    """Similarity of movement dynamics (velocity variance)."""
    ref_vel = _compute_velocities(ref)
    user_vel = _compute_velocities(user)

    if not ref_vel or not user_vel:
        return 50.0

    ref_var = _variance(ref_vel)
    user_var = _variance(user_vel)

    if ref_var == 0 and user_var == 0:
        return 100.0
    if ref_var == 0 or user_var == 0:
        return 20.0

    ratio = min(ref_var, user_var) / max(ref_var, user_var)
    return max(0.0, min(100.0, ratio * 100))


def _score_spatial(normalized_distance: float) -> float:
    """Based on normalized DTW distance."""
    return max(0.0, min(100.0, (1 - normalized_distance / _MAX_DISTANCE) * 100))


# ---------------------------------------------------------------------------
# Joint analysis
# ---------------------------------------------------------------------------


def _analyze_joints(
    ref: list[np.ndarray],
    user: list[np.ndarray],
    path: list[tuple[int, int]],
) -> list[JointFeedbackItem]:
    if not path:
        return []

    joint_scores: dict[str, float] = {}

    for joint_name, indices in KEY_JOINTS.items():
        total_diff = 0.0
        for ri, ui in path:
            ref_angle = angle_between(ref[ri], indices[0], indices[1], indices[2])
            user_angle = angle_between(user[ui], indices[0], indices[1], indices[2])
            total_diff += abs(ref_angle - user_angle)

        avg_diff = total_diff / len(path)
        joint_scores[joint_name] = max(0.0, min(100.0, (1 - avg_diff / 45) * 100))

    # Sort worst first, take top 5
    sorted_joints = sorted(joint_scores.items(), key=lambda x: x[1])
    worst = sorted_joints[:5]

    return [
        JointFeedbackItem(
            joint_name=name,
            landmark_indices=KEY_JOINTS[name],
            score=round(score, 2),
            issue=_joint_issue(name, score),
            correction=_joint_correction(name, score),
        )
        for name, score in worst
    ]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _compute_velocities(frames: list[np.ndarray]) -> list[float]:
    """Frame-to-frame pose distance (proxy for velocity)."""
    velocities = []
    for i in range(1, len(frames)):
        dist = pose_distance(frames[i], frames[i - 1])
        velocities.append(dist)
    return velocities


def _variance(values: list[float]) -> float:
    if not values:
        return 0.0
    mean = sum(values) / len(values)
    return sum((v - mean) ** 2 for v in values) / len(values)


# ---------------------------------------------------------------------------
# Feedback text templates
# ---------------------------------------------------------------------------


def _timing_summary(score: float) -> str:
    if score >= 80:
        return "Great rhythm! You stayed on beat consistently."
    if score >= 60:
        return "Decent timing, but you drifted off beat in places."
    if score >= 40:
        return "Timing needs work. Try counting beats out loud."
    return "Significant timing issues. Practice with a metronome first."


def _technique_summary(score: float) -> str:
    if score >= 80:
        return "Excellent form! Your poses closely match the reference."
    if score >= 60:
        return "Good technique overall with room for improvement."
    if score >= 40:
        return "Several poses were off. Focus on the joint feedback below."
    return "Technique needs significant improvement. Start with basic drills."


def _expression_summary(score: float) -> str:
    if score >= 80:
        return "Great dynamics! Your energy matches the choreography."
    if score >= 60:
        return "Good energy, but some moves lack punch or fluidity."
    if score >= 40:
        return "Movement feels flat. Try exaggerating your motions."
    return "Movement dynamics are very different from the reference."


def _spatial_summary(score: float) -> str:
    if score >= 80:
        return "Excellent spatial accuracy and movement range."
    if score >= 60:
        return "Mostly in the right positions with minor drift."
    if score >= 40:
        return "Positions are off in several sections. Watch the reference again."
    return "Large spatial deviations. Focus on where your body should be."


def _readable_joint_name(joint: str) -> str:
    """Convert camelCase to readable: 'leftElbow' -> 'left elbow'."""
    import re

    return re.sub(r"([a-z])([A-Z])", r"\1 \2", joint).lower()


def _joint_issue(joint: str, score: float) -> str:
    name = _readable_joint_name(joint)
    if score >= 70:
        return f"Your {name} movement is mostly accurate."
    if score >= 40:
        return f"Your {name} angle deviates from the reference."
    return f"Your {name} position is significantly off."


def _joint_correction(joint: str, score: float) -> str:
    name = _readable_joint_name(joint)
    if score >= 70:
        return f"Minor adjustments: watch the reference closely for {name}."
    if score >= 40:
        return f"Practice isolating your {name} movement separately."
    return f"Start with slow-motion drills focusing on {name} positioning."
