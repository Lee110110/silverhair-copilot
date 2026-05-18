import asyncio
from collections import defaultdict


class SosWebSocketManager:
    """Manages SOS WebSocket connections for real-time push notifications."""
    def __init__(self):
        # child_id -> WebSocket
        self.child_connections: dict[str, asyncio.Queue] = defaultdict(asyncio.Queue)

    def register(self, child_id: str) -> asyncio.Queue:
        """Register a child to receive SOS alerts. Returns a queue."""
        return self.child_connections[child_id]

    def unregister(self, child_id: str):
        if child_id in self.child_connections:
            del self.child_connections[child_id]

    async def push_alert(self, sos_id: str, child_id: str, data: dict):
        """Push an SOS alert to a specific child."""
        if child_id in self.child_connections:
            await self.child_connections[child_id].put({
                "type": "sos.alert",
                "sos_id": sos_id,
                **data,
            })

    async def push_accept(self, elderly_id: str, data: dict):
        """Push SOS accept notification to the elderly user's queue."""
        if elderly_id in self.child_connections:
            await self.child_connections[elderly_id].put({
                "type": "sos.accept",
                **data,
            })


sos_manager = SosWebSocketManager()