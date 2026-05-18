from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.core.security import create_access_token, create_refresh_token, verify_token
from app.models.models import User, UserRole, gen_invite_code
from app.schemas.user import (
    PhoneLoginRequest, WechatLoginRequest, SmsSendRequest,
    TokenResponse, UserResponse, RefreshRequest,
)
from app.utils.sms_notify import send_sms_code, verify_sms_code
from app.utils.wechat_login import verify_wechat_code
import uuid

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/sms/send")
async def send_sms(req: SmsSendRequest):
    success = await send_sms_code(req.phone)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to send SMS")
    return {"success": True}


@router.post("/login/phone", response_model=TokenResponse)
async def login_phone(req: PhoneLoginRequest, db: AsyncSession = Depends(get_db)):
    if not await verify_sms_code(req.phone, req.code):
        raise HTTPException(status_code=400, detail="Invalid verification code")

    role_val = req.role if req.role in ("elderly", "child") else "elderly"

    from sqlalchemy import select
    result = await db.execute(
        select(User).where(User.phone == req.phone, User.role == role_val)
    )
    user = result.scalar_one_or_none()

    if user is None:
        user = User(phone=req.phone, role=UserRole(role_val))
        if role_val == "elderly":
            for _ in range(10):
                code = gen_invite_code()
                from sqlalchemy import select as sel
                existing = await db.execute(sel(User).where(User.invite_code == code))
                if existing.scalar_one_or_none() is None:
                    user.invite_code = code
                    break
        db.add(user)
        await db.commit()
        await db.refresh(user)
    elif user.invite_code is None and user.role == "elderly":
        for _ in range(10):
            code = gen_invite_code()
            from sqlalchemy import select as sel
            existing = await db.execute(sel(User).where(User.invite_code == code))
            if existing.scalar_one_or_none() is None:
                user.invite_code = code
                break
        await db.commit()
        await db.refresh(user)

    token_data = {"sub": str(user.id), "role": user.role if isinstance(user.role, str) else user.role.value}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user=UserResponse.model_validate(user),
    )


@router.post("/login/wechat", response_model=TokenResponse)
async def login_wechat(req: WechatLoginRequest, db: AsyncSession = Depends(get_db)):
    openid = await verify_wechat_code(req.code)
    if openid is None:
        raise HTTPException(status_code=400, detail="Invalid WeChat code")

    from sqlalchemy import select
    result = await db.execute(select(User).where(User.wechat_openid == openid))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(wechat_openid=openid, role=UserRole.child)
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token_data = {"sub": str(user.id), "role": user.role if isinstance(user.role, str) else user.role.value}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user=UserResponse.model_validate(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = verify_token(req.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user_id = payload.get("sub")
    from sqlalchemy import select
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    token_data = {"sub": str(user.id), "role": user.role if isinstance(user.role, str) else user.role.value}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user=UserResponse.model_validate(user),
    )