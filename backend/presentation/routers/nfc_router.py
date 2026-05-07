from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator
from data.repositories.nfc_card_repository import NfcCardRepository

router = APIRouter(tags=["NFC Cards"])
_repo  = NfcCardRepository()


# ── Lookup ────────────────────────────────────────────────────────────────────

@router.get("/nfc/lookup/{uid}")
def lookup_nfc_card(uid: str):
    card = _repo.find_by_uid(uid)
    if not card:
        raise HTTPException(
            status_code=404,
            detail=f"Carte NFC '{uid}' non enregistrée",
        )
    return {
        "found":     True,
        "id":        card["card_uid"],
        "nom":       card["nom"],
        "type":      card["type"],
        "expire":    card["expire"],   # guaranteed YYYY-MM-DD string
        "ligne":     card["ligne"],
        "organisme": card["organisme"],
    }


# ── Register ──────────────────────────────────────────────────────────────────

class NfcCardRequest(BaseModel):
    card_uid:  str
    nom:       str
    type:      str
    expire:    str          # expected YYYY-MM-DD
    ligne:     str
    organisme: str

    @field_validator("expire")
    @classmethod
    def validate_expire(cls, v: str) -> str:
        """Reject bad date strings at the API boundary."""
        from datetime import date
        try:
            date.fromisoformat(v)
        except ValueError:
            raise ValueError(
                f"'expire' must be a valid ISO date (YYYY-MM-DD), got: '{v}'"
            )
        return v


@router.post("/nfc/register")
def register_nfc_card(data: NfcCardRequest):
    try:
        _repo.register(
            card_uid=  data.card_uid,
            nom=       data.nom,
            type=      data.type,
            expire=    data.expire,
            ligne=     data.ligne,
            organisme= data.organisme,
        )
        return {"success": True, "card_uid": data.card_uid.upper()}
    except Exception as e:
        if "Duplicate entry" in str(e):
            raise HTTPException(
                status_code=409,
                detail=f"Carte '{data.card_uid}' déjà enregistrée",
            )
        raise HTTPException(status_code=500, detail=str(e))


# ── List all ──────────────────────────────────────────────────────────────────

@router.get("/nfc/cards")
def list_nfc_cards():
    cards = _repo.list_all()
    return {"success": True, "total": len(cards), "cards": cards}