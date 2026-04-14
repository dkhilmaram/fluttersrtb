from data.repositories.ticket_repository import TicketRepository
from data.repositories.segment_repository import SegmentRepository
from core.exceptions import SegmentIntrouvable, PrixInvalide

_SPECIAL_KEYWORDS = [
    "Gratuit", "Armée", "Armee", "Garde", "Police", "Douane",
    "Ministère", "Ministere", "Municipalité", "Municipalite",
    "Scolaire", "Institution", "Autre", "Abonnement",
    "Agent", "NFC", "Barcode", "Scan",
]

def is_special_passage(type_tarif: str) -> bool:
    return any(kw.lower() in type_tarif.lower() for kw in _SPECIAL_KEYWORDS)

class TicketService:
    def __init__(self):
        self.repo    = TicketRepository()
        self.seg_repo = SegmentRepository()

    def vendre(self, data: dict) -> int:
        type_tarif    = data.get("type_tarif", "")
        prix_unitaire = float(data.get("prix_unitaire", 0))
        montant_total = float(data.get("montant_total", 0))
        id_vente      = data.get("id_vente")
        id_segment    = data.get("id_segment", 0)

        # Validate special passage pricing
        if is_special_passage(type_tarif) and (prix_unitaire != 0 or montant_total != 0):
            raise PrixInvalide(type_tarif)

        # Resolve segment if not provided
        if id_segment == 0:
            seg = self.seg_repo.get_actif(id_vente)
            if seg:
                id_segment = seg["id_segment"]
            else:
                last = self.seg_repo.get_last(id_vente)
                if last:
                    id_segment = last["id_segment"]
                else:
                    raise SegmentIntrouvable()

        return self.repo.create(
            id_vente      = id_vente,
            id_segment    = id_segment,
            point_depart  = data.get("point_depart"),
            point_arrivee = data.get("point_arrivee"),
            type_tarif    = type_tarif,
            quantite      = int(data.get("quantite", 1)),
            prix_unitaire = prix_unitaire,
            montant_total = montant_total,
            matricule_agent = data.get("matricule_agent"),
        )

    def get_by_voyage(self, id_vente: int):
        rows = self.repo.get_by_voyage(id_vente)
        return [
            {
                **r,
                "date_heure": str(r["date_heure"]),
                "agent":      f"{r['prenom']} {r['nom']}" if r["nom"] else None,
                "is_free":    is_special_passage(r["type_tarif"] or ""),
            }
            for r in rows
        ]

    def get_special_stats(self, id_vente: int):
        return self.repo.get_special_stats(id_vente)