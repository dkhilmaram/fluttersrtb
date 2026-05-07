import asyncio
import json
from datetime import datetime, date
from typing import AsyncGenerator

from fastapi import APIRouter
from fastapi.responses import StreamingResponse

from data.models.heartbeat_models import HeartbeatPayload
from services.heartbeat_service import HeartbeatService

router = APIRouter(tags=["heartbeat"])


# ── helpers ───────────────────────────────────────────────────────────────────

def _serialize(obj):
    """JSON-serialise datetime / date objects."""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serialisable")


# ── POST /agent/heartbeat ─────────────────────────────────────────────────────

@router.post("/agent/heartbeat")
async def receive_heartbeat(payload: HeartbeatPayload):
    """
    Called by the Flutter SyncService every 30 s and after every sync attempt.
    Upserts a row in agent_heartbeat so the web dashboard can track liveness.
    Also persists pending_tickets details so the dashboard can inspect queued items.
    """
    await HeartbeatService.record(payload)
    return {"success": True}


# ── GET /api/sync/stream  (Server-Sent Events) ────────────────────────────────

async def _event_generator() -> AsyncGenerator[str, None]:
    """
    Polls the DB every 2 seconds and pushes a JSON snapshot to the client.
    Yields SSE-formatted strings: 'data: <json>\\n\\n'
    """
    while True:
        try:
            rows = await HeartbeatService.get_snapshot()
            payload = json.dumps(rows, default=_serialize)
            yield f"data: {payload}\n\n"
        except Exception as exc:
            yield f"event: error\ndata: {str(exc)}\n\n"
        await asyncio.sleep(2)


@router.get("/api/sync/stream")
async def sync_stream():
    """
    Server-Sent Events endpoint consumed by the React SyncMonitor page.
    Returns a continuous stream; the browser EventSource reconnects automatically
    on disconnect.

    nginx: add 'proxy_buffering off;' and 'X-Accel-Buffering: no' for this route.
    gunicorn: use --worker-class uvicorn.workers.UvicornWorker (default for FastAPI).
    """
    return StreamingResponse(
        _event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control":     "no-cache",
            "X-Accel-Buffering": "no",
            "Connection":        "keep-alive",
        },
    )