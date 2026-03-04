from fastapi import APIRouter
from pydantic import BaseModel
from passlib.context import CryptContext
from database import get_db

router = APIRouter()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

# ── Modèles ──
class LoginData(BaseModel):
    matricule: str        # ← keep as str, frontend doesn't change
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

# ── Login ──
@router.post("/login")
def login(data: LoginData):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT * FROM agent WHERE matricule_agent=%s AND mot_de_passe=%s",
        (data.matricule, data.mot_de_passe)
    )
    agent = cursor.fetchone()
    conn.close()

    if agent:
        return {"success": True, "employe": {
            "id": agent["matricule_agent"],
            "matricule": str(agent["matricule_agent"]),
            "matricule_agent": agent["matricule_agent"],  # ← added so VoyageProgrammePage finds it
            "nom": agent["nom"],
            "prenom": agent["prenom"]
        }}
    return {"success": False}

# ── Ajouter un agent ──
@router.post("/ajouter_agent")
def ajouter_agent(data: AgentData):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO agent (matricule_agent, mot_de_passe, nom, prenom) VALUES (%s, %s, %s, %s)",
            (data.matricule, data.mot_de_passe, data.nom, data.prenom)
        )
        conn.commit()
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()

# ── Liste des agents ──
@router.get("/agents")
def get_agents():
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT matricule_agent, nom, prenom FROM agent")
    agents = cursor.fetchall()
    conn.close()
    return {"success": True, "agents": agents}

# ── Supprimer un agent ──
@router.delete("/supprimer_agent/{matricule}")
def supprimer_agent(matricule: str):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM agent WHERE matricule_agent=%s", (matricule,))
        conn.commit()
        return {"success": True, "message": "Agent supprimé"}
    except Exception as e:
        return {"success": False, "message": str(e)}
    finally:
        conn.close()

# ── Modifier un agent ──
@router.put("/modifier_agent/{matricule}")
def modifier_agent(matricule: str, data: AgentUpdateData):
    conn = get_db()
    cursor = conn.cursor()
    try:
        if data.mot_de_passe:
            cursor.execute(
                "UPDATE agent SET nom=%s, prenom=%s, mot_de_passe=%s WHERE matricule_agent=%s",
                (data.nom, data.prenom, data.mot_de_passe, matricule)
            )
        else:
            cursor.execute(
                "UPDATE agent SET nom=%s, prenom=%s WHERE matricule_agent=%s",
                (data.nom, data.prenom, matricule)
            )
        conn.commit()
        return {"success": True, "message": "Agent modifié"}
    except Exception as e:
        return {"success": False, "message": str(e)}
    finally:
        conn.close()