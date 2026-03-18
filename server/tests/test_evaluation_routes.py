import pytest


@pytest.mark.asyncio
async def test_post_evaluations_returns_501(client):
    payload = {
        "reference_id": "ref-1",
        "style": "salsa",
        "frames": [
            {
                "timestamp_ms": 0,
                "landmarks": [{"x": 0.1, "y": 0.2, "z": 0.3}],
            }
        ],
    }
    response = await client.post("/v1/evaluations", json=payload)
    assert response.status_code == 501


@pytest.mark.asyncio
async def test_get_evaluation_by_id_returns_501(client):
    response = await client.get("/v1/evaluations/test-id")
    assert response.status_code == 501


@pytest.mark.asyncio
async def test_list_evaluations_returns_501(client):
    response = await client.get("/v1/evaluations")
    assert response.status_code == 501


@pytest.mark.asyncio
async def test_delete_evaluation_returns_501(client):
    response = await client.delete("/v1/evaluations/test-id")
    assert response.status_code == 501


@pytest.mark.asyncio
async def test_post_video_evaluation_returns_501(client):
    response = await client.post("/v1/evaluations/video")
    assert response.status_code == 501
