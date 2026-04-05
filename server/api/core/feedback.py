"""Rich, time-localized feedback from DTW alignment data.

Ported from lib/features/evaluation/domain/feedback_generator.dart.
"""

import re
from dataclasses import dataclass, field

import numpy as np

from .constants import KEY_JOINTS
from .pose_math import angle_between


@dataclass
class DetailedFeedback:
    timing_insights: list[str]
    joint_insights: list[str]
    coaching_summary: str


_SEGMENTS = 4
_SEGMENT_NAMES = ["first quarter", "second quarter", "third quarter", "final quarter"]


def generate_feedback(
    ref_frames: list[np.ndarray],
    user_frames: list[np.ndarray],
    path: list[tuple[int, int]],
    overall_score: float,
    dimension_scores: dict[str, float],
) -> DetailedFeedback:
    timing_insights = _analyze_timing_segments(path, len(ref_frames), len(user_frames))
    joint_insights = _analyze_joint_segments(ref_frames, user_frames, path)
    coaching_summary = _generate_coaching_summary(
        overall_score, dimension_scores, timing_insights
    )
    return DetailedFeedback(
        timing_insights=timing_insights,
        joint_insights=joint_insights,
        coaching_summary=coaching_summary,
    )


def _analyze_timing_segments(
    path: list[tuple[int, int]], ref_len: int, user_len: int
) -> list[str]:
    if not path or ref_len <= 1:
        return []

    insights: list[str] = []
    segment_size = max(1, min(-(-len(path) // _SEGMENTS), len(path)))  # ceil division
    ideal_slope = (user_len - 1) / (ref_len - 1)

    for seg in range(_SEGMENTS):
        start = seg * segment_size
        end = min(start + segment_size, len(path))
        if start >= len(path):
            break

        segment_path = path[start:end]

        avg_slope = 0.0
        slope_count = 0
        for i in range(1, len(segment_path)):
            d_ref = segment_path[i][0] - segment_path[i - 1][0]
            d_user = segment_path[i][1] - segment_path[i - 1][1]
            if d_ref > 0:
                avg_slope += d_user / d_ref
                slope_count += 1

        if slope_count == 0:
            continue
        avg_slope /= slope_count

        slope_ratio = avg_slope / ideal_slope if ideal_slope > 0 else 1.0
        name = _SEGMENT_NAMES[seg]

        if slope_ratio > 1.3:
            insights.append(f"You rushed through the {name} of the routine.")
        elif slope_ratio < 0.7:
            insights.append(f"You fell behind during the {name} of the routine.")
        elif slope_ratio > 1.1:
            insights.append(f"You were slightly ahead of the beat in the {name}.")
        elif slope_ratio < 0.9:
            insights.append(f"You were slightly behind the beat in the {name}.")

    if not insights:
        insights.append("Your timing was consistent throughout the routine.")

    return insights


def _analyze_joint_segments(
    ref: list[np.ndarray],
    user: list[np.ndarray],
    path: list[tuple[int, int]],
) -> list[str]:
    if not path:
        return []

    insights: list[str] = []
    segment_size = max(1, min(-(-len(path) // _SEGMENTS), len(path)))

    for joint_name, indices in KEY_JOINTS.items():
        readable = _readable_joint_name(joint_name)

        worst_segment = -1
        worst_avg_diff = 0.0
        worst_direction = 0.0

        for seg in range(_SEGMENTS):
            start = seg * segment_size
            end = min(start + segment_size, len(path))
            if start >= len(path):
                break

            total_diff = 0.0
            total_signed = 0.0
            count = 0

            for i in range(start, end):
                ri, ui = path[i]
                ref_angle = angle_between(ref[ri], indices[0], indices[1], indices[2])
                user_angle = angle_between(user[ui], indices[0], indices[1], indices[2])
                total_diff += abs(ref_angle - user_angle)
                total_signed += user_angle - ref_angle
                count += 1

            if count == 0:
                continue
            avg_diff = total_diff / count

            if avg_diff > worst_avg_diff:
                worst_avg_diff = avg_diff
                worst_segment = seg
                worst_direction = total_signed / count

        if worst_avg_diff < 15 or worst_segment < 0:
            continue

        seg_name = _SEGMENT_NAMES[worst_segment]
        direction = _direction_phrase(joint_name, worst_direction)

        if worst_avg_diff >= 30:
            insights.append(
                f"Your {readable} was significantly {direction} during the {seg_name}."
            )
        else:
            insights.append(
                f"Your {readable} was slightly {direction} in the {seg_name}."
            )

    return insights[:5]


def _direction_phrase(joint_name: str, signed_diff: float) -> str:
    if "Elbow" in joint_name or "Knee" in joint_name:
        return "too extended" if signed_diff > 0 else "too bent"
    if "Shoulder" in joint_name:
        return "raised too high" if signed_diff > 0 else "too low"
    if "Hip" in joint_name:
        return "too open" if signed_diff > 0 else "too closed"
    if "Ankle" in joint_name:
        return "too flexed" if signed_diff > 0 else "too pointed"
    return "over-extended" if signed_diff > 0 else "under-extended"


def _generate_coaching_summary(
    overall_score: float,
    dimension_scores: dict[str, float],
    timing_insights: list[str],
) -> str:
    parts: list[str] = []

    # Opening line
    if overall_score >= 85:
        parts.append("Excellent performance!")
    elif overall_score >= 70:
        parts.append("Good work overall.")
    elif overall_score >= 50:
        parts.append("Decent effort with clear areas to improve.")
    else:
        parts.append("Keep practicing \u2014 every session builds muscle memory.")

    # Weakest dimension
    if dimension_scores:
        weakest_dim = min(dimension_scores, key=dimension_scores.get)  # type: ignore[arg-type]
        coaching = {
            "timing": "Focus on your timing \u2014 try practicing with the metronome.",
            "technique": (
                "Your biggest opportunity is technique \u2014 "
                "slow down and nail the shapes before adding speed."
            ),
            "expression": (
                "Work on your dynamics \u2014 "
                "exaggerate movements to match the energy of the reference."
            ),
            "spatialAwareness": (
                "Pay attention to your positioning \u2014 "
                "watch the reference ghost overlay to guide your placement."
            ),
        }
        parts.append(coaching.get(weakest_dim, ""))

    # Pacing advice
    has_rush = any("rushed" in t for t in timing_insights)
    has_fell_behind = any("fell behind" in t for t in timing_insights)

    if has_rush and has_fell_behind:
        parts.append("Your pacing was inconsistent \u2014 try to stay steady throughout.")
    elif has_rush:
        parts.append("In particular, slow down in the sections where you rushed.")
    elif has_fell_behind:
        parts.append("Try to keep up in the sections where you fell behind.")

    return " ".join(parts)


def _readable_joint_name(joint: str) -> str:
    return re.sub(r"([a-z])([A-Z])", r"\1 \2", joint).lower()
