from fastapi import APIRouter
from services.ticket_service import TicketService

router = APIRouter(tags=["Tickets"])
_svc = TicketService()

@router.post("/tickets/vendre")
def vendre_ticket(data: dict):
    id_ticket = _svc.vendre(data)
    return {"success": True, "id_ticket": id_ticket}

@router.get("/voyages/{id_vente}/tickets")
def get_tickets(id_vente: int):
    return {"success": True, "tickets": _svc.get_by_voyage(id_vente)}

@router.get("/voyages/{id_vente}/passages-speciaux/stats")
def get_special_stats(id_vente: int):
    stats = _svc.get_special_stats(id_vente)
    return {
        "success": True,
        "id_vente": id_vente,
        "passages_speciaux": [
            {"type": s["type_tarif"], "nombre": s["count"], "quantite_totale": s["total_quantite"]}
            for s in stats
        ],
    }