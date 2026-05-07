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
    code_agence: Optional[int] = None


class AgentUpdateData(BaseModel):
    nom: str
    prenom: str
    mot_de_passe: str = ""
    code_agence: Optional[int] = None


class AgentResponse(BaseModel):
    id: str
    matricule: str
    matricule_agent: int
    nom: str
    prenom: str
    code_agence: Optional[int] = None