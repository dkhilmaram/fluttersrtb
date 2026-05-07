from fastapi import HTTPException

class AgentNotFound(HTTPException):
    def __init__(self):
        super().__init__(status_code=404, detail="Agent introuvable")

class VoyageNotFound(HTTPException):
    def __init__(self):
        super().__init__(status_code=404, detail="Voyage introuvable")

class VoyageDejaClôturé(HTTPException):
    def __init__(self):
        super().__init__(status_code=409, detail="Voyage déjà clôturé")

class VoyageDejaActif(HTTPException):
    def __init__(self):
        super().__init__(status_code=409, detail="Voyage déjà actif")

class SegmentIntrouvable(HTTPException):
    def __init__(self):
        super().__init__(status_code=404, detail="Aucun segment trouvé pour ce voyage")

class PrixInvalide(HTTPException):
    def __init__(self, type_tarif: str):
        super().__init__(
            status_code=422,
            detail=f"Passage spécial '{type_tarif}' doit avoir prix=0"
        )

class TicketIntrouvable(HTTPException):
    def __init__(self, id_ticket: int):
        super().__init__(status_code=404, detail=f"Ticket #{id_ticket} introuvable")

class TicketDejaScanne(HTTPException):
    def __init__(self):
        super().__init__(status_code=409, detail="Ce ticket a déjà été scanné")

class LigneIncompatible(HTTPException):
    def __init__(self, detail: str = "Ligne incompatible avec ce voyage"):
        super().__init__(status_code=409, detail=detail)