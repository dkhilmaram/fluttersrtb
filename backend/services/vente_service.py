from data.repositories.vente_repository import VenteRepository
from core.exceptions import VoyageNotFound, VoyageDejaClôturé, VoyageDejaActif

class VenteService:
    def __init__(self):
        self.repo = VenteRepository()

    def create(self, data) -> int:
        return self.repo.create(data)

    def get_programmees(self, matricule_agent: int):
        rows = self.repo.get_programmees(matricule_agent)
        return [
            {
                "id":              r["id_voyage"],
                "id_voyage":        r["id_voyage"],
                "id_ligne":        r["id_ligne"],
                "id_appareil":     r["id_appareil"],
                "matricule_agent": r["matricule_agent"],
                "code_agence":     r["code_agence"],
                "depart":          r["point_depart"],
                "arrivee":         r["point_arrive"],
                "nom_ligne":       r["nom_ligne"],
                "date_heure":      str(r["date_heure"]),
                "statut":          r["statut"],
            }
            for r in rows
        ]

    def get_by_agent(self, matricule_agent: int):
        rows = self.repo.get_by_agent(matricule_agent)
        return [
            {
                "id":              r["id_voyage"],
                "id_voyage":        r["id_voyage"],
                "id_ligne":        r["id_ligne"],
                "id_appareil":     r["id_appareil"],
                "code_agence":     r["code_agence"],
                "matricule_agent": r["matricule_agent"],
                "depart":          r["point_depart"],
                "arrivee":         r["point_arrive"],
                "nom_ligne":       r["nom_ligne"],
                "date_heure":      str(r["date_heure"]),
                "type":            r["type"],
                "statut":          r["statut"],
            }
            for r in rows
        ]

    def delete(self, id_voyage: int):
        self.repo.delete(id_voyage)

    def get_statut(self, id_voyage: int) -> str:
        statut = self.repo.get_statut(id_voyage)
        if statut is None:
            raise VoyageNotFound()
        return statut

    def cloturer(self, id_voyage: int) -> str:
        vente = self.repo.find_by_id(id_voyage)
        if not vente:
            raise VoyageNotFound()
        if vente["statut"] == "cloture":
            raise VoyageDejaClôturé()
        return self.repo.cloturer(id_voyage)

    def reopen(self, id_voyage: int):
        statut = self.repo.get_statut(id_voyage)
        if statut is None:
            raise VoyageNotFound()
        if statut != "cloture":
            raise VoyageDejaActif()
        self.repo.reopen(id_voyage)

    def bulk_cloturer(self, ids: list[int]) -> int:
        return self.repo.bulk_cloturer(ids)

    def bulk_reopen(self, ids: list[int]) -> int:
        return self.repo.bulk_reopen(ids)