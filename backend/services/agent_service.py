from data.repositories.agent_repository import AgentRepository
from core.security import hash_password, verify_password
from core.exceptions import AgentNotFound

ALLOWED_ROLES = {"receveur"}

class AgentService:
    def __init__(self):
        self.repo = AgentRepository()

    def login(self, matricule: str, mot_de_passe: str) -> tuple[dict | None, str]:
        """
        Returns (agent_dict, error_code).
        error_code: "" | "not_found" | "wrong_password" | "role_denied"
        """
        agent = self.repo.find_by_matricule(matricule)
        print(f"🔍 AGENT FROM DB: {agent}")

        if not agent:
            print("❌ No agent found with this matricule")
            return None, "not_found"

        if not verify_password(mot_de_passe, agent["mot_de_passe"]):
            print("❌ Wrong password")
            return None, "wrong_password"

        role = (agent.get("role") or "").strip().lower()
        print(f"🔍 ROLE CHECK: agent role='{role}' expected={ALLOWED_ROLES}")

        if role not in ALLOWED_ROLES:
            print(f"❌ Access denied — role '{role}' is not allowed")
            return None, "role_denied"

        print(f"✅ Login success for matricule {agent['matricule_agent']}")
        return {
            "id":              agent["matricule_agent"],
            "matricule":       str(agent["matricule_agent"]),
            "matricule_agent": agent["matricule_agent"],
            "nom":             agent["nom"],
            "prenom":          agent["prenom"],
            "role":            agent["role"],
            "code_agence":     agent.get("code_agence"),
        }, ""

    def create(
        self,
        matricule: str,
        mot_de_passe: str,
        nom: str,
        prenom: str,
        role: str = "receveur",
        code_agence: int | None = None,
    ):
        hashed = hash_password(mot_de_passe)
        self.repo.create(matricule, hashed, nom, prenom, role, code_agence)

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
        role: str = "receveur",
        code_agence: int | None = None,
    ):
        hashed = hash_password(mot_de_passe) if mot_de_passe else None
        self.repo.update(matricule, nom, prenom, hashed, role, code_agence)