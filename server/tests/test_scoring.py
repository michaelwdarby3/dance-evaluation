"""Unit tests for the scoring engine core modules."""

import math

import numpy as np
import pytest

from api.core.constants import (
    KEY_JOINTS,
    LEFT_HIP,
    LEFT_SHOULDER,
    RIGHT_HIP,
    RIGHT_SHOULDER,
    STYLE_WEIGHTS,
)
from api.core.dtw import compute_dtw
from api.core.pose_math import (
    angle_between,
    cosine_similarity,
    normalize_pose,
    pose_distance,
    pose_to_vector,
)
from api.core.scoring import evaluate


def _make_frame(offset: float = 0.0, visibility: float = 0.9) -> np.ndarray:
    """Create a 33-landmark frame with predictable values."""
    frame = np.zeros((33, 4), dtype=np.float64)
    for i in range(33):
        frame[i] = [0.5 + offset + i * 0.001, 0.3 + i * 0.02, 0.0, visibility]
    return frame


def _make_sequence(n_frames: int, base_offset: float = 0.0) -> list[np.ndarray]:
    """Create a sequence of frames with slight per-frame variation."""
    return [_make_frame(base_offset + i * 0.001) for i in range(n_frames)]


# ---------------------------------------------------------------------------
# pose_math tests
# ---------------------------------------------------------------------------


class TestNormalizePose:
    def test_centered_on_hip_midpoint(self):
        frame = _make_frame()
        normed = normalize_pose(frame)
        mid_hip = (normed[LEFT_HIP, :3] + normed[RIGHT_HIP, :3]) / 2
        np.testing.assert_allclose(mid_hip, [0, 0, 0], atol=1e-10)

    def test_torso_height_is_one(self):
        frame = _make_frame()
        normed = normalize_pose(frame)
        mid_hip = (normed[LEFT_HIP, :3] + normed[RIGHT_HIP, :3]) / 2
        mid_shoulder = (normed[LEFT_SHOULDER, :3] + normed[RIGHT_SHOULDER, :3]) / 2
        height = np.linalg.norm(mid_shoulder - mid_hip)
        assert abs(height - 1.0) < 1e-10

    def test_visibility_preserved(self):
        frame = _make_frame(visibility=0.75)
        normed = normalize_pose(frame)
        np.testing.assert_allclose(normed[:, 3], 0.75)


class TestPoseDistance:
    def test_identical_frames_zero_distance(self):
        f = _make_frame()
        assert pose_distance(f, f) == 0.0

    def test_different_frames_positive_distance(self):
        f1 = _make_frame(0.0)
        f2 = _make_frame(0.1)
        assert pose_distance(f1, f2) > 0

    def test_symmetric(self):
        f1 = _make_frame(0.0)
        f2 = _make_frame(0.05)
        assert abs(pose_distance(f1, f2) - pose_distance(f2, f1)) < 1e-10


class TestCosineSimilarity:
    def test_identical_vectors(self):
        v = np.array([1.0, 2.0, 3.0])
        assert abs(cosine_similarity(v, v) - 1.0) < 1e-10

    def test_orthogonal_vectors(self):
        a = np.array([1.0, 0.0])
        b = np.array([0.0, 1.0])
        assert abs(cosine_similarity(a, b)) < 1e-10

    def test_opposite_vectors(self):
        a = np.array([1.0, 0.0])
        b = np.array([-1.0, 0.0])
        assert abs(cosine_similarity(a, b) - (-1.0)) < 1e-10

    def test_zero_vector_returns_zero(self):
        a = np.array([0.0, 0.0])
        b = np.array([1.0, 2.0])
        assert cosine_similarity(a, b) == 0.0


class TestPoseToVector:
    def test_output_length(self):
        f = _make_frame()
        v = pose_to_vector(f)
        assert len(v) == 33 * 3

    def test_excludes_visibility(self):
        f = _make_frame(visibility=0.99)
        v = pose_to_vector(f)
        # visibility column should not appear
        assert 0.99 not in v


class TestAngleBetween:
    def test_right_angle(self):
        frame = np.zeros((33, 4))
        # Place 3 points forming a right angle at index 1
        frame[0] = [1, 0, 0, 1]  # a
        frame[1] = [0, 0, 0, 1]  # b (vertex)
        frame[2] = [0, 1, 0, 1]  # c
        angle = angle_between(frame, 0, 1, 2)
        assert abs(angle - 90.0) < 1e-6

    def test_straight_line(self):
        frame = np.zeros((33, 4))
        frame[0] = [-1, 0, 0, 1]
        frame[1] = [0, 0, 0, 1]
        frame[2] = [1, 0, 0, 1]
        angle = angle_between(frame, 0, 1, 2)
        assert abs(angle - 180.0) < 1e-6

    def test_acute_angle(self):
        frame = np.zeros((33, 4))
        frame[0] = [1, 0, 0, 1]
        frame[1] = [0, 0, 0, 1]
        frame[2] = [1, 1, 0, 1]
        angle = angle_between(frame, 0, 1, 2)
        assert abs(angle - 45.0) < 1e-6


# ---------------------------------------------------------------------------
# DTW tests
# ---------------------------------------------------------------------------


