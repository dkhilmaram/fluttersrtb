from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import mysql.connector
from passlib.context import CryptContext

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Bcrypt ──
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

# ── Connexion MySQL ──
def get_db():
    return mysql.connector.connect(
        host="localhost",
        port=3306,
        user="root",
        password="",
        database="srtb_db"
    )

# ── Modèles ──
class LoginData(BaseModel):
    matricule: str
    mot_de_passe: str

class EmployeData(BaseModel):
    matricule: str
    mot_de_passe: str
    nom: str
    prenom: str

class EmployeUpdateData(BaseModel):
    nom: str
    prenom: str
    mot_de_passe: str = ""

# ── Login ──
@app.post("/login")
def login(data: LoginData):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM employes WHERE matricule=%s", (data.matricule,))
    employe = cursor.fetchone()
    conn.close()
    if employe and verify_password(data.mot_de_passe, employe["mot_de_passe"]):
        return {"success": True, "employe": {
            "id": employe["id"],
            "matricule": employe["matricule"],
            "nom": employe["nom"],
            "prenom": employe["prenom"]
        }}
    return {"success": False, "message": "Matricule ou mot de passe incorrect"}

# ── Ajouter un employé ──
@app.post("/ajouter_employe")
def ajouter_employe(data: EmployeData):
    conn = get_db()
    cursor = conn.cursor()
    hashed = hash_password(data.mot_de_passe)
    try:
        cursor.execute(
            "INSERT INTO employes (matricule, mot_de_passe, nom, prenom) VALUES (%s, %s, %s, %s)",
            (data.matricule, hashed, data.nom, data.prenom)
        )
        conn.commit()
        conn.close()
        return {"success": True, "message": "Employé ajouté avec succès"}
    except:
        conn.close()
        return {"success": False, "message": "Matricule déjà existant"}

# ── Liste des employés ──
@app.get("/employes")
def get_employes():
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, matricule, nom, prenom FROM employes")
    employes = cursor.fetchall()
    conn.close()
    return {"success": True, "employes": employes}

# ── Supprimer un employé ──
@app.delete("/supprimer_employe/{matricule}")
def supprimer_employe(matricule: str):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM employes WHERE matricule=%s", (matricule,))
        conn.commit()
        conn.close()
        return {"success": True, "message": "Employé supprimé"}
    except Exception as e:
        conn.close()
        return {"success": False, "message": str(e)}

# ── Modifier un employé ──
@app.put("/modifier_employe/{matricule}")
def modifier_employe(matricule: str, data: EmployeUpdateData):
    conn = get_db()
    cursor = conn.cursor()
    try:
        if data.mot_de_passe:
            hashed = hash_password(data.mot_de_passe)
            cursor.execute(
                "UPDATE employes SET nom=%s, prenom=%s, mot_de_passe=%s WHERE matricule=%s",
                (data.nom, data.prenom, hashed, matricule)
            )
        else:
            cursor.execute(
                "UPDATE employes SET nom=%s, prenom=%s WHERE matricule=%s",
                (data.nom, data.prenom, matricule)
            )
        conn.commit()
        conn.close()
        return {"success": True, "message": "Employé modifié"}
    except Exception as e:
        conn.close()
        return {"success": False, "message": str(e)}