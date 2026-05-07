from typing import List
from data.models.heartbeat_models import HeartbeatPayload
from data.repositories.heartbeat_repository import HeartbeatRepository


class HeartbeatService:

    @staticmethod
    async def record(payload: HeartbeatPayload) -> None:
        """Validate and persist a heartbeat from the mobile app."""
        await HeartbeatRepository.upsert(payload)

    @staticmethod
    async def get_snapshot() -> List[dict]:
        """
        Return the latest state of every agent for the SSE stream.
        Each dict is JSON-serialisable (datetimes are converted to ISO strings
        by the router before sending).
        """
        return await HeartbeatRepository.get_all_with_stats()