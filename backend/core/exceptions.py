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
    def __init__(self, id_ticket):
        super().__init__(status_code=404, detail=f"Ticket #{id_ticket} introuvable")


class TicketDejaScanne(HTTPException):
    def __init__(self, identifier=None, scanned_at=None):
        if scanned_at:
            detail = f"Ce ticket a déjà été scanné le {scanned_at}."
        else:
            detail = "Ce ticket a déjà été scanné."
        super().__init__(status_code=409, detail=detail)


class LigneIncompatible(HTTPException):
    """
    Raised when a sold ticket belongs to a different ligne than the
    current voyage.  Accepts either:
      - LigneIncompatible(ticket_ligne="X", current_ligne="Y")   ← service style
      - LigneIncompatible(detail="custom message")               ← direct style
      - LigneIncompatible()                                      ← generic fallback
    """

    def __init__(
        self,
        detail: str = None,
        ticket_ligne: str = None,
        current_ligne: str = None,
    ):
        if detail is None:
            if ticket_ligne and current_ligne:
                detail = (
                    f"Ligne du ticket\u00a0: {ticket_ligne}\n"
                    f"Ligne du voyage\u00a0: {current_ligne}"
                )
            else:
                detail = "Ligne incompatible avec ce voyage"
        super().__init__(status_code=409, detail=detail)