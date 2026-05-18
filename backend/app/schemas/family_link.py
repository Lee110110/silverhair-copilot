from pydantic import BaseModel
from datetime import datetime


class FamilyLinkCreate(BaseModel):
    target_phone: str | None = None
    invite_code: str | None = None


class FamilyLinkResponse(BaseModel):
    id: str
    elderly_id: str
    child_id: str | None = None
    invite_code: str | None = None
    status: str
    created_at: datetime | None = None

    model_config = {"from_attributes": True}