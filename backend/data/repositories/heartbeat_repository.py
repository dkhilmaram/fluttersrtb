import json
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
                     last_sync_at, app_version, updated_at, pending_tickets)
                VALUES (:matricule_agent, :pending_count, :failed_count,
                        :last_sync_at, :app_version, NOW(), :pending_tickets)
                ON DUPLICATE KEY UPDATE
                    pending_count   = VALUES(pending_count),
                    failed_count    = VALUES(failed_count),
                    last_sync_at    = VALUES(last_sync_at),
                    app_version     = VALUES(app_version),
                    updated_at      = NOW(),
                    pending_tickets = VALUES(pending_tickets)
                """,
                {
                    "matricule_agent": payload.matricule_agent,
                    "pending_count":   payload.pending_count,
                    "failed_count":    payload.failed_count,
                    "last_sync_at":    payload.last_sync_at,
                    "app_version":     payload.app_version,
                    # Serialise list → JSON string for the TEXT/JSON column
                    "pending_tickets": json.dumps(
                        payload.pending_tickets or [],
                        default=str,
                    ),
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
                    h.pending_tickets,
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
            result = []
            for r in rows:
                row = dict(r)
                # Parse pending_tickets back from JSON string to list
                raw = row.get("pending_tickets")
                if isinstance(raw, str):
                    try:
                        row["pending_tickets"] = json.loads(raw)
                    except (json.JSONDecodeError, TypeError):
                        row["pending_tickets"] = []
                elif raw is None:
                    row["pending_tickets"] = []
                result.append(row)
            return result