"""Tests for the SQLite evaluation storage layer."""

import sqlite3

import pytest

from api.storage import sqlite as store


def _sample_row(eval_id="test-123", score=75.0):
    return {
        "id": eval_id,
        "overall_score": score,
        "dimensions": [
            {"dimension": "timing", "score": 80.0, "summary": "Good rhythm."},
            {"dimension": "technique", "score": 65.0, "summary": "Needs work."},
            {"dimension": "expression", "score": 70.0, "summary": "Decent energy."},
            {"dimension": "spatialAwareness", "score": 85.0, "summary": "Great positioning."},
        ],
        "joint_feedback": [
            {
                "joint_name": "leftElbow",
                "landmark_indices": [11, 13, 15],
                "score": 42.5,
                "issue": "Your left elbow angle deviates.",
                "correction": "Practice isolating your left elbow.",
            },
        ],
        "created_at": "2026-04-05T12:00:00",
        "style": "hipHop",
        "timing_insights": ["Your timing was consistent throughout the routine."],
        "joint_insights": ["Your left elbow was slightly too bent in the first quarter."],
        "coaching_summary": "Good work overall. Focus on technique.",
        "drills": [
            {
                "drill_id": "tech_arm_circles",
                "name": "Arm Extension Circles",
                "description": "Full arm circles with straight elbows.",
                "target_joint": "leftElbow",
                "target_dimension": "technique",
                "priority": 1,
            },
        ],
    }


class TestSave:
    def test_save_and_get(self):
        row = _sample_row()
        store.save(row)
        result = store.get("test-123")
        assert result is not None
        assert result["id"] == "test-123"
        assert result["overall_score"] == 75.0

    def test_duplicate_id_raises(self):
        store.save(_sample_row("dup-1"))
        with pytest.raises(sqlite3.IntegrityError):
            store.save(_sample_row("dup-1"))


class TestGet:
    def test_returns_none_for_missing(self):
        assert store.get("nonexistent") is None

    def test_roundtrip_all_fields(self):
        """Every field should survive the save→get roundtrip exactly."""
        original = _sample_row("roundtrip-1")
        store.save(original)
        loaded = store.get("roundtrip-1")

        assert loaded["id"] == original["id"]
        assert loaded["overall_score"] == original["overall_score"]
        assert loaded["style"] == original["style"]
        assert loaded["created_at"] == original["created_at"]
        assert loaded["coaching_summary"] == original["coaching_summary"]
        assert loaded["timing_insights"] == original["timing_insights"]
        assert loaded["joint_insights"] == original["joint_insights"]
        assert loaded["dimensions"] == original["dimensions"]
        assert loaded["joint_feedback"] == original["joint_feedback"]
        assert loaded["drills"] == original["drills"]

    def test_null_coaching_summary(self):
        row = _sample_row("null-coaching")
        row["coaching_summary"] = None
        store.save(row)
        loaded = store.get("null-coaching")
        assert loaded["coaching_summary"] is None

    def test_empty_lists_roundtrip(self):
        row = _sample_row("empty-lists")
        row["timing_insights"] = []
        row["joint_insights"] = []
        row["drills"] = []
        store.save(row)
        loaded = store.get("empty-lists")
        assert loaded["timing_insights"] == []
        assert loaded["joint_insights"] == []
        assert loaded["drills"] == []


class TestList:
    def test_empty_db(self):
        assert store.list_evaluations() == []

    def test_ordered_newest_first(self):
        store.save(_sample_row("older"))
        row2 = _sample_row("newer")
        row2["created_at"] = "2026-04-06T12:00:00"
        store.save(row2)

        results = store.list_evaluations()
        assert len(results) == 2
        assert results[0]["id"] == "newer"
        assert results[1]["id"] == "older"

    def test_limit_and_offset(self):
        for i in range(5):
            row = _sample_row(f"item-{i}")
            row["created_at"] = f"2026-04-0{i + 1}T12:00:00"
            store.save(row)

        page1 = store.list_evaluations(limit=2, offset=0)
        assert len(page1) == 2

        page2 = store.list_evaluations(limit=2, offset=2)
        assert len(page2) == 2

        page3 = store.list_evaluations(limit=2, offset=4)
        assert len(page3) == 1

        all_ids = [r["id"] for r in page1 + page2 + page3]
        assert len(set(all_ids)) == 5


class TestDelete:
    def test_delete_existing(self):
        store.save(_sample_row("to-delete"))
        assert store.delete("to-delete") is True
        assert store.get("to-delete") is None

    def test_delete_missing_returns_false(self):
        assert store.delete("nonexistent") is False

    def test_delete_does_not_affect_others(self):
        store.save(_sample_row("keep"))
        store.save(_sample_row("remove"))
        store.delete("remove")
        assert store.get("keep") is not None
        assert store.get("remove") is None
