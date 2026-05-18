from pydantic import BaseModel, Field
from datetime import datetime
from app.models.models import UserRole


class UserBase(BaseModel):
    name: str | None = None
    role: str


class UserCreate(UserBase):
    phone: str | None = None
    wechat_openid: str | None = None


class UserResponse(UserBase):
    id: str
    phone: str | None = None
    invite_code: str | None = None
    is_active: bool
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserResponse


class RefreshRequest(BaseModel):
    refresh_token: str


class SmsSendRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")


class PhoneLoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")
    code: str = Field(..., min_length=4, max_length=6)
    role: str = "elderly"


class WechatLoginRequest(BaseModel):
    code: str