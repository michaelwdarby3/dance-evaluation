"""Evaluation endpoints — stubs for Milestone 2."""

from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(tags=["evaluation"])


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


class EvaluationResponse(BaseModel):
    id: str
    overall_score: float
    dimensions: list[DimensionScoreOut]
    joint_feedback: list[JointFeedbackOut]
    created_at: datetime
    style: str


@router.post("/evaluations", response_model=EvaluationResponse, status_code=501)
async def create_evaluation(req: EvaluationRequest):
    raise HTTPException(501, "Not implemented — server evaluation coming in Milestone 2")


@router.get("/evaluations/{evaluation_id}", response_model=EvaluationResponse, status_code=501)
async def get_evaluation(evaluation_id: str):
    raise HTTPException(501, "Not implemented")


@router.get("/evaluations", status_code=501)
async def list_evaluations(limit: int = 20, offset: int = 0):
    raise HTTPException(501, "Not implemented")


@router.delete("/evaluations/{evaluation_id}", status_code=501)
async def delete_evaluation(evaluation_id: str):
    raise HTTPException(501, "Not implemented")


@router.post("/evaluations/video", status_code=501)
async def create_video_evaluation():
    raise HTTPException(501, "Not implemented — Path 2 coming in Milestone 3")
