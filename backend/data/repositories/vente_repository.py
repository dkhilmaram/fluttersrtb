from core.database import get_db
from datetime import datetime

def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

class VenteRepository:

    def create(self, data) -> int:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """INSERT INTO billetterie.vente
                   (id_ligne, id_appareil, date_heure, matricule_agent, code_agence, type)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (data.id_ligne, data.id_appareil, data.date_heure,
                 data.matricule_agent, data.code_agence, data.type),
            )
            conn.commit()
            return cursor.lastrowid
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def find_by_id(self, id_vente: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT * FROM billetterie.vente WHERE id_vente = %s", (id_vente,)
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def get_statut(self, id_vente: int) -> str | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT statut FROM billetterie.vente WHERE id_vente = %s", (id_vente,)
            )
            row = cursor.fetchone()
            return row["statut"] if row else None
        finally:
            conn.close()

    def get_programmees(self, matricule_agent: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT v.id_vente, v.id_ligne, v.id_appareil,
                       v.date_heure, v.type, v.statut,
                       v.matricule_agent, v.code_agence,
                       l.nom_ligne, l.point_depart, l.point_arrive,
                       a.nom, a.prenom
                FROM billetterie.vente v
                JOIN  base_global.ligne l ON v.id_ligne        = l.id_ligne
                LEFT JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
                WHERE v.type = 'programmé' AND v.matricule_agent = %s
                ORDER BY v.date_heure DESC
            """, (matricule_agent,))
            return cursor.fetchall()
        finally:
            conn.close()

    def get_by_agent(self, matricule_agent: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT v.id_vente, v.id_ligne, v.date_heure, v.type,
                       v.statut, v.id_appareil, v.code_agence,
                       v.matricule_agent,
                       l.nom_ligne, l.point_depart, l.point_arrive
                FROM billetterie.vente v
                JOIN base_global.ligne l ON v.id_ligne = l.id_ligne
                WHERE v.matricule_agent = %s
                ORDER BY v.date_heure DESC
            """, (matricule_agent,))
            return cursor.fetchall()
        finally:
            conn.close()

    def delete(self, id_vente: int) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE FROM billetterie.vente WHERE id_vente = %s", (id_vente,)
            )
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def cloturer(self, id_vente: int) -> str:
        now = _now()
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "UPDATE billetterie.vente SET statut='cloture', date_cloture=%s WHERE id_vente=%s",
                (now, id_vente)
            )
            conn.commit()
            return now
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def reopen(self, id_vente: int):
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "UPDATE billetterie.vente SET statut='actif', date_cloture=NULL WHERE id_vente=%s",
                (id_vente,)
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
            for id_vente in ids:
                cursor.execute(
                    """UPDATE billetterie.vente
                       SET statut='cloture', date_cloture=%s
                       WHERE id_vente=%s AND statut != 'cloture'""",
                    (now, id_vente)
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
            for id_vente in ids:
                cursor.execute(
                    """UPDATE billetterie.vente
                       SET statut='actif', date_cloture=NULL
                       WHERE id_vente=%s AND statut='cloture'""",
                    (id_vente,)
                )
                reopened += cursor.rowcount
            conn.commit()
            return reopened
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()