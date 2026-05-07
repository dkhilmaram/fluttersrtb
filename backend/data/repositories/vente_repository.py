from core.database import get_db
from datetime import datetime
from data.repositories.segment_repository import SegmentRepository


def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _normalize_type(raw_type: str | None) -> str:
    """
    Flutter sends 'spontané' for manually-created trips.
    The DB stores 'non programmé' for that category.
    'programmé' is kept as-is.
    Anything else also maps to 'non programmé'.
    """
    if raw_type == "programmé":
        return "programmé"
    return "non programmé"


class VenteRepository:

    def __init__(self):
        self._seg_repo = SegmentRepository()

    def create(self, data) -> int:
        conn = get_db()
        cursor = conn.cursor()
        type_value = _normalize_type(data.type)
        try:
            cursor.execute(
                """INSERT INTO billetterie.voyage
                   (id_ligne, id_appareil, date_heure, matricule_agent, code_agence, type, statut)
                   VALUES (%s, %s, %s, %s, %s, %s, 'actif')""",
                (
                    data.id_ligne,
                    data.id_appareil,   # always int (0 fallback from model)
                    data.date_heure,
                    data.matricule_agent,
                    data.code_agence,
                    type_value,
                ),
            )
            conn.commit()
            new_id = cursor.lastrowid
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

        # Copy template segments from the ligne into the new voyage
        self._seg_repo.copy_segments_from_ligne(new_id, data.id_ligne)

        return new_id

    def find_by_id(self, id_voyage: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT * FROM billetterie.voyage WHERE id_voyage = %s", (id_voyage,)
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def get_statut(self, id_voyage: int) -> str | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT statut FROM billetterie.voyage WHERE id_voyage = %s", (id_voyage,)
            )
            row = cursor.fetchone()
            return row["statut"] if row else None
        finally:
            conn.close()

    def get_programmees(self, matricule_agent: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    v.id_voyage,
                    v.id_ligne,
                    v.id_appareil,
                    v.date_heure,
                    v.type,
                    v.statut,
                    v.matricule_agent,
                    v.code_agence,
                    l.nom_ligne,
                    l.point_depart  AS depart,
                    l.point_arrive  AS arrivee,
                    a.nom,
                    a.prenom
                FROM billetterie.voyage v
                JOIN  base_global.ligne l ON v.id_ligne        = l.id_ligne
                LEFT JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
                WHERE v.type = 'programmé'
                  AND v.matricule_agent = %s
                ORDER BY v.date_heure DESC
                """,
                (matricule_agent,),
            )
            return cursor.fetchall()
        finally:
            conn.close()

    def get_by_agent(self, matricule_agent: int) -> list[dict]:
        """
        Returns ALL voyages for the agent (both programmé and non programmé).
        Flutter then filters client-side.
        Adds depart/arrivee aliases so both tabs can read the same field names.
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    v.id_voyage,
                    v.id_ligne,
                    v.date_heure,
                    v.type,
                    v.statut,
                    v.id_appareil,
                    v.code_agence,
                    v.matricule_agent,
                    l.nom_ligne,
                    l.point_depart  AS depart,
                    l.point_arrive  AS arrivee
                FROM billetterie.voyage v
                JOIN base_global.ligne l ON v.id_ligne = l.id_ligne
                WHERE v.matricule_agent = %s
                ORDER BY v.date_heure DESC
                """,
                (matricule_agent,),
            )
            return cursor.fetchall()
        finally:
            conn.close()

    def delete(self, id_voyage: int) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE FROM billetterie.voyage WHERE id_voyage = %s", (id_voyage,)
            )
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def cloturer(self, id_voyage: int) -> str:
        now = _now()
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "UPDATE billetterie.voyage SET statut='cloture', date_cloture=%s WHERE id_voyage=%s",
                (now, id_voyage),
            )
            conn.commit()
            return now
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def reopen(self, id_voyage: int):
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "UPDATE billetterie.voyage SET statut='actif', date_cloture=NULL WHERE id_voyage=%s",
                (id_voyage,),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def bulk_cloturer(self, ids: list[int]) -> int:
        now = _now()
        conn = get_db()
        cursor = conn.cursor()
        closed = 0
        try:
            for id_voyage in ids:
                cursor.execute(
                    """UPDATE billetterie.voyage
                       SET statut='cloture', date_cloture=%s
                       WHERE id_voyage=%s AND statut != 'cloture'""",
                    (now, id_voyage),
                )
                closed += cursor.rowcount
            conn.commit()
            return closed
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def bulk_reopen(self, ids: list[int]) -> int:
        conn = get_db()
        cursor = conn.cursor()
        reopened = 0
        try:
            for id_voyage in ids:
                cursor.execute(
                    """UPDATE billetterie.voyage
                       SET statut='actif', date_cloture=NULL
                       WHERE id_voyage=%s AND statut='cloture'""",
                    (id_voyage,),
                )
                reopened += cursor.rowcount
            conn.commit()
            return reopened
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    # ─────────────────────────────────────────────────────────────
    # Fetch lines filtered by agence
    # ─────────────────────────────────────────────────────────────
    def get_lignes_by_agence(self, code_agence: int) -> list[dict]:
        """
        Returns all active lines assigned to a given agence.
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    l.id_ligne,
                    l.nom_ligne,
                    l.point_depart,
                    l.point_arrive
                FROM base_global.ligne l
                WHERE l.code_agence = %s
                ORDER BY l.nom_ligne ASC
                """,
                (code_agence,),
            )
            return cursor.fetchall()
        finally:
            conn.close()