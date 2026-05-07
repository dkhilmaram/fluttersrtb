from fastapi import APIRouter, HTTPException
from services.ticket_service import TicketService
from core.exceptions import (
    SegmentIntrouvable,
    PrixInvalide,
    TicketIntrouvable,
    TicketDejaScanne,
    LigneIncompatible,
)

router = APIRouter(tags=["Tickets"])
_svc = TicketService()


@router.post("/tickets/vendre")
def vendre_ticket(data: dict):
    if data.get("sync_status") not in ("online", "synced"):
        data["sync_status"] = "online"

    try:
        result = _svc.vendre(data)
        # Return both id_ticket AND numero_titre so Flutter can confirm
        # which ID was actually stored (useful when Flutter omits the field
        # and the server generates a fallback).
        return {
            "success":       True,
            "id_ticket":     result["id_ticket"],
            "numero_titre":  result["numero_titre"],
        }
    except PrixInvalide as e:
        raise HTTPException(status_code=422, detail=str(e))
    except SegmentIntrouvable:
        raise HTTPException(status_code=404, detail="Segment introuvable pour ce voyage.")


@router.get("/voyages/{id_voyage}/tickets")
def get_tickets(id_voyage: int):
    return {"success": True, "tickets": _svc.get_by_voyage(id_voyage)}


@router.get("/voyages/{id_voyage}/passages-speciaux/stats")
def get_special_stats(id_voyage: int):
    stats = _svc.get_special_stats(id_voyage)
    return {
        "success": True,
        "id_voyage": id_voyage,
        "passages_speciaux": [
            {
                "type":             s["type_tarif"],
                "nombre":           s["count"],
                "quantite_totale":  s["total_quantite"],
            }
            for s in stats
        ],
    }


# ── Sold-ticket QR: verify by integer id_ticket (legacy) ─────────────────────

@router.get("/tickets/{id_ticket}/verify")
def verify_ticket(id_ticket: int, id_voyage_courant: int):
    """
    Verify by integer PK (legacy / server-generated QR).
    Does NOT mark the ticket as scanned.
    """
    try:
        info = _svc.verify_ticket(id_ticket, id_voyage_courant)
        return {"success": True, "ticket": info}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except LigneIncompatible as e:
        raise HTTPException(status_code=409, detail=str(e))


@router.post("/tickets/{id_ticket}/scan")
def mark_ticket_scanned(id_ticket: int, data: dict):
    """
    Validate/scan by integer PK (legacy).
    Body: { "id_voyage_courant": <int> }
    """
    id_voyage_courant = data.get("id_voyage_courant")
    if not id_voyage_courant:
        raise HTTPException(status_code=422, detail="id_voyage_courant est requis.")

    try:
        result = _svc.mark_ticket_scanned(id_ticket, id_voyage_courant)
        return {"success": True, "ticket": result}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except TicketDejaScanne as e:
        raise HTTPException(status_code=409, detail=str(e))
    except LigneIncompatible as e:
        raise HTTPException(status_code=409, detail=str(e))


# ── Sold-ticket QR: verify by string numero_titre (NouveauTicketPage) ────────

@router.get("/tickets/verify-by-numero/{numero_titre:path}")
def verify_ticket_by_numero(numero_titre: str, id_voyage_courant: int):
    """
    Verify by client-generated numero_titre (NouveauTicketPage QR format).
    Does NOT mark the ticket as scanned.

    Query params:
      id_voyage_courant — agent's current voyage ID

    Error codes:
      404 — no ticket found with this numero_titre
      409 — ligne mismatch
    """
    try:
        info = _svc.verify_ticket_by_numero(numero_titre, id_voyage_courant)
        return {"success": True, "ticket": info}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except LigneIncompatible as e:
        raise HTTPException(status_code=409, detail=str(e))


@router.post("/tickets/by-numero/{numero_titre:path}/scan")
def mark_ticket_scanned_by_numero(numero_titre: str, data: dict):
    """
    Validate/scan by client-generated numero_titre.
    Body: { "id_voyage_courant": <int> }

    Error codes:
      404 — ticket not found
      409 — ligne mismatch OR already scanned
    """
    id_voyage_courant = data.get("id_voyage_courant")
    if not id_voyage_courant:
        raise HTTPException(status_code=422, detail="id_voyage_courant est requis.")

    try:
        result = _svc.mark_ticket_scanned_by_numero(numero_titre, id_voyage_courant)
        return {"success": True, "ticket": result}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except TicketDejaScanne as e:
        raise HTTPException(status_code=409, detail=str(e))
    except LigneIncompatible as e:
        raise HTTPException(status_code=409, detail=str(e))