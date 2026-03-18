"""Dance Evaluation API — FastAPI application."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Routes will be enabled as they are implemented.
from api.routes import evaluation
# from api.routes import reference, auth, sync


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: load models, connect to services
    yield
    # Shutdown: cleanup


app = FastAPI(
    title="Dance Evaluation API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}


app.include_router(evaluation.router, prefix="/v1")
# app.include_router(reference.router, prefix="/v1")
# app.include_router(auth.router, prefix="/v1")
# app.include_router(sync.router, prefix="/v1")
