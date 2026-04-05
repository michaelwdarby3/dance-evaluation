"""Tests for the drill recommendation engine."""

from api.core.drills import recommend_drills


def test_empty_when_all_scores_high():
    """No drills recommended when all scores are above 70."""
    dims = {"timing": 80.0, "technique": 85.0, "expression": 75.0, "spatialAwareness": 90.0}
    joints = [{"joint_name": "leftElbow", "score": 80.0}]
    assert recommend_drills(dims, joints) == []


def test_weak_timing_returns_timing_drills():
    dims = {"timing": 30.0, "technique": 80.0, "expression": 80.0, "spatialAwareness": 80.0}
    drills = recommend_drills(dims, [])
    assert len(drills) > 0
    assert any(d.target_dimension == "timing" for d in drills)


def test_weak_joint_returns_technique_drill():
    dims = {"timing": 80.0, "technique": 40.0, "expression": 80.0, "spatialAwareness": 80.0}
    joints = [{"joint_name": "leftElbow", "score": 35.0}]
    drills = recommend_drills(dims, joints)
    assert any(d.target_dimension == "technique" for d in drills)


def test_limit_to_five():
    dims = {"timing": 20.0, "technique": 20.0, "expression": 20.0, "spatialAwareness": 20.0}
    joints = [
        {"joint_name": "leftElbow", "score": 10.0},
        {"joint_name": "rightElbow", "score": 15.0},
        {"joint_name": "leftKnee", "score": 20.0},
        {"joint_name": "leftShoulder", "score": 25.0},
        {"joint_name": "leftHip", "score": 30.0},
        {"joint_name": "leftAnkle", "score": 35.0},
    ]
    drills = recommend_drills(dims, joints)
    assert len(drills) <= 5


def test_priorities_sequential():
    dims = {"timing": 20.0, "technique": 20.0, "expression": 20.0, "spatialAwareness": 80.0}
    joints = [{"joint_name": "leftElbow", "score": 30.0}]
    drills = recommend_drills(dims, joints)
    if drills:
        priorities = [d.priority for d in drills]
        assert priorities == list(range(1, len(drills) + 1))


def test_no_duplicate_drill_ids():
    dims = {"timing": 30.0, "technique": 30.0, "expression": 30.0, "spatialAwareness": 30.0}
    joints = [
        {"joint_name": "leftElbow", "score": 20.0},
        {"joint_name": "rightElbow", "score": 25.0},
    ]
    drills = recommend_drills(dims, joints)
    ids = [d.drill_id for d in drills]
    assert len(ids) == len(set(ids))


def test_all_drills_have_nonempty_fields():
    dims = {"timing": 30.0, "technique": 30.0, "expression": 30.0, "spatialAwareness": 30.0}
    joints = [{"joint_name": "leftKnee", "score": 20.0}]
    drills = recommend_drills(dims, joints)
    for d in drills:
        assert d.name
        assert d.description


def test_weak_expression_returns_expression_drills():
    dims = {"timing": 80.0, "technique": 80.0, "expression": 30.0, "spatialAwareness": 80.0}
    drills = recommend_drills(dims, [])
    assert any(d.target_dimension == "expression" for d in drills)


def test_weak_spatial_returns_spatial_drills():
    dims = {"timing": 80.0, "technique": 80.0, "expression": 80.0, "spatialAwareness": 30.0}
    drills = recommend_drills(dims, [])
    assert any(d.target_dimension == "spatialAwareness" for d in drills)


def test_left_right_joint_normalization():
    """A leftElbow feedback should match a rightElbow drill (and vice versa)."""
    dims = {"timing": 80.0, "technique": 40.0, "expression": 80.0, "spatialAwareness": 80.0}
    joints = [{"joint_name": "leftElbow", "score": 30.0}]
    drills = recommend_drills(dims, joints)
    # Should match elbow drills despite left/right difference
    elbow_drills = [d for d in drills if "elbow" in d.name.lower() or "arm" in d.name.lower()]
    assert len(elbow_drills) > 0
