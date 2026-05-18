from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import CORS_ORIGINS
from app.api.v1.router import router as v1_router
from app.api.v1.websocket import ws_endpoint
from app.models.models import Base
from app.core.database import engine

app = FastAPI(
    title="银发族数字陪驾 API",
    description="Digital Co-Pilot for Seniors - Backend API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(v1_router)


@app.websocket("/api/v1/ws/coscreen/{session_id}")
async def websocket_coscreen(websocket: WebSocket, session_id: str, token: str):
    await ws_endpoint(websocket, session_id, token)


@app.on_event("startup")
async def startup():
    # Create tables (for dev; use alembic for production)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@app.get("/")
async def root():
    return {"service": "银发族数字陪驾", "version": "0.1.0", "status": "running"}