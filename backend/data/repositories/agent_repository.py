from core.database import get_db


class AgentRepository:

    def find_by_matricule(self, matricule: str) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT
                    a.matricule_agent,
                    a.mot_de_passe,
                    a.nom,
                    a.prenom,
                    a.code_agence
                FROM agent a
                WHERE a.matricule_agent = %s
            """, (matricule,))
            return cursor.fetchone()
        finally:
            conn.close()

    def create(self, matricule: str, hashed_password: str,
               nom: str, prenom: str,
               code_agence: int | None = None) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """INSERT INTO agent
                   (matricule_agent, mot_de_passe, nom, prenom, code_agence)
                   VALUES (%s, %s, %s, %s, %s)""",
                (matricule, hashed_password, nom, prenom, code_agence),
            )
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def list_all(self) -> list[dict]:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT matricule_agent, nom, prenom, code_agence FROM agent"
            )
            return cursor.fetchall()
        finally:
            conn.close()

    def delete(self, matricule: str) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "DELETE FROM agent WHERE matricule_agent = %s",
                (matricule,),
            )
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def update(self, matricule: str, nom: str, prenom: str,
               hashed_password: str | None = None,
               code_agence: int | None = None) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            if hashed_password:
                cursor.execute(
                    """UPDATE agent
                       SET nom=%s, prenom=%s, mot_de_passe=%s, code_agence=%s
                       WHERE matricule_agent=%s""",
                    (nom, prenom, hashed_password, code_agence, matricule),
                )
            else:
                cursor.execute(
                    """UPDATE agent
                       SET nom=%s, prenom=%s, code_agence=%s
                       WHERE matricule_agent=%s""",
                    (nom, prenom, code_agence, matricule),
                )
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()