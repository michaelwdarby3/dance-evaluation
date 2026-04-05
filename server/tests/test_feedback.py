"""Tests for the feedback generator."""

import numpy as np

from api.core.feedback import generate_feedback


def _make_frame(offset: float = 0.0) -> np.ndarray:
    frame = np.zeros((33, 4), dtype=np.float64)
    for i in range(33):
        frame[i] = [0.5 + offset + i * 0.001, 0.3 + i * 0.02, 0.0, 0.9]
    return frame


def _make_sequence(n: int, base: float = 0.0) -> list[np.ndarray]:
    return [_make_frame(base + i * 0.001) for i in range(n)]


def test_consistent_timing_diagonal_path():
    """A diagonal warping path should produce 'consistent' timing insight."""
    ref = _make_sequence(20)
    user = _make_sequence(20)
    path = [(i, i) for i in range(20)]
    scores = {"timing": 90.0, "technique": 80.0, "expression": 75.0, "spatialAwareness": 85.0}

    fb = generate_feedback(ref, user, path, 85.0, scores)
    assert any("consistent" in t for t in fb.timing_insights)


def test_rushing_detection():
    """A steep slope in the first quarter should flag rushing."""
    ref = _make_sequence(20)
    user = _make_sequence(30)
    # First quarter: steep (user advances fast), rest: near-flat
    path = []
    for i in range(5):
        path.append((i, i * 3))  # steep: slope ~3
    for i in range(5, 20):
        path.append((i, min(15 + (i - 5), 29)))  # gentle slope, capped at 29
    scores = {"timing": 50.0, "technique": 60.0, "expression": 55.0, "spatialAwareness": 60.0}

    fb = generate_feedback(ref, user, path, 55.0, scores)
    assert any("rushed" in t or "ahead" in t for t in fb.timing_insights)


def test_coaching_summary_tier_excellent():
    """Score >= 85 should produce 'Excellent' in coaching summary."""
    ref = _make_sequence(10)
    user = _make_sequence(10)
    path = [(i, i) for i in range(10)]
    scores = {"timing": 90.0, "technique": 88.0, "expression": 85.0, "spatialAwareness": 92.0}

    fb = generate_feedback(ref, user, path, 90.0, scores)
    assert "Excellent" in fb.coaching_summary


def test_weakest_dimension_in_coaching():
    """The weakest dimension should be mentioned in coaching."""
    ref = _make_sequence(10)
    user = _make_sequence(10)
    path = [(i, i) for i in range(10)]
    scores = {"timing": 40.0, "technique": 80.0, "expression": 75.0, "spatialAwareness": 85.0}

    fb = generate_feedback(ref, user, path, 65.0, scores)
    assert "timing" in fb.coaching_summary.lower()


def test_empty_path_graceful():
    """An empty path should yield empty timing/joint insights but still produce coaching."""
    ref = _make_sequence(10)
    user = _make_sequence(10)
    scores = {"timing": 50.0, "technique": 50.0, "expression": 50.0, "spatialAwareness": 50.0}

    fb = generate_feedback(ref, user, [], 50.0, scores)
    assert fb.timing_insights == []
    assert fb.joint_insights == []
    assert len(fb.coaching_summary) > 0
