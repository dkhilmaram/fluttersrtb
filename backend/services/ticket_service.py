import uuid
from datetime import date as _date
from data.repositories.ticket_repository import TicketRepository
from core.exceptions import SegmentIntrouvable, PrixInvalide, TicketIntrouvable, TicketDejaScanne, LigneIncompatible
from core.database import get_db

_SPECIAL_KEYWORDS = [
    "Gratuit", "Armée", "Armee", "Garde", "Police", "Douane",
    "Ministère", "Ministere", "Municipalité", "Municipalite",
    "Scolaire", "Institution", "Autre", "Abonnement",
    "Agent", "NFC", "Barcode", "Scan",
]


def is_special_passage(type_tarif: str) -> bool:
    return any(kw.lower() in type_tarif.lower() for kw in _SPECIAL_KEYWORDS)


def _gen_numero_titre() -> str:
    """
    Server-side fallback: generates a unique ticket ID when Flutter does not
    send one (e.g. the Dart TicketRepository omits the field).

    Format: SRTB-YYYYMMDD-XXXXXXXX  (8 random hex chars, upper-case)
    """
    today  = _date.today().strftime("%Y%m%d")
    suffix = uuid.uuid4().hex[:8].upper()
    return f"SRTB-{today}-{suffix}"


class TicketService:
    def __init__(self):
        self.repo = TicketRepository()

    # ── Segment resolution ────────────────────────────────────────────────────

    def _resolve_segment(self, id_voyage: int, point_depart: str) -> int:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
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

    def vendre(self, data: dict) -> dict:
        """
        Save a sold ticket.

        Returns a dict with:
          - id_ticket    (int)   : the new auto-increment PK
          - numero_titre (str)   : the ID stored in the DB
                                   (Flutter's value if provided, otherwise
                                    a server-generated fallback)
        """
        type_tarif    = data.get("type_tarif", "")
        prix_unitaire = float(data.get("prix_unitaire", 0))
        montant_total = float(data.get("montant_total", 0))
        id_voyage     = data.get("id_voyage")
        point_depart  = data.get("point_depart", "")

        raw_sync    = data.get("sync_status", "online")
        sync_status = raw_sync if raw_sync in ("online", "synced") else "online"

        # Use the client-generated QR ID when present; fall back to a
        # server-generated one so numero_titre is never NULL.
        numero_titre = (data.get("numero_titre") or "").strip() or _gen_numero_titre()

        if is_special_passage(type_tarif) and (prix_unitaire != 0 or montant_total != 0):
            raise PrixInvalide(type_tarif)

        id_segment = self._resolve_segment(id_voyage, point_depart)

        id_ticket = self.repo.create(
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
            numero_titre    = numero_titre,
        )

        return {"id_ticket": id_ticket, "numero_titre": numero_titre}

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

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _build_ticket_response(self, row: dict) -> dict:
        """Serialise a ticket DB row into the API response shape."""
        already_scanned = row.get("scanned_at") is not None
        return {
            "id_ticket":      row["id_ticket"],
            "id_voyage":      row["id_voyage"],
            "point_depart":   row["point_depart"],
            "point_arrivee":  row["point_arrivee"],
            "type_tarif":     row["type_tarif"],
            "quantite":       row["quantite"],
            "prix_unitaire":  float(row["prix_unitaire"] or 0),
            "montant_total":  float(row["montant_total"] or 0),
            "date_heure":     str(row["date_heure"]),
            "nom_ligne":      row.get("nom_ligne") or "—",
            "agent_nom":      row.get("agent_nom") or "—",
            "numero_titre":   row.get("numero_titre"),
            "scanned_at":     str(row["scanned_at"]) if row.get("scanned_at") else None,
            "already_scanned": already_scanned,
        }

    def _check_ligne_compatibility(self, row: dict, id_voyage_courant: int) -> None:
        """
        Raise LigneIncompatible if the ticket's ligne differs from the
        agent's current voyage ligne.
        """
        if row["id_voyage"] == id_voyage_courant:
            return  # same voyage → always compatible

        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT v.id_ligne, l.nom_ligne
                FROM   billetterie.voyage v
                LEFT JOIN base_global.ligne l ON l.id_ligne = v.id_ligne
                WHERE  v.id_voyage = %s
                LIMIT 1
                """,
                (id_voyage_courant,),
            )
            current = cursor.fetchone()
        finally:
            conn.close()

        ticket_ligne  = row.get("id_ligne")
        current_ligne = current["id_ligne"] if current else None

        if ticket_ligne != current_ligne:
            raise LigneIncompatible(
                ticket_ligne  = row.get("nom_ligne") or str(ticket_ligne),
                current_ligne = (current or {}).get("nom_ligne") or str(current_ligne),
            )

    # ── Sold-ticket QR verification — by integer id_ticket ───────────────────

    def verify_ticket(self, id_ticket: int, id_voyage_courant: int) -> dict:
        row = self.repo.get_ticket_for_verification(id_ticket)
        if row is None:
            raise TicketIntrouvable(id_ticket)

        self._check_ligne_compatibility(row, id_voyage_courant)
        return self._build_ticket_response(row)

    def mark_ticket_scanned(self, id_ticket: int, id_voyage_courant: int) -> dict:
        info = self.verify_ticket(id_ticket, id_voyage_courant)

        if info["already_scanned"]:
            raise TicketDejaScanne(id_ticket, info["scanned_at"])

        success = self.repo.mark_ticket_scanned(id_ticket)
        if not success:
            raise TicketDejaScanne(id_ticket, None)

        return {**info, "scanned_at": None, "already_scanned": False}

    # ── Sold-ticket QR verification — by string numero_titre ─────────────────

    def verify_ticket_by_numero(self, numero_titre: str, id_voyage_courant: int) -> dict:
        """
        Verify using the client-generated string ID from NouveauTicketPage QR
        ({"id": "SRTB-20260505-000042", "vente": 5, ...}).
        """
        row = self.repo.get_ticket_by_numero(numero_titre)
        if row is None:
            raise TicketIntrouvable(numero_titre)

        self._check_ligne_compatibility(row, id_voyage_courant)
        return self._build_ticket_response(row)

    def mark_ticket_scanned_by_numero(self, numero_titre: str, id_voyage_courant: int) -> dict:
        """Scan/validate using the string numero_titre."""
        info = self.verify_ticket_by_numero(numero_titre, id_voyage_courant)

        if info["already_scanned"]:
            raise TicketDejaScanne(numero_titre, info["scanned_at"])

        success = self.repo.mark_ticket_scanned(info["id_ticket"])
        if not success:
            raise TicketDejaScanne(numero_titre, None)

        return {**info, "scanned_at": None, "already_scanned": False}