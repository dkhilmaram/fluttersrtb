from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class HeartbeatPayload(BaseModel):
    matricule_agent: int
    pending_count: int = 0
    failed_count: int = 0
    last_sync_at: Optional[datetime] = None
    app_version: Optional[str] = None


class HeartbeatRow(BaseModel):
    matricule_agent: int
    prenom: Optional[str] = None
    nom: Optional[str] = None
    pending_count: int = 0
    failed_count: int = 0
    last_sync_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    seconds_ago: Optional[int] = None
    tickets_today: int = 0
    recette_today_ms: int = 0
    