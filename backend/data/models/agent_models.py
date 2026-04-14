from pydantic import BaseModel

class LoginData(BaseModel):
    matricule: str
    mot_de_passe: str

class AgentData(BaseModel):
    matricule: str
    mot_de_passe: str
    nom: str
    prenom: str

class AgentUpdateData(BaseModel):
    nom: str
    prenom: str
    mot_de_passe: str = ""

class AgentResponse(BaseModel):
    id: str
    matricule: str
    matricule_agent: int
    nom: str
    prenom: str