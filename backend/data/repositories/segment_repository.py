from core.database import get_db

class SegmentRepository:

    def get_arrets(self, id_voyage: int) -> list[dict]:
        """Reconstruct ordered stop list from segment_voyage rows."""
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT point_depart AS nom_arret, ordre
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s
                ORDER BY ordre ASC
            """, (id_voyage,))
            rows = cursor.fetchall()
            if not rows:
                return []

            arrets = [{"nom_arret": r["nom_arret"], "ordre": r["ordre"]} for r in rows]

            cursor.execute("""
                SELECT point_arrivee AS nom_arret, ordre + 1 AS ordre
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s
                ORDER BY ordre DESC LIMIT 1
            """, (id_voyage,))
            last = cursor.fetchone()
            if last:
                arrets.append(last)

            return arrets
        finally:
            conn.close()

    def get_last(self, id_voyage: int) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT id_segment, point_depart, point_arrivee, ordre
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s ORDER BY ordre DESC LIMIT 1
            """, (id_voyage,))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_actif(self, id_voyage: int) -> dict | None:
        """Return the current active segment for a vente (last by ordre)."""
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT id_segment, point_depart, point_arrivee, ordre
                FROM billetterie.segment_voyage
                WHERE id_voyage = %s
                ORDER BY ordre DESC LIMIT 1
            """, (id_voyage,))
            return cursor.fetchone()
        finally:
            conn.close()

    def get_all(self, id_voyage: int) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT sv.id_segment, sv.point_depart, sv.point_arrivee, sv.ordre,
                       v.id_ligne, v.matricule_agent,
                       l.nom_ligne, a.nom, a.prenom
                FROM billetterie.segment_voyage sv
                JOIN  billetterie.voyage     v  ON sv.id_voyage        = v.id_voyage
                JOIN  base_global.ligne     l  ON v.id_ligne         = l.id_ligne
                LEFT JOIN base_global.agent a  ON v.matricule_agent  = a.matricule_agent
                WHERE sv.id_voyage = %s
                ORDER BY sv.ordre
            """, (id_voyage,))
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

    def copy_segments_from_ligne(self, id_voyage: int, id_ligne: int) -> int:
        """
        Copy the template segments (id_voyage IS NULL) for a given ligne
        into segment_voyage rows linked to the new voyage.
        Returns the number of segments copied.
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            # Fetch template segments for this ligne
            cursor.execute("""
                SELECT id_ligne, point_depart, point_arrivee, ordre
                FROM billetterie.segment_voyage
                WHERE id_ligne = %s AND id_voyage IS NULL
                ORDER BY ordre ASC
            """, (id_ligne,))
            templates = cursor.fetchall()

            if not templates:
                return 0

            for seg in templates:
                cursor.execute("""
                    INSERT INTO billetterie.segment_voyage
                        (id_voyage, id_ligne, point_depart, point_arrivee, ordre)
                    VALUES (%s, %s, %s, %s, %s)
                """, (
                    id_voyage,
                    seg['id_ligne'],
                    seg['point_depart'],
                    seg['point_arrivee'],
                    seg['ordre'],
                ))

            conn.commit()
            return len(templates)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()