from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()

class ScanLogRequest(BaseModel):
    id_voyage:       int
    id_segment:      int
    scan_mode:       str
    numero_titre:    str
    nom_titulaire:   str
    type_abonnement: str
    organisme:       str
    ligne_titre:     str
    expire:          str
    date_scan:       str
    matricule_agent: int

@router.post("/scan/log")
async def log_scan(data: ScanLogRequest):
    print(f"📡 Scan log: {data.scan_mode} — {data.numero_titre} — {data.nom_titulaire}")
    return {"success": True}