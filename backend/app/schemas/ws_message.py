from pydantic import BaseModel
from typing import Any


class WsMessage(BaseModel):
    type: str
    session_id: str | None = None
    timestamp: str | None = None
    payload: dict[str, Any] = {}