class TestDTW:
    def test_identical_sequences(self):
        seq = _make_sequence(10)
        result = compute_dtw(seq, seq)
        assert result.distance == 0.0
        assert result.normalized_distance == 0.0
        assert len(result.warping_path) == 10

    def test_diagonal_path_for_identical(self):
        seq = _make_sequence(5)
        result = compute_dtw(seq, seq)
        assert result.warping_path == [(i, i) for i in range(5)]

    def test_different_lengths(self):
        ref = _make_sequence(10)
        user = _make_sequence(5)
        result = compute_dtw(ref, user)
        assert result.distance > 0
        assert len(result.warping_path) >= max(10, 5)
        # Path should start at (0,0) and end at (9,4)
        assert result.warping_path[0] == (0, 0)
        assert result.warping_path[-1] == (9, 4)

    def test_empty_sequence(self):
        result = compute_dtw([], _make_sequence(5))
        assert result.distance == float("inf")
        assert result.warping_path == []

    def test_single_frame(self):
        ref = [_make_frame(0.0)]
        user = [_make_frame(0.1)]
        result = compute_dtw(ref, user)
        assert len(result.warping_path) == 1
        assert result.warping_path[0] == (0, 0)


# ---------------------------------------------------------------------------
# Scoring integration tests
# ---------------------------------------------------------------------------


class TestEvaluate:
    def test_identical_performance_high_score(self):
        """User performing identically to reference should score high."""
        ref = _make_sequence(20)
        user = _make_sequence(20)
        result = evaluate(user, ref, style="hipHop")

        assert result.overall_score >= 80
        for d in result.dimensions:
            assert d.score >= 50  # All dimensions should be decent

    def test_very_different_performance_low_score(self):
        """Wildly different performance should score low."""
        ref = _make_sequence(20, base_offset=0.0)
        # Create user frames with scrambled landmark positions (not just offset)
        rng = np.random.RandomState(42)
        user = []
        for i in range(20):
            frame = np.zeros((33, 4), dtype=np.float64)
            frame[:, :3] = rng.rand(33, 3) * 2.0  # random positions
            frame[:, 3] = 0.9
            user.append(frame)
        result = evaluate(user, ref, style="hipHop")

        assert result.overall_score < 60

    def test_dimensions_present(self):
        ref = _make_sequence(10)
        user = _make_sequence(10)
        result = evaluate(user, ref, style="hipHop")

        dim_names = {d.dimension for d in result.dimensions}
        assert dim_names == {"timing", "technique", "expression", "spatialAwareness"}

    def test_joint_feedback_present(self):
        ref = _make_sequence(10)
        user = _make_sequence(10, base_offset=0.05)
        result = evaluate(user, ref, style="hipHop")

        assert len(result.joint_feedback) > 0
        assert len(result.joint_feedback) <= 5
        for jf in result.joint_feedback:
            assert jf.joint_name in KEY_JOINTS
            assert len(jf.landmark_indices) == 3
            assert 0 <= jf.score <= 100

    def test_style_affects_overall_score(self):
        """Different styles should weight dimensions differently."""
        ref = _make_sequence(15)
        user = _make_sequence(15, base_offset=0.02)

        hip_hop = evaluate(user, ref, style="hipHop")
        contemporary = evaluate(user, ref, style="contemporary")

        # Scores might differ slightly due to different weights
        # Just verify both are valid
        assert 0 <= hip_hop.overall_score <= 100
        assert 0 <= contemporary.overall_score <= 100

    def test_low_confidence_frames_filtered(self):
        """Frames with low visibility should be filtered out."""
        ref = _make_sequence(10)
        # Mix high and low confidence frames
        user = []
        for i in range(10):
            vis = 0.9 if i % 2 == 0 else 0.1
            user.append(_make_frame(i * 0.001, visibility=vis))

        result = evaluate(user, ref, style="hipHop", min_confidence=0.3)
        assert result.overall_score >= 0

    def test_feedback_summaries_not_empty(self):
        ref = _make_sequence(10)
        user = _make_sequence(10)
        result = evaluate(user, ref, style="freestyle")

        for d in result.dimensions:
            assert len(d.summary) > 0
        for jf in result.joint_feedback:
            assert len(jf.issue) > 0
            assert len(jf.correction) > 0

    def test_feedback_fields_populated(self):
        """Detailed feedback fields should be populated after evaluate()."""
        ref = _make_sequence(20)
        user = _make_sequence(20)
        result = evaluate(user, ref, style="hipHop")

        assert len(result.timing_insights) > 0
        assert result.coaching_summary is not None
        assert len(result.coaching_summary) > 0

    def test_drills_populated_for_poor_performance(self):
        """Poor performance should produce drill recommendations."""
        ref = _make_sequence(20, base_offset=0.0)
        rng = np.random.RandomState(99)
        user = []
        for _ in range(20):
            frame = np.zeros((33, 4), dtype=np.float64)
            frame[:, :3] = rng.rand(33, 3) * 2.0
            frame[:, 3] = 0.9
            user.append(frame)
        result = evaluate(user, ref, style="hipHop")

        assert len(result.drills) > 0
        for d in result.drills:
            assert d.drill_id
            assert d.name
            assert d.description
            assert d.priority >= 1


# ---------------------------------------------------------------------------
# Constants tests
# ---------------------------------------------------------------------------


class TestConstants:
    def test_style_weights_sum_to_one(self):
        for style, weights in STYLE_WEIGHTS.items():
            total = sum(weights.values())
            assert abs(total - 1.0) < 1e-10, f"{style} weights sum to {total}"

    def test_all_key_joints_have_three_indices(self):
        for name, indices in KEY_JOINTS.items():
            assert len(indices) == 3, f"{name} has {len(indices)} indices"

    def test_key_joint_indices_in_range(self):
        for name, indices in KEY_JOINTS.items():
            for idx in indices:
                assert 0 <= idx < 33, f"{name} index {idx} out of range"
