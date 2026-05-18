from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.models import FamilyLink, User
from app.schemas.family_link import FamilyLinkCreate, FamilyLinkResponse
from sqlalchemy import select

router = APIRouter(prefix="/family-links", tags=["family-links"])


@router.post("/request", response_model=FamilyLinkResponse)
async def create_link_request(
    data: FamilyLinkCreate,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = user_payload["sub"]
    role = user_payload["role"]

    # Child submits elderly's invite code to create a link
    if data.invite_code:
        elderly_result = await db.execute(
            select(User).where(User.invite_code == data.invite_code)
        )
        elderly = elderly_result.scalar_one_or_none()
        if elderly is None:
            raise HTTPException(status_code=400, detail="邀请码无效")

        # Check if already linked
        existing = await db.execute(
            select(FamilyLink).where(
                FamilyLink.elderly_id == elderly.id,
                FamilyLink.child_id == user_id,
                FamilyLink.status == "active",
            )
        )
        if existing.scalar_one_or_none() is not None:
            raise HTTPException(status_code=400, detail="已经绑定了该老人")

        link = FamilyLink(
            elderly_id=elderly.id, child_id=user_id, status="active"
        )
        db.add(link)
        await db.commit()
        await db.refresh(link)
        return FamilyLinkResponse.model_validate(link)

    # Elderly creates a pending link for child to accept
    if role == "elderly":
        link = FamilyLink(elderly_id=user_id, status="pending")
    else:
        if data.target_phone:
            elderly_result = await db.execute(
                select(User).where(User.phone == data.target_phone)
            )
            elderly = elderly_result.scalar_one_or_none()
            if elderly is None:
                raise HTTPException(status_code=404, detail="Elderly user not found")
            link = FamilyLink(
                elderly_id=elderly.id, child_id=user_id, status="active"
            )
        else:
            link = FamilyLink(child_id=user_id, status="pending")

    db.add(link)
    await db.commit()
    await db.refresh(link)
    return FamilyLinkResponse.model_validate(link)


@router.put("/{link_id}/accept", response_model=FamilyLinkResponse)
async def accept_link(
    link_id: str,
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(FamilyLink).where(FamilyLink.id == link_id))
    link = result.scalar_one_or_none()
    if link is None:
        raise HTTPException(status_code=404, detail="Link not found")
    link.status = "active"
    await db.commit()
    await db.refresh(link)
    return FamilyLinkResponse.model_validate(link)


@router.get("/", response_model=list[FamilyLinkResponse])
async def list_links(
    user_payload: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = user_payload["sub"]
    result = await db.execute(
        select(FamilyLink).where(
            (FamilyLink.elderly_id == user_id) | (FamilyLink.child_id == user_id)
        )
    )
    return [FamilyLinkResponse.model_validate(link) for link in result.scalars().all()]
