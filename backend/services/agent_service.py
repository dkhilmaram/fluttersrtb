from data.repositories.agent_repository import AgentRepository
from core.security import hash_password, verify_password
from core.exceptions import AgentNotFound


class AgentService:
    def __init__(self):
        self.repo = AgentRepository()

    def login(self, matricule: str, mot_de_passe: str) -> dict | None:
        agent = self.repo.find_by_matricule(matricule)
        if agent and verify_password(mot_de_passe, agent["mot_de_passe"]):
            return {
                "id":              agent["matricule_agent"],
                "matricule":       str(agent["matricule_agent"]),
                "matricule_agent": agent["matricule_agent"],
                "nom":             agent["nom"],
                "prenom":          agent["prenom"],
                "code_agence":     agent.get("code_agence"),
            }
        return None

    def create(
        self,
        matricule: str,
        mot_de_passe: str,
        nom: str,
        prenom: str,
        code_agence: int | None = None,   # ← was missing
    ):
        hashed = hash_password(mot_de_passe)
        self.repo.create(matricule, hashed, nom, prenom, code_agence)

    def list_all(self):
        return self.repo.list_all()

    def delete(self, matricule: str):
        deleted = self.repo.delete(matricule)
        if not deleted:
            raise AgentNotFound()

    def update(
        self,
        matricule: str,
        nom: str,
        prenom: str,
        mot_de_passe: str = "",
        code_agence: int | None = None,   # ← was missing
    ):
        hashed = hash_password(mot_de_passe) if mot_de_passe else None
        self.repo.update(matricule, nom, prenom, hashed, code_agence)