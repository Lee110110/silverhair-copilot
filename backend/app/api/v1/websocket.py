from fastapi import WebSocket, WebSocketDisconnect
from app.ws.connection_manager import manager
from app.schemas.ws_message import WsMessage
from app.core.security import verify_token
from app.ws.frame_relay import FrameRelay
from app.ws.annotation_relay import AnnotationRelay
from app.core.database import async_session
from app.models.models import AnnotationSession
from sqlalchemy import select
import json
import logging

logger = logging.getLogger(__name__)

frame_relay = FrameRelay()
annotation_relay = AnnotationRelay()


async def _activate_session(session_id: str):
    """Update session status from 'pending' to 'active' in the database."""
    async with async_session() as db:
        result = await db.execute(
            select(AnnotationSession).where(AnnotationSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if session and session.status == "pending":
            session.status = "active"
            await db.commit()
            logger.info(f"Session {session_id} activated")


async def ws_endpoint(websocket: WebSocket, session_id: str, token: str):
    print(f"[WS] >>> CONNECTION REQUEST session={session_id}", flush=True)
    # Accept first so the client can properly receive close frames
    await websocket.accept()
    print(f"[WS] >>> ACCEPTED session={session_id}", flush=True)

    payload = verify_token(token)
    if payload is None:
        logger.warning(f"WS rejected: invalid token for session {session_id}")
        print(f"[WS] >>> INVALID TOKEN session={session_id}", flush=True)
        await websocket.close(code=4001, reason="Invalid token")
        return

    user_id = payload.get("sub")
    role = payload.get("role")
    print(f"[WS] >>> CONNECTED session={session_id} user={user_id} role={role}", flush=True)

    await manager.connect(session_id, user_id, role, websocket)
    conn_count = len(manager.sessions.get(session_id, {}))
    print(f"[WS] >>> Session {session_id} now has {conn_count} connections", flush=True)

    try:
        if manager.is_session_ready(session_id):
            await _activate_session(session_id)
            ready_msg = WsMessage(
                type="session.ready",
                session_id=session_id,
                payload={"elderly_ready": True, "child_ready": True},
            )
            await manager.broadcast(session_id, ready_msg.model_dump_json())
            logger.info(f"Session {session_id}: session.ready broadcast")

        while True:
            data = await websocket.receive_text()
            msg = WsMessage.model_validate_json(data)
            msg_type = msg.type
            logger.debug(f"WS msg: session={session_id} user={user_id} type={msg_type}")

            if msg_type.startswith("frame."):
                await handle_frame_message(session_id, user_id, role, msg, websocket)
            elif msg_type.startswith("annotation."):
                await handle_annotation_message(session_id, user_id, role, msg, websocket)
            elif msg_type.startswith("sos."):
                await handle_sos_message(session_id, user_id, role, msg, websocket)
            elif msg_type.startswith("heartbeat."):
                await handle_heartbeat(session_id, user_id, role, msg, websocket)
            elif msg_type.startswith("session."):
                await handle_session_message(session_id, user_id, role, msg, websocket)
            else:
                await manager.relay(session_id, user_id, data)

    except WebSocketDisconnect:
        manager.disconnect(session_id, user_id)
        logger.info(f"WS disconnected: session={session_id} user={user_id}")
        # Notify peer that this user temporarily disconnected (not session end).
        # The disconnected client will auto-reconnect; sending session.end
        # here was killing the session whenever the elderly app went to
        # background for the MediaProjection permission dialog.
        await manager.broadcast(
            session_id,
            json.dumps({
                "type": "session.peer_disconnect",
                "session_id": session_id,
                "payload": {"user_id": user_id},
            }),
        )
    except Exception as e:
        manager.disconnect(session_id, user_id)
        logger.error(f"WS error: session={session_id} user={user_id} error={e}")
        await manager.broadcast(
            session_id,
            json.dumps({
                "type": "session.peer_disconnect",
                "session_id": session_id,
                "payload": {"user_id": user_id, "error": str(e)},
            }),
        )


async def handle_frame_message(session_id, user_id, role, msg, ws):
    if msg.type == "frame.screen":
        frame_relay.record_frame(session_id, msg.payload)
        await manager.relay(session_id, user_id, msg.model_dump_json())
    elif msg.type == "frame.ack":
        frame_relay.ack_frame(session_id, msg.payload.get("seq", 0))
        await manager.relay(session_id, user_id, msg.model_dump_json())


async def handle_annotation_message(session_id, user_id, role, msg, ws):
    annotation_relay.record_annotation(session_id, msg.type, msg.payload)
    await manager.relay(session_id, user_id, msg.model_dump_json())


async def handle_sos_message(session_id, user_id, role, msg, ws):
    await manager.relay(session_id, user_id, msg.model_dump_json())


async def handle_heartbeat(session_id, user_id, role, msg, ws):
    if msg.type == "heartbeat.ping":
        pong = WsMessage(type="heartbeat.pong", session_id=session_id)
        await manager.send_to_user(session_id, user_id, pong.model_dump_json())


async def handle_session_message(session_id, user_id, role, msg, ws):
    if msg.type == "session.join":
        if manager.is_session_ready(session_id):
            await _activate_session(session_id)
            ready_msg = WsMessage(
                type="session.ready",
                session_id=session_id,
                payload={"elderly_ready": True, "child_ready": True},
            )
            await manager.broadcast(session_id, ready_msg.model_dump_json())
            logger.info(f"Session {session_id}: session.ready broadcast (from session.join)")
    elif msg.type == "session.end":
        reason = msg.payload.get("reason", "user_quit")
        end_msg = WsMessage(
            type="session.end",
            session_id=session_id,
            payload={"reason": reason, "user_id": user_id},
        )
        await manager.broadcast(session_id, end_msg.model_dump_json())
        manager.disconnect(session_id, user_id)
