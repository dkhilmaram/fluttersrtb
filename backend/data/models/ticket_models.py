from pydantic import BaseModel
from enum import Enum

class TypePassageSpecial(str, Enum):
    GRATUIT_ARMEE          = "Gratuit — Armée nationale"
    GRATUIT_GARDE          = "Gratuit — Garde nationale"
    GRATUIT_POLICE         = "Gratuit — Police nationale"
    GRATUIT_DOUANE         = "Gratuit — Douane"
    GRATUIT_MINISTERE      = "Gratuit — Ministère"
    GRATUIT_MUNICIPAL      = "Gratuit — Municipalité"
    GRATUIT_SCOLAIRE       = "Gratuit — Établissement scolaire"
    GRATUIT_AUTRE          = "Gratuit — Autre institution"
    ABONNEMENT             = "Abonnement"
    AGENT                  = "Agent"
    TITRE_NFC              = "Titre NFC"
    TITRE_BARCODE          = "Titre Code-barres"
    ABONNEMENT_MENSUEL     = "Abonnement Mensuel"
    ABONNEMENT_TRIMESTRIEL = "Abonnement Trimestriel"
    ABONNEMENT_ANNUEL      = "Abonnement Annuel"
    ABONNEMENT_ETUDIANT    = "Abonnement Étudiant"
    ABONNEMENT_RETRAITE    = "Abonnement Retraité"

class TicketVendreData(BaseModel):
    id_vente:        int
    id_segment:      int   = 0
    point_depart:    str
    point_arrivee:   str
    type_tarif:      str
    quantite:        int   = 1
    prix_unitaire:   float = 0.0
    montant_total:   float = 0.0
    matricule_agent: int
    metadata:        dict  = None