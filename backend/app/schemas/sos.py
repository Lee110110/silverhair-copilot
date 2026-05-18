from pydantic import BaseModel
from datetime import datetime


class SosAlertCreate(BaseModel):
    elderly_id: str | None = None
    location_lat: str | None = None
    location_lng: str | None = None


class SosResponse(BaseModel):
    id: str
    elderly_id: str
    child_id: str
    status: str
    location_lat: str | None = None
    location_lng: str | None = None
    created_at: datetime | None = None
    resolved_at: datetime | None = None

    model_config = {"from_attributes": True}