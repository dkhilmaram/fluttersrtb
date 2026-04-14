from data.repositories.segment_repository import SegmentRepository

class SegmentService:
    def __init__(self):
        self.repo = SegmentRepository()

    def get_arrets(self, id_vente: int) -> dict:
        segments = self.repo.get_arrets(id_vente)
        if not segments:
            return {"success": False, "arrets": [], "message": "Aucun segment trouvé"}
        arrets = [s["point_depart"] for s in segments]
        arrets.append(segments[-1]["point_arrivee"])
        return {"success": True, "arrets": arrets}

    def get_segment_actif(self, id_vente: int) -> dict:
        segment = self.repo.get_actif(id_vente)
        if not segment:
            prochain = self.repo.get_prochain_en_attente(id_vente)
            return {
                "success":       True,
                "segment":       None,
                "prochain":      self._fmt_prochain(prochain) if prochain else None,
                "tous_clotures": prochain is None,
            }
        prochain = self.repo.get_prochain_en_attente(id_vente, after_ordre=segment["ordre"])
        return {
            "success":       True,
            "segment":       self._fmt_seg(segment),
            "prochain":      self._fmt_prochain(prochain) if prochain else None,
            "tous_clotures": False,
        }

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
                    "statut":          s["statut"],
                    "id_ligne":        s["id_ligne"],
                    "nom_ligne":       s["nom_ligne"],
                    "matricule_agent": s["matricule_agent"],
                    "agent_nom":       f"{s['prenom']} {s['nom']}" if s["nom"] else None,
                    "date_ouverture":  str(s["date_ouverture"]) if s["date_ouverture"] else None,
                    "date_cloture":    str(s["date_cloture"])   if s["date_cloture"]   else None,
                }
                for s in rows
            ],
        }

    def get_prix_ligne(self, id_ligne: int) -> dict:
        result = self.repo.get_prix_ligne(id_ligne)
        if result:
            return {"success": True, "prix": result["prix"],
                    "point_depart": result["point_depart"], "point_arrive": result["point_arrive"]}
        return {"success": False, "message": "Ligne introuvable"}

    def get_tarifs_ligne(self, id_ligne: int) -> dict:
        segments, tarif_types = self.repo.get_tarifs_ligne(id_ligne)
        prix_map = {}
        for s in segments:
            prix_map[f"{s['point_a']}|{s['point_b']}"] = s["prix_normal"]
            prix_map[f"{s['point_b']}|{s['point_a']}"] = s["prix_normal"]
        return {"success": True, "arrets": [], "prix_map": prix_map, "tarif_types": tarif_types}

    def _fmt_seg(self, s: dict) -> dict:
        return {
            "id_segment":     s["id_segment"],
            "point_depart":   s["point_depart"],
            "point_arrivee":  s["point_arrivee"],
            "ordre":          s["ordre"],
            "statut":         s["statut"],
            "date_ouverture": str(s["date_ouverture"]) if s.get("date_ouverture") else None,
            "date_cloture":   str(s["date_cloture"])   if s.get("date_cloture")   else None,
        }

    def _fmt_prochain(self, s: dict) -> dict:
        return {
            "id_segment":    s["id_segment"],
            "point_depart":  s["point_depart"],
            "point_arrivee": s["point_arrivee"],
            "ordre":         s["ordre"],
        }