from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from data.repositories.nfc_card_repository import NfcCardRepository

router = APIRouter(tags=["NFC Cards"])
_repo = NfcCardRepository()


@router.get("/nfc/lookup/{uid}")
def lookup_nfc_card(uid: str):
    card = _repo.find_by_uid(uid)
    if not card:
        raise HTTPException(
            status_code=404,
            detail=f"Carte NFC '{uid}' non enregistrée"
        )
    return {
        "found":     True,
        "id":        card["card_uid"],
        "nom":       card["nom"],
        "type":      card["type"],
        "expire":    card["expire"],
        "ligne":     card["ligne"],
        "organisme": card["organisme"],
    }


class NfcCardRequest(BaseModel):
    card_uid:  str
    nom:       str
    type:      str
    expire:    str
    ligne:     str
    organisme: str


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
                detail=f"Carte '{data.card_uid}' déjà enregistrée"
            )
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/nfc/cards")
def list_nfc_cards():
    cards = _repo.list_all()
    return {"success": True, "total": len(cards), "cards": cards}