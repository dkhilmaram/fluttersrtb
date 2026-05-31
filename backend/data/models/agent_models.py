from pydantic import BaseModel
from typing import Optional


class LoginData(BaseModel):
    matricule: str
    mot_de_passe: str


class AgentData(BaseModel):
    matricule: str
    mot_de_passe: str
    nom: str
    prenom: str
    role: str = "receveur"
    code_agence: Optional[int] = None


class AgentUpdateData(BaseModel):
    nom: str
    prenom: str
    mot_de_passe: str = ""
    role: str = "receveur"
    code_agence: Optional[int] = None


class AgentResponse(BaseModel):
    id: str
    matricule: str
    matricule_agent: int
    nom: str
    prenom: str
    role: str
    code_agence: Optional[int] = None