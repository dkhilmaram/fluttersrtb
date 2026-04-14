from core.database import get_db

class AgentRepository:

    def find_by_matricule(self, matricule: str) -> dict | None:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                "SELECT * FROM agent WHERE matricule_agent = %s",
                (matricule,)
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def create(self, matricule: str, hashed_password: str, nom: str, prenom: str) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "INSERT INTO agent (matricule_agent, mot_de_passe, nom, prenom) VALUES (%s, %s, %s, %s)",
                (matricule, hashed_password, nom, prenom)
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
            cursor.execute("SELECT matricule_agent, nom, prenom FROM agent")
            return cursor.fetchall()
        finally:
            conn.close()

    def delete(self, matricule: str) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute("DELETE FROM agent WHERE matricule_agent = %s", (matricule,))
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def update(self, matricule: str, nom: str, prenom: str, hashed_password: str | None = None) -> bool:
        conn = get_db()
        cursor = conn.cursor()
        try:
            if hashed_password:
                cursor.execute(
                    "UPDATE agent SET nom=%s, prenom=%s, mot_de_passe=%s WHERE matricule_agent=%s",
                    (nom, prenom, hashed_password, matricule)
                )
            else:
                cursor.execute(
                    "UPDATE agent SET nom=%s, prenom=%s WHERE matricule_agent=%s",
                    (nom, prenom, matricule)
                )
            conn.commit()
            return cursor.rowcount > 0
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()