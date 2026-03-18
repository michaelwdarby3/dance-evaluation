import pytest
from pydantic import ValidationError
from api.routes.evaluation import LandmarkIn, PoseFrameIn, EvaluationRequest


@pytest.mark.asyncio
async def test_landmark_accepts_valid_data():
    lm = LandmarkIn(x=0.5, y=0.3, z=-0.1, visibility=0.95)
    assert lm.x == 0.5
    assert lm.y == 0.3
    assert lm.z == -0.1
    assert lm.visibility == 0.95


@pytest.mark.asyncio
async def test_landmark_default_visibility():
    lm = LandmarkIn(x=0.1, y=0.2, z=0.3)
    assert lm.visibility == 0.0


@pytest.mark.asyncio
async def test_pose_frame_requires_timestamp_and_landmarks():
    landmarks = [LandmarkIn(x=0.1, y=0.2, z=0.3)]
    frame = PoseFrameIn(timestamp_ms=100, landmarks=landmarks)
    assert frame.timestamp_ms == 100
    assert len(frame.landmarks) == 1


@pytest.mark.asyncio
async def test_evaluation_request_requires_fields():
    landmarks = [LandmarkIn(x=0.1, y=0.2, z=0.3)]
    frame = PoseFrameIn(timestamp_ms=0, landmarks=landmarks)
    req = EvaluationRequest(reference_id="ref-1", style="salsa", frames=[frame])
    assert req.reference_id == "ref-1"
    assert req.style == "salsa"
    assert len(req.frames) == 1


@pytest.mark.asyncio
async def test_evaluation_request_realistic_data():
    """Validate with 30 frames, each containing 33 landmarks (MediaPipe pose)."""
    frames = []
    for i in range(30):
        landmarks = [
            LandmarkIn(x=j * 0.01, y=j * 0.02, z=j * 0.001, visibility=0.9)
            for j in range(33)
        ]
        frames.append(PoseFrameIn(timestamp_ms=i * 33, landmarks=landmarks))

    req = EvaluationRequest(reference_id="ref-42", style="hip-hop", frames=frames)
    assert len(req.frames) == 30
    assert len(req.frames[0].landmarks) == 33


@pytest.mark.asyncio
async def test_landmark_missing_required_field_raises():
    with pytest.raises(ValidationError):
        LandmarkIn(x=0.1, y=0.2)  # missing z


@pytest.mark.asyncio
async def test_pose_frame_missing_timestamp_raises():
    with pytest.raises(ValidationError):
        PoseFrameIn(landmarks=[LandmarkIn(x=0.1, y=0.2, z=0.3)])


@pytest.mark.asyncio
async def test_pose_frame_missing_landmarks_raises():
    with pytest.raises(ValidationError):
        PoseFrameIn(timestamp_ms=100)


@pytest.mark.asyncio
async def test_evaluation_request_missing_fields_raises():
    with pytest.raises(ValidationError):
        EvaluationRequest(reference_id="ref-1")  # missing style and frames


@pytest.mark.asyncio
async def test_landmark_wrong_type_raises():
    with pytest.raises(ValidationError):
        LandmarkIn(x="not-a-float", y=0.2, z=0.3)
