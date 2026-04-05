import os
import tempfile

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient


@pytest.fixture(autouse=True)
def _isolated_db(tmp_path):
    """Each test gets its own SQLite database."""
    db_path = str(tmp_path / "test_evaluations.db")
    os.environ["EVAL_DB_PATH"] = db_path
    yield
    os.environ.pop("EVAL_DB_PATH", None)


@pytest_asyncio.fixture
async def client():
    from api.main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
