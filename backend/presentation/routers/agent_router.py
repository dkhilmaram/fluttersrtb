from fastapi import APIRouter
from data.models.agent_models import LoginData, AgentData, AgentUpdateData
from services.agent_service import AgentService

router = APIRouter(tags=["Auth"])
_svc = AgentService()


@router.post("/login")
def login(data: LoginData):
    agent = _svc.login(data.matricule, data.mot_de_passe)
    if agent:
        return {"success": True, "employe": agent}
    return {"success": False}


@router.post("/agents")
def create_agent(data: AgentData):
    _svc.create(
        data.matricule,
        data.mot_de_passe,
        data.nom,
        data.prenom,
        data.code_agence,
    )
    return {"success": True}


@router.get("/agents")
def list_agents():
    return {"agents": _svc.list_all()}


@router.delete("/agents/{matricule}")
def delete_agent(matricule: str):
    _svc.delete(matricule)
    return {"success": True}


@router.put("/agents/{matricule}")
def update_agent(matricule: str, data: AgentUpdateData):
    _svc.update(
        matricule,
        data.nom,
        data.prenom,
        data.mot_de_passe,
        data.code_agence,
    )
    return {"success": True}