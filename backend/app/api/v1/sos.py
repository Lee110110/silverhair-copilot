from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.models import SosEvent, FamilyLink
from app.schemas.sos import SosAlertCreate, SosResponse
from sqlalchemy import select

router = APIRouter(prefix="/sos", tags=["sos"])


@router.post("/alert", response_model=SosResponse)
async def create_sos_alert(
    data: SosAlertCreate,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    elderly_id = user_payload["sub"] if data.elderly_id is None else data.elderly_id

    result = await db.execute(
        select(FamilyLink).where(
            FamilyLink.elderly_id == elderly_id, FamilyLink.status == "active"
        ).limit(1)
    )
    link = result.scalars().first()
    if link is None:
        raise HTTPException(status_code=404, detail="No linked child found")

    sos = SosEvent(
        elderly_id=elderly_id,
        child_id=link.child_id,
        location_lat=data.location_lat,
        location_lng=data.location_lng,
    )
    db.add(sos)
    await db.commit()
    await db.refresh(sos)

    from app.ws.sos_handler import sos_manager
    await sos_manager.push_alert(str(sos.id), str(link.child_id), {
        "elderly_id": str(elderly_id),
        "sos_id": str(sos.id),
        "location": {"lat": data.location_lat, "lng": data.location_lng},
    })

    return SosResponse.model_validate(sos)


@router.put("/{sos_id}/accept", response_model=SosResponse)
async def accept_sos(
    sos_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SosEvent).where(SosEvent.id == sos_id))
    sos = result.scalar_one_or_none()
    if sos is None:
        raise HTTPException(status_code=404, detail="SOS event not found")
    sos.status = "accepted"
    await db.commit()
    await db.refresh(sos)

    from app.ws.sos_handler import sos_manager
    await sos_manager.push_accept(str(sos.elderly_id), {"sos_id": str(sos.id), "status": "accepted"})

    return SosResponse.model_validate(sos)


@router.put("/{sos_id}/cancel", response_model=SosResponse)
async def cancel_sos(
    sos_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SosEvent).where(SosEvent.id == sos_id))
    sos = result.scalar_one_or_none()
    if sos is None:
        raise HTTPException(status_code=404, detail="SOS event not found")
    sos.status = "cancelled"
    await db.commit()
    await db.refresh(sos)
    return SosResponse.model_validate(sos)


@router.get("/history", response_model=list[SosResponse])
async def sos_history(
    limit: int = 20,
    offset: int = 0,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = user_payload["sub"]
    result = await db.execute(
        select(SosEvent)
        .where((SosEvent.elderly_id == user_id) | (SosEvent.child_id == user_id))
        .order_by(SosEvent.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return [SosResponse.model_validate(e) for e in result.scalars().all()]