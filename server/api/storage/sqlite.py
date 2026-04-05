"""SQLite-backed evaluation storage.

Stores full EvaluationResult rows with complex fields serialized as JSON.
DB file defaults to ``server/data/evaluations.db`` (auto-created).
Swap this module for a Firestore implementation when moving to the cloud.
"""

import json
import os
import sqlite3
from pathlib import Path

_DB_DIR = Path(__file__).resolve().parent.parent.parent / "data"

_CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS evaluations (
    id              TEXT PRIMARY KEY,
    overall_score   REAL    NOT NULL,
    dimensions      TEXT    NOT NULL,   -- JSON array
    joint_feedback  TEXT    NOT NULL,   -- JSON array
    created_at      TEXT    NOT NULL,
    style           TEXT    NOT NULL,
    timing_insights TEXT    NOT NULL,   -- JSON array
    joint_insights  TEXT    NOT NULL,   -- JSON array
    coaching_summary TEXT,
    drills          TEXT    NOT NULL    -- JSON array
);
"""


def _db_path() -> str:
    return os.environ.get("EVAL_DB_PATH", str(_DB_DIR / "evaluations.db"))


def _connect() -> sqlite3.Connection:
    db_path = Path(_db_path())
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute(_CREATE_TABLE)
    return conn


def save(row: dict) -> None:
    """Insert an evaluation result dict. Raises on duplicate id."""
    conn = _connect()
    try:
        conn.execute(
            """INSERT INTO evaluations
               (id, overall_score, dimensions, joint_feedback, created_at,
                style, timing_insights, joint_insights, coaching_summary, drills)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                row["id"],
                row["overall_score"],
                json.dumps(row["dimensions"]),
                json.dumps(row["joint_feedback"]),
                row["created_at"],
                row["style"],
                json.dumps(row["timing_insights"]),
                json.dumps(row["joint_insights"]),
                row.get("coaching_summary"),
                json.dumps(row["drills"]),
            ),
        )
        conn.commit()
    finally:
        conn.close()


def get(evaluation_id: str) -> dict | None:
    """Return a single evaluation dict or None."""
    conn = _connect()
    try:
        cur = conn.execute("SELECT * FROM evaluations WHERE id = ?", (evaluation_id,))
        row = cur.fetchone()
        return _row_to_dict(row) if row else None
    finally:
        conn.close()


def list_evaluations(limit: int = 20, offset: int = 0) -> list[dict]:
    """Return evaluations ordered by created_at descending."""
    conn = _connect()
    try:
        cur = conn.execute(
            "SELECT * FROM evaluations ORDER BY created_at DESC LIMIT ? OFFSET ?",
            (limit, offset),
        )
        return [_row_to_dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


def delete(evaluation_id: str) -> bool:
    """Delete by id. Returns True if a row was deleted."""
    conn = _connect()
    try:
        cur = conn.execute("DELETE FROM evaluations WHERE id = ?", (evaluation_id,))
        conn.commit()
        return cur.rowcount > 0
    finally:
        conn.close()


def _row_to_dict(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "overall_score": row["overall_score"],
        "dimensions": json.loads(row["dimensions"]),
        "joint_feedback": json.loads(row["joint_feedback"]),
        "created_at": row["created_at"],
        "style": row["style"],
        "timing_insights": json.loads(row["timing_insights"]),
        "joint_insights": json.loads(row["joint_insights"]),
        "coaching_summary": row["coaching_summary"],
        "drills": json.loads(row["drills"]),
    }
