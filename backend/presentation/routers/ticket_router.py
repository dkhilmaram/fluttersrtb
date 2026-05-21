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

    On ligne mismatch (409), the full ticket data is ALWAYS included in the
    response body under the `ticket` key so the Flutter client can display
    all fields even when the ligne is wrong.
    """
    try:
        info = _svc.verify_ticket(id_ticket, id_voyage_courant)
        return {"success": True, "ticket": info}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except LigneIncompatible as e:
        # ── KEY FIX: fetch the full ticket row so the client can render it ──
        # We fetch without the voyage filter (passing the ticket's own voyage)
        # to get all fields, then let the client overlay the ligne_invalide flag.
        ticket_data = None
        try:
            row = _svc.repo.get_ticket_for_verification(id_ticket)
            if row is not None:
                ticket_data = _svc._build_ticket_response(row)
        except Exception:
            pass  # If this fails, the client falls back to QR payload fields

        raise HTTPException(
            status_code=409,
            detail={
                "detail": str(e),
                "ticket": ticket_data,  # always present when ticket exists
            },
        )


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
        ticket_data = None
        try:
            row = _svc.repo.get_ticket_for_verification(id_ticket)
            if row is not None:
                ticket_data = _svc._build_ticket_response(row)
        except Exception:
            pass
        raise HTTPException(
            status_code=409,
            detail={
                "detail": str(e),
                "ticket": ticket_data,
            },
        )


# ── Sold-ticket QR: verify by string numero_titre (NouveauTicketPage) ────────

@router.get("/tickets/verify-by-numero/{numero_titre:path}")
def verify_ticket_by_numero(numero_titre: str, id_voyage_courant: int):
    """
    Verify by client-generated numero_titre (NouveauTicketPage QR format).
    Does NOT mark the ticket as scanned.

    On ligne mismatch (409), the full ticket data is ALWAYS included in the
    response body under the `ticket` key.
    """
    try:
        info = _svc.verify_ticket_by_numero(numero_titre, id_voyage_courant)
        return {"success": True, "ticket": info}
    except TicketIntrouvable as e:
        raise HTTPException(status_code=404, detail=str(e))
    except LigneIncompatible as e:
        ticket_data = None
        try:
            row = _svc.repo.get_ticket_by_numero(numero_titre)
            if row is not None:
                ticket_data = _svc._build_ticket_response(row)
        except Exception:
            pass
        raise HTTPException(
            status_code=409,
            detail={
                "detail": str(e),
                "ticket": ticket_data,
            },
        )


@router.post("/tickets/by-numero/{numero_titre:path}/scan")
def mark_ticket_scanned_by_numero(numero_titre: str, data: dict):
    """
    Validate/scan by client-generated numero_titre.
    Body: { "id_voyage_courant": <int> }
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
        ticket_data = None
        try:
            row = _svc.repo.get_ticket_by_numero(numero_titre)
            if row is not None:
                ticket_data = _svc._build_ticket_response(row)
        except Exception:
            pass
        raise HTTPException(
            status_code=409,
            detail={
                "detail": str(e),
                "ticket": ticket_data,
            },
        )