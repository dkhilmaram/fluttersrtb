from fastapi import APIRouter
from data.models.vente_models import VenteData, ClotureJourneeData, ReopenJourneeData
from services.vente_service import VenteService
from services.segments_service import SegmentService

router = APIRouter(tags=["Ventes"])
_svc     = VenteService()
_seg_svc = SegmentService()

@router.post("/ajouter_vente")
def ajouter_vente(data: VenteData):
    id_vente = _svc.create(data)
    return {"success": True, "id_vente": id_vente}

@router.get("/ventes/programmees/{matricule_agent}")
def get_ventes_programmees(matricule_agent: int):
    return {"voyages": _svc.get_programmees(matricule_agent)}

@router.get("/ventes/agent/{matricule_agent}")
def get_ventes_agent(matricule_agent: int):
    return {"voyages": _svc.get_by_agent(matricule_agent)}

@router.delete("/supprimer_vente/{vente_id}")
def supprimer_vente(vente_id: int):
    _svc.delete(vente_id)
    return {"success": True, "message": "Vente supprimée"}

@router.get("/vente/{id_vente}/statut")
def get_statut(id_vente: int):
    return {"success": True, "statut": _svc.get_statut(id_vente)}

@router.put("/vente/{id_vente}/cloturer")
def cloturer(id_vente: int):
    date_cloture = _svc.cloturer(id_vente)
    return {"success": True, "message": "Voyage clôturé", "date_cloture": date_cloture}

@router.put("/vente/{id_vente}/reopen")
def reopen(id_vente: int):
    _svc.reopen(id_vente)
    return {"success": True, "message": "Voyage réouvert"}

@router.put("/ventes/cloturer-journee")
def cloturer_journee(data: ClotureJourneeData):
    if not data.ids:
        return {"success": False, "message": "Aucun id fourni"}
    closed = _svc.bulk_cloturer(data.ids)
    return {"success": True, "closed": closed}

@router.put("/ventes/reopen-journee")
def reopen_journee(data: ReopenJourneeData):
    if not data.ids:
        return {"success": False, "message": "Aucun id fourni"}
    reopened = _svc.bulk_reopen(data.ids)
    return {"success": True, "reopened": reopened}

@router.get("/ligne/{id_ligne}/prix")
def get_prix_ligne(id_ligne: int):
    return _seg_svc.get_prix_ligne(id_ligne)

@router.get("/ligne/{id_ligne}/tarifs")
def get_tarifs_ligne(id_ligne: int):
    return _seg_svc.get_tarifs_ligne(id_ligne)