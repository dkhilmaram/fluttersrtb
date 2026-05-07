from fastapi import APIRouter
from data.models.vente_models import VenteData, ClotureJourneeData, ReopenJourneeData
from services.vente_service import VenteService
from services.segments_service import SegmentService

router = APIRouter(tags=["Ventes"])
_svc     = VenteService()
_seg_svc = SegmentService()

@router.post("/ajouter_vente")
def ajouter_vente(data: VenteData):
    id_voyage = _svc.create(data)
    return {"success": True, "id_voyage": id_voyage}

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

@router.get("/vente/{id_voyage}/statut")
def get_statut(id_voyage: int):
    return {"success": True, "statut": _svc.get_statut(id_voyage)}

@router.put("/vente/{id_voyage}/cloturer")
def cloturer(id_voyage: int):
    date_cloture = _svc.cloturer(id_voyage)
    return {"success": True, "message": "Voyage clôturé", "date_cloture": date_cloture}

@router.put("/vente/{id_voyage}/reopen")
def reopen(id_voyage: int):
    _svc.reopen(id_voyage)
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

# ─────────────────────────────────────────────────────────────
# NEW — list lines by agence (used by Flutter "Ajouter voyage")
# ─────────────────────────────────────────────────────────────
@router.get("/lignes/agence/{code_agence}")
def get_lignes_by_agence(code_agence: int):
    """
    Returns all lines for a given agence code.
    Called by the Flutter bottom sheet when the receveur wants
    to open a non-scheduled voyage.
    """
    lignes = _svc.get_lignes_by_agence(code_agence)
    return {"success": True, "lignes": lignes}
@router.post("/ventes/creer")
def creer_voyage(data: VenteData):
    id_voyage = _svc.create(data)
    return {"success": True, "id_voyage": id_voyage}