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
    ) -> int:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """
                INSERT INTO billetterie.ticket_vendu
                    (id_voyage, id_segment, point_depart, point_arrivee,
                     type_tarif, quantite, prix_unitaire, montant_total,
                     date_heure, matricule_agent, sync_status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
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
        """
        Returns every ticket for the voyage with its canonical id_segment,
        segment ordre, departure/arrival from the segment row (as fallback),
        ligne name, and agent name.

        The JOIN on segment_voyage handles two cases:
          1. Voyage-specific rows  → sv.id_voyage = t.id_voyage  (preferred)
          2. Line-template rows    → sv.id_voyage IS NULL         (fallback)
             used only when no voyage-specific row exists for that id_segment.

        This prevents the bug where all tickets collapse into the same segment
        because their segment rows were stored as line-level templates
        (id_voyage = NULL) instead of voyage-specific rows.
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
                    sv.ordre             AS segment_ordre,
                    sv.point_depart      AS segment_point_depart,
                    sv.point_arrivee     AS segment_point_arrivee,
                    l.nom_ligne,
                    CONCAT(a.prenom, ' ', a.nom) AS agent_nom
                FROM      billetterie.ticket_vendu   t
                LEFT JOIN billetterie.segment_voyage sv
                       ON sv.id_segment = t.id_segment
                      AND (
                            -- Prefer voyage-specific segment row
                            sv.id_voyage = t.id_voyage
                            OR (
                                -- Fall back to line-template row (id_voyage IS NULL)
                                -- only when no voyage-specific row exists
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