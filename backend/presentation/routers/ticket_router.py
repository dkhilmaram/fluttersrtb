from fastapi import APIRouter
from services.ticket_service import TicketService

router = APIRouter(tags=["Tickets"])
_svc = TicketService()

@router.post("/tickets/vendre")
def vendre_ticket(data: dict):
    # Guard: enforce valid sync_status before it reaches the service
    # Flutter sends 'online' (real-time sale) or 'synced' (was offline, now pushing)
    if data.get("sync_status") not in ("online", "synced"):
        data["sync_status"] = "online"

    id_ticket = _svc.vendre(data)
    return {"success": True, "id_ticket": id_ticket}

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
            {"type": s["type_tarif"], "nombre": s["count"], "quantite_totale": s["total_quantite"]}
            for s in stats
        ],
    }