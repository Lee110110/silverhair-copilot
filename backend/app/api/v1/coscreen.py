from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.models import AnnotationSession
from app.schemas.coscreen import CoScreenSessionCreate, CoScreenSessionResponse
from sqlalchemy import select, update
from datetime import datetime, timezone

router = APIRouter(prefix="/coscreen", tags=["coscreen"])


@router.post("/session", response_model=CoScreenSessionResponse)
async def create_session(
    data: CoScreenSessionCreate,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    child_id = data.child_id if data.child_id else user_payload["sub"]

    # Clean up stale "pending" sessions for the same pair before creating a new one
    await db.execute(
        update(AnnotationSession)
        .where(
            AnnotationSession.elderly_id == data.elderly_id,
            AnnotationSession.child_id == child_id,
            AnnotationSession.status == "pending",
        )
        .values(status="ended", ended_at=datetime.now(timezone.utc))
    )

    session = AnnotationSession(
        elderly_id=data.elderly_id, child_id=child_id
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return CoScreenSessionResponse.model_validate(session)


@router.get("/pending")
async def get_pending_session(
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = user_payload["sub"]
    role = user_payload.get("role", "elderly")

    if role == "child":
        result = await db.execute(
            select(AnnotationSession)
            .where(AnnotationSession.child_id == user_id, AnnotationSession.status == "pending")
            .order_by(AnnotationSession.created_at.desc())
            .limit(1)
        )
    else:
        result = await db.execute(
            select(AnnotationSession)
            .where(AnnotationSession.elderly_id == user_id, AnnotationSession.status == "pending")
            .order_by(AnnotationSession.created_at.desc())
            .limit(1)
        )
    session = result.scalar_one_or_none()
    if session is None:
        return {"session_id": None}
    return {"session_id": session.id, "child_id": session.child_id, "elderly_id": session.elderly_id, "created_at": str(session.created_at)}


@router.get("/session/{session_id}", response_model=CoScreenSessionResponse)
async def get_session(
    session_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AnnotationSession).where(AnnotationSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return CoScreenSessionResponse.model_validate(session)


@router.put("/session/{session_id}/accept", response_model=CoScreenSessionResponse)
async def accept_session(
    session_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AnnotationSession).where(AnnotationSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    session.status = "active"
    await db.commit()
    await db.refresh(session)
    return CoScreenSessionResponse.model_validate(session)


@router.put("/session/{session_id}/end", response_model=CoScreenSessionResponse)
async def end_session(
    session_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    result = await db.execute(
        select(AnnotationSession).where(AnnotationSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    session.status = "ended"
    session.ended_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(session)
    return CoScreenSessionResponse.model_validate(session)