from data.repositories.segment_repository import SegmentRepository

class SegmentService:
    def __init__(self):
        self.repo = SegmentRepository()

    def get_arrets(self, id_vente: int) -> dict:
        arrets = self.repo.get_arrets(id_vente)
        if not arrets:
            return {"success": False, "arrets": [], "message": "Aucun arrêt trouvé"}
        return {"success": True, "arrets": [a["nom_arret"] for a in arrets]}

    def get_all_segments(self, id_vente: int) -> dict:
        rows = self.repo.get_all(id_vente)
        return {
            "success": True,
            "segments": [
                {
                    "id_segment":      s["id_segment"],
                    "point_depart":    s["point_depart"],
                    "point_arrivee":   s["point_arrivee"],
                    "ordre":           s["ordre"],
                    "id_ligne":        s["id_ligne"],
                    "nom_ligne":       s["nom_ligne"],
                    "matricule_agent": s["matricule_agent"],
                    "agent_nom": f"{s['prenom']} {s['nom']}" if s["nom"] else None,
                }
                for s in rows
            ],
        }

    def get_prix_ligne(self, id_ligne: int) -> dict:
        result = self.repo.get_prix_ligne(id_ligne)
        if result:
            return {
                "success": True,
                "prix": result["prix"],
                "point_depart": result["point_depart"],
                "point_arrive": result["point_arrive"],
            }
        return {"success": False, "message": "Ligne introuvable"}

    def get_tarifs_ligne(self, id_ligne: int) -> dict:
        segments, tarif_types = self.repo.get_tarifs_ligne(id_ligne)
        prix_map = {}
        for s in segments:
            prix_map[f"{s['point_a']}|{s['point_b']}"] = s["prix_normal"]
            prix_map[f"{s['point_b']}|{s['point_a']}"] = s["prix_normal"]
        return {"success": True, "arrets": [], "prix_map": prix_map, "tarif_types": tarif_types}