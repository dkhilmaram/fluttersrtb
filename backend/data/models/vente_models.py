from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class VenteData(BaseModel):
    matricule_agent: int
    id_ligne:        int
    id_appareil:     Optional[int] = 0       # was `int` (required) → now optional, defaults to 0
    code_agence:     Optional[int] = None
    type:            Optional[str] = 'spontané'
    date_heure:      Optional[str] = None

    # Flutter sends these — ignored by DB but must not cause 422
    depart:    Optional[str] = None
    arrivee:   Optional[str] = None
    nom_ligne: Optional[str] = None
    id_billet: Optional[int] = None
    statut:    Optional[str] = None

    def model_post_init(self, __context):
        if not self.date_heure:
            self.date_heure = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        # Ensure id_appareil is never None so the DB INSERT never gets NULL
        if self.id_appareil is None:
            self.id_appareil = 0


class ClotureJourneeData(BaseModel):
    ids: list[int]


class ReopenJourneeData(BaseModel):
    ids: list[int]