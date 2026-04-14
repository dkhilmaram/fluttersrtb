from core.database import get_db

class SegmentRepository:

    def get_arrets(self, id_vente: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT point_depart, point_arrivee, ordre
                FROM billetterie.segment_voyage
                WHERE id_vente = %s ORDER BY ordre ASC
            """, (id_vente,))
            return cursor.fetchall()
        finally:
            conn.close()

    def get_actif(self, id_vente: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT * FROM billetterie.segment_voyage
                WHERE id_vente = %s AND statut = 'actif'
                ORDER BY ordre LIMIT 1
            """, (id_vente,))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_prochain_en_attente(self, id_vente: int, after_ordre: int = -1) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT * FROM billetterie.segment_voyage
                WHERE id_vente = %s AND statut = 'en_attente' AND ordre > %s
                ORDER BY ordre LIMIT 1
            """, (id_vente, after_ordre))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_last(self, id_vente: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT * FROM billetterie.segment_voyage
                WHERE id_vente = %s ORDER BY ordre DESC LIMIT 1
            """, (id_vente,))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_all(self, id_vente: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT sv.id_segment, sv.point_depart, sv.point_arrivee,
                       sv.ordre, sv.statut,
                       sv.date_ouverture, sv.date_cloture,
                       v.id_ligne, v.matricule_agent,
                       l.nom_ligne, a.nom, a.prenom
                FROM billetterie.segment_voyage sv
                JOIN  billetterie.vente   v ON sv.id_vente       = v.id_vente
                JOIN  base_global.ligne   l ON v.id_ligne        = l.id_ligne
                LEFT JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
                WHERE sv.id_vente = %s ORDER BY sv.ordre
            """, (id_vente,))
            return cursor.fetchall()
        finally:
            conn.close()

    def get_prix_ligne(self, id_ligne: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT l.point_depart, l.point_arrive, b.prix
                FROM base_global.ligne l
                JOIN billetterie.billet b ON l.id_billet = b.id_billet
                WHERE l.id_ligne = %s
            """, (id_ligne,))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_tarifs_ligne(self, id_ligne: int) -> tuple[list, list]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT point_a, point_b, prix_normal
                FROM billetterie.tarif_segment WHERE id_ligne = %s
            """, (id_ligne,))
            segments = cursor.fetchall()
            cursor.execute(
                "SELECT type_tarif, pourcentage FROM billetterie.type_tarif ORDER BY pourcentage DESC"
            )
            tarif_types = cursor.fetchall()
            return segments, tarif_types
        finally:
            conn.close()