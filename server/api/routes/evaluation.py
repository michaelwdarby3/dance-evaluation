"""Evaluation endpoints — full CRUD backed by local SQLite storage."""

from datetime import datetime

import numpy as np
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from api.core.scoring import evaluate
from api.references.repository import load_reference
from api.storage import sqlite as store

router = APIRouter(tags=["evaluation"])


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class LandmarkIn(BaseModel):
    x: float
    y: float
    z: float
    visibility: float = 0.0


class PoseFrameIn(BaseModel):
    timestamp_ms: int
    landmarks: list[LandmarkIn]


class EvaluationRequest(BaseModel):
    reference_id: str
    style: str
    frames: list[PoseFrameIn]


class DimensionScoreOut(BaseModel):
    dimension: str
    score: float
    summary: str


class JointFeedbackOut(BaseModel):
    joint_name: str
    landmark_indices: list[int]
    score: float
    issue: str
    correction: str


class DrillRecommendationOut(BaseModel):
    drill_id: str
    name: str
    description: str
    target_joint: str
    target_dimension: str
    priority: int


class EvaluationResponse(BaseModel):
    id: str
    overall_score: float
    dimensions: list[DimensionScoreOut]
    joint_feedback: list[JointFeedbackOut]
    created_at: datetime
    style: str
    timing_insights: list[str] = []
    joint_insights: list[str] = []
    coaching_summary: str | None = None
    drills: list[DrillRecommendationOut] = []


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/evaluations", response_model=EvaluationResponse)
async def create_evaluation(req: EvaluationRequest):
    # Load reference
    try:
        ref_frames = load_reference(req.reference_id)
    except FileNotFoundError:
        raise HTTPException(404, f"Reference '{req.reference_id}' not found")

    if not req.frames:
        raise HTTPException(422, "No frames provided")

    # Convert request frames to numpy arrays.
    user_frames = []
    for pf in req.frames:
        arr = np.zeros((len(pf.landmarks), 4), dtype=np.float64)
        for i, lm in enumerate(pf.landmarks):
            arr[i] = [lm.x, lm.y, lm.z, lm.visibility]
        user_frames.append(arr)

    result = evaluate(user_frames, ref_frames, style=req.style)

    response = EvaluationResponse(
        id=result.id,
        overall_score=result.overall_score,
        dimensions=[
            DimensionScoreOut(
                dimension=d.dimension,
                score=d.score,
                summary=d.summary,
            )
            for d in result.dimensions
        ],
        joint_feedback=[
            JointFeedbackOut(
                joint_name=j.joint_name,
                landmark_indices=j.landmark_indices,
                score=j.score,
                issue=j.issue,
                correction=j.correction,
            )
            for j in result.joint_feedback
        ],
        created_at=datetime.fromisoformat(result.created_at),
        style=result.style,
        timing_insights=result.timing_insights,
        joint_insights=result.joint_insights,
        coaching_summary=result.coaching_summary,
        drills=[
            DrillRecommendationOut(
                drill_id=d.drill_id,
                name=d.name,
                description=d.description,
                target_joint=d.target_joint,
                target_dimension=d.target_dimension,
                priority=d.priority,
            )
            for d in result.drills
        ],
    )

    store.save(_response_to_row(response))
    return response


@router.get("/evaluations/{evaluation_id}", response_model=EvaluationResponse)
async def get_evaluation(evaluation_id: str):
    row = store.get(evaluation_id)
    if not row:
        raise HTTPException(404, f"Evaluation '{evaluation_id}' not found")
    return _row_to_response(row)


@router.get("/evaluations", response_model=list[EvaluationResponse])
async def list_evaluations(limit: int = 20, offset: int = 0):
    rows = store.list_evaluations(limit=limit, offset=offset)
    return [_row_to_response(r) for r in rows]


@router.delete("/evaluations/{evaluation_id}", status_code=204)
async def delete_evaluation(evaluation_id: str):
    if not store.delete(evaluation_id):
        raise HTTPException(404, f"Evaluation '{evaluation_id}' not found")


@router.post("/evaluations/video", status_code=501)
async def create_video_evaluation():
    raise HTTPException(501, "Not implemented — Path 2 coming in Milestone 3")


# ---------------------------------------------------------------------------
# Storage mapping helpers
# ---------------------------------------------------------------------------


def _response_to_row(resp: EvaluationResponse) -> dict:
    return {
        "id": resp.id,
        "overall_score": resp.overall_score,
        "dimensions": [d.model_dump() for d in resp.dimensions],
        "joint_feedback": [j.model_dump() for j in resp.joint_feedback],
        "created_at": resp.created_at.isoformat(),
        "style": resp.style,
        "timing_insights": resp.timing_insights,
        "joint_insights": resp.joint_insights,
        "coaching_summary": resp.coaching_summary,
        "drills": [d.model_dump() for d in resp.drills],
    }


def _row_to_response(row: dict) -> EvaluationResponse:
    return EvaluationResponse(
        id=row["id"],
        overall_score=row["overall_score"],
        dimensions=[DimensionScoreOut(**d) for d in row["dimensions"]],
        joint_feedback=[JointFeedbackOut(**j) for j in row["joint_feedback"]],
        created_at=datetime.fromisoformat(row["created_at"]),
        style=row["style"],
        timing_insights=row["timing_insights"],
        joint_insights=row["joint_insights"],
        coaching_summary=row["coaching_summary"],
        drills=[DrillRecommendationOut(**d) for d in row["drills"]],
    )
