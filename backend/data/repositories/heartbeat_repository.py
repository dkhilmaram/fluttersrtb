from typing import List
from core.database import get_db
from data.models.heartbeat_models import HeartbeatPayload, HeartbeatRow


class HeartbeatRepository:

    @staticmethod
    async def upsert(payload: HeartbeatPayload) -> None:
        """Insert or update the heartbeat row for a given agent."""
        async with get_db() as conn:
            await conn.execute(
                """
                INSERT INTO agent_heartbeat
                    (matricule_agent, pending_count, failed_count,
                     last_sync_at, app_version, updated_at)
                VALUES (:matricule_agent, :pending_count, :failed_count,
                        :last_sync_at, :app_version, NOW())
                ON DUPLICATE KEY UPDATE
                    pending_count = VALUES(pending_count),
                    failed_count  = VALUES(failed_count),
                    last_sync_at  = VALUES(last_sync_at),
                    app_version   = VALUES(app_version),
                    updated_at    = NOW()
                """,
                {
                    "matricule_agent": payload.matricule_agent,
                    "pending_count":   payload.pending_count,
                    "failed_count":    payload.failed_count,
                    "last_sync_at":    payload.last_sync_at,
                    "app_version":     payload.app_version,
                },
            )

    @staticmethod
    async def get_all_with_stats() -> List[dict]:
        """
        Return every agent that has ever sent a heartbeat,
        joined with today's ticket counts and revenue from ticket_vendu.
        """
        async with get_db() as conn:
            rows = await conn.fetch_all(
                """
                SELECT
                    h.matricule_agent,
                    a.prenom,
                    a.nom,
                    h.pending_count,
                    h.failed_count,
                    h.last_sync_at,
                    h.app_version,
                    h.updated_at,
                    TIMESTAMPDIFF(SECOND, h.updated_at, NOW())          AS seconds_ago,
                    COALESCE(s.tickets_today, 0)                        AS tickets_today,
                    COALESCE(s.recette_today_ms, 0)                     AS recette_today_ms
                FROM agent_heartbeat h
                LEFT JOIN agent a
                       ON a.matricule = h.matricule_agent
                LEFT JOIN (
                    SELECT
                        matricule_agent,
                        COUNT(*)            AS tickets_today,
                        SUM(montant_total)  AS recette_today_ms
                    FROM ticket_vendu
                    WHERE DATE(created_at) = CURDATE()
                    GROUP BY matricule_agent
                ) s ON s.matricule_agent = h.matricule_agent
                ORDER BY h.updated_at DESC
                """
            )
            return [dict(r) for r in rows]