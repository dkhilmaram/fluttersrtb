from pydantic import BaseModel

class VenteData(BaseModel):
    matricule_agent: int
    id_ligne:        int
    id_appareil:     int
    date_heure:      str
    code_agence:     int | None = None
    type:            str

class ClotureJourneeData(BaseModel):
    ids: list[int]

class ReopenJourneeData(BaseModel):
    ids: list[int]