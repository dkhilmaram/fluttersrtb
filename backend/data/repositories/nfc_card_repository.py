from core.database import get_db
from datetime import datetime


class NfcCardRepository:

    def find_by_uid(self, uid: str) -> dict | None:
        """
        Look up a pre-registered NFC card by its hardware UID.
        Returns a dict or None if not found.
        """
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    card_uid,
                    nom,
                    type,
                    DATE_FORMAT(expire, '%%Y-%%m-%%d') AS expire,
                    ligne,
                    organisme
                FROM billetterie.nfc_cards
                WHERE card_uid = %s
                """,
                (uid.upper().strip(),),
            )
            return cursor.fetchone()
        finally:
            conn.close()

    def register(
        self,
        card_uid:  str,
        nom:       str,
        type:      str,
        expire:    str,
        ligne:     str,
        organisme: str,
    ) -> bool:
        """
        Insert a new pre-registered NFC card.
        Returns True on success, raises on duplicate key.
        """
        conn = get_db()
        cursor = conn.cursor()
        try:
            cursor.execute(
                """
                INSERT INTO billetterie.nfc_cards
                    (card_uid, nom, type, expire, ligne, organisme)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    card_uid.upper().strip(),
                    nom,
                    type,
                    expire,
                    ligne,
                    organisme,
                ),
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
                """
                SELECT
                    card_uid,
                    nom,
                    type,
                    DATE_FORMAT(expire, '%%Y-%%m-%%d') AS expire,
                    ligne,
                    organisme,
                    created_at
                FROM billetterie.nfc_cards
                ORDER BY created_at DESC
                """
            )
            return cursor.fetchall()
        finally:
            conn.close()