from fastapi import APIRouter
from data.models.agent_models import LoginData
from services.agent_service import AgentService

router = APIRouter(tags=["Auth"])
_svc = AgentService()

@router.post("/login")
def login(data: LoginData):
    agent = _svc.login(data.matricule, data.mot_de_passe)
    if agent:
        return {"success": True, "employe": agent}
    return {"success": False}