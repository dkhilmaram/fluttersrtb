from core.database import get_db
import datetime


class NfcCardRepository:

    def find_by_uid(self, uid: str) -> dict | None:
        conn   = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    card_uid,
                    nom,
                    type,
                    expire,
                    ligne,
                    organisme
                FROM billetterie.nfc_cards
                WHERE card_uid = %s
                """,
                (uid.upper().strip(),),
            )
            row = cursor.fetchone()
            if row is None:
                return None

            print(f"[NFC] raw expire = {repr(row.get('expire'))}")
            row["expire"] = _to_iso(row.get("expire"))
            print(f"[NFC] normalised expire = {repr(row['expire'])}")
            return row
        finally:
            cursor.close()
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
        conn   = get_db()
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
            cursor.close()
            conn.close()

    def list_all(self) -> list[dict]:
        conn   = get_db()
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(
                """
                SELECT
                    card_uid,
                    nom,
                    type,
                    expire,
                    ligne,
                    organisme,
                    created_at
                FROM billetterie.nfc_cards
                ORDER BY created_at DESC
                """
            )
            rows = cursor.fetchall()
            for row in rows:
                row["expire"] = _to_iso(row.get("expire"))
            return rows
        finally:
            cursor.close()
            conn.close()


# ── helper ────────────────────────────────────────────────────────────────────

def _to_iso(value) -> str:
    """
    Convert whatever MySQL returns for a date column into YYYY-MM-DD.

    Handles:
      - datetime.date       →  '2026-12-31'
      - datetime.datetime   →  '2026-12-31'
      - str '2026-12-31'    →  '2026-12-31'   (already correct)
      - str '2026-12-31 00:00:00'  →  '2026-12-31'
      - None / ''           →  ''
    """
    if value is None:
        return ""
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.strftime("%Y-%m-%d")
    s = str(value).strip()
    if not s:
        return ""
    # If stored as 'YYYY-MM-DD HH:MM:SS', keep only the date part
    return s[:10]