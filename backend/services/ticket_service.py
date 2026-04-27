from data.repositories.ticket_repository import TicketRepository
from core.exceptions import SegmentIntrouvable, PrixInvalide
from core.database import get_db

_SPECIAL_KEYWORDS = [
    "Gratuit", "Armée", "Armee", "Garde", "Police", "Douane",
    "Ministère", "Ministere", "Municipalité", "Municipalite",
    "Scolaire", "Institution", "Autre", "Abonnement",
    "Agent", "NFC", "Barcode", "Scan",
]


def is_special_passage(type_tarif: str) -> bool:
    return any(kw.lower() in type_tarif.lower() for kw in _SPECIAL_KEYWORDS)


class TicketService:
    def __init__(self):
        self.repo = TicketRepository()

    # ── Segment resolution ────────────────────────────────────────────────────

    def _resolve_segment(self, id_voyage: int, point_depart: str) -> int:
        """
        Resolve the correct id_segment from point_depart.

        Priority:
          1. Exact match on segment_voyage.point_depart for this voyage
             (case-insensitive). This is the normal case — each boarding
             stop maps to exactly one segment row.
          2. Last segment by ordre — used when the boarding stop is the
             final arrival of the route (edge case: agent sells a ticket
             at the terminus before the voyage is fully closed).
          3. Raises SegmentIntrouvable if the voyage has no segments at all.
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            # ── Primary: match point_depart on voyage-specific segment rows ──
            cursor.execute(
                """
                SELECT id_segment
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s
                  AND LOWER(point_depart) = LOWER(%s)
                LIMIT 1
                """,
                (id_voyage, point_depart),
            )
            row = cursor.fetchone()
            if row:
                return row["id_segment"]

            # ── Fallback: last segment by ordre ──────────────────────────────
            cursor.execute(
                """
                SELECT id_segment
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s
                ORDER BY ordre DESC
                LIMIT 1
                """,
                (id_voyage,),
            )
            row = cursor.fetchone()
            if row:
                return row["id_segment"]

        finally:
            conn.close()

        raise SegmentIntrouvable()

    # ── Core actions ──────────────────────────────────────────────────────────

    def vendre(self, data: dict) -> int:
        type_tarif    = data.get("type_tarif", "")
        prix_unitaire = float(data.get("prix_unitaire", 0))
        montant_total = float(data.get("montant_total", 0))
        id_voyage     = data.get("id_voyage")
        point_depart  = data.get("point_depart", "")

        raw_sync    = data.get("sync_status", "online")
        sync_status = raw_sync if raw_sync in ("online", "synced") else "online"

        # Validate special passage pricing
        if is_special_passage(type_tarif) and (prix_unitaire != 0 or montant_total != 0):
            raise PrixInvalide(type_tarif)

        # Always resolve segment server-side — never trust the client value
        id_segment = self._resolve_segment(id_voyage, point_depart)

        return self.repo.create(
            id_voyage       = id_voyage,
            id_segment      = id_segment,
            point_depart    = point_depart,
            point_arrivee   = data.get("point_arrivee"),
            type_tarif      = type_tarif,
            quantite        = int(data.get("quantite", 1)),
            prix_unitaire   = prix_unitaire,
            montant_total   = montant_total,
            matricule_agent = data.get("matricule_agent"),
            sync_status     = sync_status,
        )

    def get_by_voyage(self, id_voyage: int):
        rows = self.repo.get_by_voyage(id_voyage)
        return [
            {
                **r,
                "date_heure": str(r["date_heure"]),
                "agent":      r.get("agent_nom"),
                "is_free":    is_special_passage(r.get("type_tarif") or ""),
            }
            for r in rows
        ]

    def get_special_stats(self, id_voyage: int):
        return self.repo.get_special_stats(id_voyage)