"""Tests for evaluation endpoints — full CRUD."""

import pytest


def _make_frame(offset: float = 0.0):
    """Build a realistic 33-landmark frame payload."""
    landmarks = []
    for i in range(33):
        landmarks.append({
            "x": 0.5 + offset + i * 0.001,
            "y": 0.3 + i * 0.02,
            "z": 0.0,
            "visibility": 0.9,
        })
    return {"timestamp_ms": 0, "landmarks": landmarks}


def _make_payload(reference_id="hip_hop_basic", n_frames=10, offset=0.0):
    return {
        "reference_id": reference_id,
        "style": "hipHop",
        "frames": [_make_frame(offset + i * 0.001) for i in range(n_frames)],
    }


# ---------------------------------------------------------------------------
# POST /v1/evaluations
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_post_evaluations_returns_200(client):
    response = await client.post("/v1/evaluations", json=_make_payload())
    assert response.status_code == 200
    data = response.json()

    assert "id" in data
    assert 0 <= data["overall_score"] <= 100
    assert len(data["dimensions"]) == 4
    assert all(d["dimension"] in ("timing", "technique", "expression", "spatialAwareness")
               for d in data["dimensions"])
    assert all(0 <= d["score"] <= 100 for d in data["dimensions"])
    assert isinstance(data["joint_feedback"], list)
    assert data["style"] == "hipHop"


@pytest.mark.asyncio
async def test_post_evaluations_unknown_reference_404(client):
    payload = _make_payload(reference_id="nonexistent_ref_xyz")
    response = await client.post("/v1/evaluations", json=payload)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_post_evaluations_empty_frames_422(client):
    payload = {
        "reference_id": "hip_hop_basic",
        "style": "hipHop",
        "frames": [],
    }
    response = await client.post("/v1/evaluations", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_post_evaluations_response_has_feedback_fields(client):
    response = await client.post("/v1/evaluations", json=_make_payload())
    data = response.json()
    assert isinstance(data["timing_insights"], list)
    assert len(data["timing_insights"]) > 0
    assert isinstance(data["joint_insights"], list)
    assert isinstance(data["coaching_summary"], str)
    assert len(data["coaching_summary"]) > 0
    assert isinstance(data["drills"], list)
    for drill in data["drills"]:
        assert "drill_id" in drill
        assert "name" in drill
        assert "description" in drill
        assert "target_joint" in drill
        assert "target_dimension" in drill
        assert "priority" in drill


@pytest.mark.asyncio
async def test_post_evaluations_joint_feedback_structure(client):
    response = await client.post("/v1/evaluations", json=_make_payload())
    data = response.json()
    for jf in data["joint_feedback"]:
        assert "joint_name" in jf
        assert "landmark_indices" in jf
        assert len(jf["landmark_indices"]) == 3
        assert "score" in jf
        assert "issue" in jf
        assert "correction" in jf


# ---------------------------------------------------------------------------
# GET /v1/evaluations/{id}
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_evaluation_by_id(client):
    post_resp = await client.post("/v1/evaluations", json=_make_payload())
    eval_id = post_resp.json()["id"]

    get_resp = await client.get(f"/v1/evaluations/{eval_id}")
    assert get_resp.status_code == 200
    data = get_resp.json()
    assert data["id"] == eval_id
    assert data["overall_score"] == post_resp.json()["overall_score"]
    assert len(data["dimensions"]) == 4


@pytest.mark.asyncio
async def test_get_evaluation_not_found_404(client):
    response = await client.get("/v1/evaluations/nonexistent-id")
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# GET /v1/evaluations (list)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_evaluations_empty(client):
    response = await client.get("/v1/evaluations")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_list_evaluations_returns_created(client):
    await client.post("/v1/evaluations", json=_make_payload())
    await client.post("/v1/evaluations", json=_make_payload(offset=0.01))

    response = await client.get("/v1/evaluations")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


@pytest.mark.asyncio
async def test_list_evaluations_limit(client):
    for i in range(5):
        await client.post("/v1/evaluations", json=_make_payload(offset=i * 0.01))

    response = await client.get("/v1/evaluations?limit=3")
    assert response.status_code == 200
    assert len(response.json()) == 3


@pytest.mark.asyncio
async def test_list_evaluations_offset(client):
    for i in range(5):
        await client.post("/v1/evaluations", json=_make_payload(offset=i * 0.01))

    response = await client.get("/v1/evaluations?limit=10&offset=3")
    assert response.status_code == 200
    assert len(response.json()) == 2


# ---------------------------------------------------------------------------
# DELETE /v1/evaluations/{id}
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_delete_evaluation(client):
    post_resp = await client.post("/v1/evaluations", json=_make_payload())
    eval_id = post_resp.json()["id"]

    del_resp = await client.delete(f"/v1/evaluations/{eval_id}")
    assert del_resp.status_code == 204

    get_resp = await client.get(f"/v1/evaluations/{eval_id}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_evaluation_not_found_404(client):
    response = await client.delete("/v1/evaluations/nonexistent-id")
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Video endpoint — still stubbed
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_post_video_evaluation_returns_501(client):
    response = await client.post("/v1/evaluations/video")
    assert response.status_code == 501
