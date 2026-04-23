from core.database import get_db
from datetime import datetime

def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

class TicketRepository:

    def create(
        self,
        id_voyage,
        id_segment,
        point_depart,
        point_arrivee,
        type_tarif,
        quantite,
        prix_unitaire,
        montant_total,
        matricule_agent,
        sync_status = "online",   # ← new parameter, defaults to 'online' for safety
    ) -> int:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                INSERT INTO billetterie.ticket_vendu
                (id_voyage, id_segment, point_depart, point_arrivee,
                 type_tarif, quantite, prix_unitaire, montant_total,
                 date_heure, matricule_agent, sync_status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
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
                sync_status,      # ← now actually saved to MySQL
            ))
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
            cursor.execute("""
                SELECT t.id_ticket, t.point_depart, t.point_arrivee,
                       t.type_tarif, t.quantite, t.prix_unitaire,
                       t.montant_total, t.date_heure, t.id_segment,
                       t.sync_status,
                       sv.ordre AS segment_ordre,
                       l.nom_ligne, a.nom, a.prenom
                FROM billetterie.ticket_vendu t
                LEFT JOIN billetterie.segment_voyage sv ON t.id_segment     = sv.id_segment
                LEFT JOIN billetterie.voyage          v  ON t.id_voyage      = v.id_voyage
                LEFT JOIN base_global.ligne           l  ON v.id_ligne       = l.id_ligne
                LEFT JOIN base_global.agent           a  ON t.matricule_agent = a.matricule_agent
                WHERE t.id_voyage = %s ORDER BY t.date_heure DESC
            """, (id_voyage,))
            return cursor.fetchall()
        finally:
            conn.close()

    def get_special_stats(self, id_voyage: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT type_tarif,
                       COUNT(*)      AS count,
                       SUM(quantite) AS total_quantite
                FROM billetterie.ticket_vendu
                WHERE id_voyage = %s AND prix_unitaire = 0
                GROUP BY type_tarif ORDER BY count DESC
            """, (id_voyage,))
            return cursor.fetchall()
        finally:
            conn.close()