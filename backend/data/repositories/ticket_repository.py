from core.database import get_db
from datetime import datetime


def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


class TicketRepository:

    def create(
        self,
        id_voyage: int,
        id_segment: int,
        point_depart: str,
        point_arrivee: str,
        type_tarif: str,
        quantite: int,
        prix_unitaire: int,
        montant_total: int,
        matricule_agent: int,
        sync_status: str = "online",
        numero_titre: str | None = None,
    ) -> int:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """
                INSERT INTO billetterie.ticket_vendu
                    (id_voyage, id_segment, point_depart, point_arrivee,
                     type_tarif, quantite, prix_unitaire, montant_total,
                     date_heure, matricule_agent, sync_status, numero_titre)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    id_voyage,
                    id_segment,
                    point_depart,
                    point_arrivee,
                    type_tarif,
                    quantite,
                    prix_unitaire,
                    montant_total,
                    _now(),
                    matricule_agent,
                    sync_status,
                    numero_titre,
                ),
            )
            conn.commit()
            return cursor.lastrowid
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def get_by_voyage(self, id_voyage: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    t.id_ticket,
                    t.id_voyage,
                    t.id_segment,
                    t.point_depart,
                    t.point_arrivee,
                    t.type_tarif,
                    t.quantite,
                    t.prix_unitaire,
                    t.montant_total,
                    t.date_heure,
                    t.matricule_agent,
                    t.sync_status,
                    t.checked_at        AS scanned_at,
                    t.numero_titre,
                    sv.ordre             AS segment_ordre,
                    sv.point_depart      AS segment_point_depart,
                    sv.point_arrivee     AS segment_point_arrivee,
                    l.nom_ligne,
                    CONCAT(a.prenom, ' ', a.nom) AS agent_nom
                FROM      billetterie.ticket_vendu   t
                LEFT JOIN billetterie.segment_voyage sv
                       ON sv.id_segment = t.id_segment
                      AND (
                            sv.id_voyage = t.id_voyage
                            OR (
                                sv.id_voyage IS NULL
                                AND NOT EXISTS (
                                    SELECT 1
                                    FROM billetterie.segment_voyage sv2
                                    WHERE sv2.id_segment = t.id_segment
                                      AND sv2.id_voyage  = t.id_voyage
                                )
                            )
                          )
                LEFT JOIN billetterie.voyage          v
                       ON v.id_voyage   = t.id_voyage
                LEFT JOIN base_global.ligne           l
                       ON l.id_ligne    = v.id_ligne
                LEFT JOIN base_global.agent           a
                       ON a.matricule_agent = t.matricule_agent
                WHERE t.id_voyage = %s
                ORDER BY sv.ordre ASC, t.date_heure DESC
                """,
                (id_voyage,),
            )
            return cursor.fetchall()
        finally:
            conn.close()

    def get_special_stats(self, id_voyage: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    type_tarif,
                    COUNT(*)       AS count,
                    SUM(quantite)  AS total_quantite
                FROM billetterie.ticket_vendu
                WHERE id_voyage = %s AND prix_unitaire = 0
                GROUP BY type_tarif
                ORDER BY count DESC
                """,
                (id_voyage,),
            )
            return cursor.fetchall()
        finally:
            conn.close()

    # ── Ticket verification (QR scan of sold ticket) ──────────────────────────

    def get_ticket_for_verification(self, id_ticket: int) -> dict | None:
        """Fetch by integer PK (legacy QR format)."""
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    t.id_ticket,
                    t.id_voyage,
                    t.id_segment,
                    t.point_depart,
                    t.point_arrivee,
                    t.type_tarif,
                    t.quantite,
                    t.prix_unitaire,
                    t.montant_total,
                    t.date_heure,
                    t.matricule_agent,
                    t.sync_status,
                    t.checked_at        AS scanned_at,
                    t.numero_titre,
                    sv.ordre             AS segment_ordre,
                    l.id_ligne,
                    l.nom_ligne,
                    v.date_heure        AS voyage_date,
                    CONCAT(a.prenom, ' ', a.nom) AS agent_nom
                FROM      billetterie.ticket_vendu   t
                LEFT JOIN billetterie.segment_voyage sv
                       ON sv.id_segment = t.id_segment
                      AND (
                            sv.id_voyage = t.id_voyage
                            OR (
                                sv.id_voyage IS NULL
                                AND NOT EXISTS (
                                    SELECT 1
                                    FROM billetterie.segment_voyage sv2
                                    WHERE sv2.id_segment = t.id_segment
                                      AND sv2.id_voyage  = t.id_voyage
                                )
                            )
                          )
                LEFT JOIN billetterie.voyage v
                       ON v.id_voyage = t.id_voyage
                LEFT JOIN base_global.ligne l
                       ON l.id_ligne = v.id_ligne
                LEFT JOIN base_global.agent a
                       ON a.matricule_agent = t.matricule_agent
                WHERE t.id_ticket = %s
                LIMIT 1
                """,
                (id_ticket,),
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def get_ticket_by_numero(self, numero_titre: str) -> dict | None:
        """
        Fetch by client-generated numero_titre string
        (NouveauTicketPage QR format: {"id": "SRTB-...", ...}).
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    t.id_ticket,
                    t.id_voyage,
                    t.id_segment,
                    t.point_depart,
                    t.point_arrivee,
                    t.type_tarif,
                    t.quantite,
                    t.prix_unitaire,
                    t.montant_total,
                    t.date_heure,
                    t.matricule_agent,
                    t.sync_status,
                    t.checked_at        AS scanned_at,
                    t.numero_titre,
                    sv.ordre             AS segment_ordre,
                    l.id_ligne,
                    l.nom_ligne,
                    v.date_heure        AS voyage_date,
                    CONCAT(a.prenom, ' ', a.nom) AS agent_nom
                FROM      billetterie.ticket_vendu   t
                LEFT JOIN billetterie.segment_voyage sv
                       ON sv.id_segment = t.id_segment
                      AND (
                            sv.id_voyage = t.id_voyage
                            OR (
                                sv.id_voyage IS NULL
                                AND NOT EXISTS (
                                    SELECT 1
                                    FROM billetterie.segment_voyage sv2
                                    WHERE sv2.id_segment = t.id_segment
                                      AND sv2.id_voyage  = t.id_voyage
                                )
                            )
                          )
                LEFT JOIN billetterie.voyage v
                       ON v.id_voyage = t.id_voyage
                LEFT JOIN base_global.ligne l
                       ON l.id_ligne = v.id_ligne
                LEFT JOIN base_global.agent a
                       ON a.matricule_agent = t.matricule_agent
                WHERE t.numero_titre = %s
                LIMIT 1
                """,
                (numero_titre,),
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def mark_ticket_scanned(self, id_ticket: int) -> bool:
        """
        Atomically mark a ticket as scanned — only if not scanned yet.
        Returns True if succeeded, False if already scanned (race guard).
        """
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """
                UPDATE billetterie.ticket_vendu
                SET    checked_at = %s
                WHERE  id_ticket  = %s
                  AND  checked_at IS NULL
                """,
                (_now(), id_ticket),
            )
            conn.commit()
            return cursor.rowcount == 1
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()