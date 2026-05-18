from pydantic import BaseModel
from datetime import datetime


class CoScreenSessionCreate(BaseModel):
    elderly_id: str
    child_id: str | None = None


class CoScreenSessionResponse(BaseModel):
    id: str
    elderly_id: str
    child_id: str
    status: str
    created_at: datetime | None = None
    ended_at: datetime | None = None

    model_config = {"from_attributes": True}