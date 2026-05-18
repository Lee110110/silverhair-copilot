from fastapi import WebSocket
from collections import defaultdict
import asyncio


class ConnectionManager:
    def __init__(self):
        # session_id -> { user_id -> WebSocket }
        self.sessions: dict[str, dict[str, WebSocket]] = defaultdict(dict)

    async def connect(self, session_id: str, user_id: str, role: str, ws: WebSocket):
        self.sessions[session_id][user_id] = ws

    def disconnect(self, session_id: str, user_id: str):
        if session_id in self.sessions and user_id in self.sessions[session_id]:
            del self.sessions[session_id][user_id]
            if not self.sessions[session_id]:
                del self.sessions[session_id]

    def is_session_ready(self, session_id: str) -> bool:
        return session_id in self.sessions and len(self.sessions[session_id]) >= 2

    async def relay(self, session_id: str, from_user_id: str, message: str):
        """Send message to all other users in the session."""
        if session_id not in self.sessions:
            return
        for uid, ws in self.sessions[session_id].items():
            if uid != from_user_id:
                try:
                    await ws.send_text(message)
                except Exception:
                    pass

    async def broadcast(self, session_id: str, message: str):
        """Send message to all users in the session."""
        if session_id not in self.sessions:
            return
        for ws in self.sessions[session_id].values():
            try:
                await ws.send_text(message)
            except Exception:
                pass

    async def send_to_user(self, session_id: str, user_id: str, message: str):
        """Send message to a specific user in the session."""
        if session_id in self.sessions and user_id in self.sessions[session_id]:
            try:
                await self.sessions[session_id][user_id].send_text(message)
            except Exception:
                pass


manager = ConnectionManager()