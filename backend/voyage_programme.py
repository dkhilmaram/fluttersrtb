from fastapi import APIRouter
from pydantic import BaseModel
from database import get_db
from datetime import datetime
from enum import Enum

router = APIRouter()

# ── Modèles ──
class VenteData(BaseModel):
    matricule_agent: int
    id_ligne: int
    id_appareil: int
    id_billet: int
    date_heure: str
    code_agence: int
    type: str

class TypePassageSpecial(str, Enum):
    """Types of special passages (institutions, NFC, subscriptions)"""
    # Institutions — all prefixed with "Gratuit — " from the Flutter app
    GRATUIT_ARMEE      = "Gratuit — Armée nationale"
    GRATUIT_GARDE      = "Gratuit — Garde nationale"
    GRATUIT_POLICE     = "Gratuit — Police nationale"
    GRATUIT_DOUANE     = "Gratuit — Douane"
    GRATUIT_MINISTERE  = "Gratuit — Ministère"
    GRATUIT_MUNICIPAL  = "Gratuit — Municipalité"
    GRATUIT_SCOLAIRE   = "Gratuit — Établissement scolaire"
    GRATUIT_AUTRE      = "Gratuit — Autre institution"
    # Special types (no prefix)
    ABONNEMENT         = "Abonnement"
    AGENT              = "Agent"
    # Scan types (formatted as "Scan <mode> — <subtype>")
    TITRE_NFC          = "Titre NFC"
    TITRE_BARCODE      = "Titre Code-barres"
    # Legacy / generic
    ABONNEMENT_MENSUEL      = "Abonnement Mensuel"
    ABONNEMENT_TRIMESTRIEL  = "Abonnement Trimestriel"
    ABONNEMENT_ANNUEL       = "Abonnement Annuel"
    ABONNEMENT_ETUDIANT     = "Abonnement Étudiant"
    ABONNEMENT_RETRAITE     = "Abonnement Retraité"

class TicketSpecialData(BaseModel):
    """Enhanced ticket data with metadata support"""
    id_vente:         int
    id_segment:       int   = 0
    point_depart:     str
    point_arrivee:    str
    type_tarif:       str   # Use enum or free string
    quantite:         int   = 1
    prix_unitaire:    float = 0.0   # Always 0 for special passages
    montant_total:    float = 0.0   # Always 0 for special passages
    matricule_agent:  int
    metadata:         dict  = None  # e.g. {"institution": "Armée", "card_id": "ABC123"}


# ── FIX 3: All keywords that identify a zero-price special passage ──
_SPECIAL_KEYWORDS = [
    # Gratuit prefix (used by Flutter for all institution types)
    "Gratuit",
    # Individual institution names (fallback if prefix is missing)
    "Armée", "Armee",
    "Garde",
    "Police",
    "Douane",
    "Ministère", "Ministere",
    "Municipalité", "Municipalite",
    "Scolaire",
    "Institution",
    "Autre",
    # Special types
    "Abonnement",
    "Agent",
    # Scan / NFC / barcode
    "NFC",
    "Barcode",
    "Scan",
]

def _is_special_passage(type_tarif: str) -> bool:
    """Return True if the ticket type should always have prix=0."""
    return any(kw.lower() in type_tarif.lower() for kw in _SPECIAL_KEYWORDS)


# ── Ajouter une vente ──
@router.post("/ajouter_vente")
def ajouter_vente(data: VenteData):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """INSERT INTO billetterie.vente
               (id_ligne, id_appareil, id_billet, date_heure, matricule_agent, code_agence, type)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (data.id_ligne, data.id_appareil, data.id_billet,
             data.date_heure, data.matricule_agent, data.code_agence, data.type)
        )
        conn.commit()
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ── Ventes programmées pour un agent spécifique ──
@router.get("/ventes/programmees/{matricule_agent}")
def get_ventes_programmees(matricule_agent: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT v.id_vente, v.id_ligne, v.id_appareil, v.id_billet,
               v.date_heure, v.type, v.statut,
               v.matricule_agent, v.code_agence,
               l.nom_ligne, l.point_depart, l.point_arrive,
               a.nom, a.prenom
        FROM billetterie.vente v
        JOIN base_global.ligne l ON v.id_ligne = l.id_ligne
        JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
        WHERE v.type = 'programmé' AND v.matricule_agent = %s
        ORDER BY v.date_heure DESC
    """, (matricule_agent,))
    ventes = cursor.fetchall()
    conn.close()
    return {"voyages": [
        {
            "id":               v["id_vente"],
            "id_ligne":         v["id_ligne"],
            "id_appareil":      v["id_appareil"],
            "id_billet":        v["id_billet"],
            "matricule_agent":  v["matricule_agent"],
            "code_agence":      v["code_agence"],
            "depart":           v["point_depart"],
            "arrivee":          v["point_arrive"],
            "nom_ligne":        v["nom_ligne"],
            "date_heure":       str(v["date_heure"]),
            "statut":           v["statut"],
        }
        for v in ventes
    ]}


# ── Ventes d'un seul agent ──
@router.get("/ventes/agent/{matricule_agent}")
def get_ventes_agent(matricule_agent: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT v.id_vente, v.id_ligne, v.date_heure, v.type,
               l.nom_ligne, l.point_depart, l.point_arrive
        FROM billetterie.vente v
        JOIN base_global.ligne l ON v.id_ligne = l.id_ligne
        WHERE v.matricule_agent = %s
        ORDER BY v.date_heure
    """, (matricule_agent,))
    ventes = cursor.fetchall()
    conn.close()
    return {"voyages": [
        {
            "id":        v["id_vente"],
            "id_ligne":  v["id_ligne"],
            "depart":    v["point_depart"],
            "arrivee":   v["point_arrive"],
            "nom_ligne": v["nom_ligne"],
            "date_heure": str(v["date_heure"]),
            "type":      v["type"],
        }
        for v in ventes
    ]}


# ── Supprimer une vente ──
@router.delete("/supprimer_vente/{vente_id}")
def supprimer_vente(vente_id: int):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "DELETE FROM billetterie.vente WHERE id_vente=%s", (vente_id,))
        conn.commit()
        return {"success": True, "message": "Vente supprimée"}
    except Exception as e:
        return {"success": False, "message": str(e)}
    finally:
        conn.close()


# ── Prix d'une ligne ──
@router.get("/ligne/{id_ligne}/prix")
def get_prix_ligne(id_ligne: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT l.point_depart, l.point_arrive, b.prix
        FROM base_global.ligne l
        JOIN billetterie.billet b ON l.id_billet = b.id_billet
        WHERE l.id_ligne = %s
    """, (id_ligne,))
    result = cursor.fetchone()
    conn.close()
    if result:
        return {"success": True, "prix": result["prix"],
                "point_depart": result["point_depart"],
                "point_arrive": result["point_arrive"]}
    return {"success": False, "message": "Ligne introuvable"}


# ── Tarifs d'une ligne ──
@router.get("/ligne/{id_ligne}/tarifs")
def get_tarifs_ligne(id_ligne: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("""
        SELECT nom_arret FROM billetterie.arret
        WHERE id_ligne = %s ORDER BY ordre
    """, (id_ligne,))
    arrets = [r["nom_arret"] for r in cursor.fetchall()]

    cursor.execute("""
        SELECT point_a, point_b, prix_normal
        FROM billetterie.tarif_segment
        WHERE id_ligne = %s
    """, (id_ligne,))
    segments = cursor.fetchall()

    prix_map = {}
    for s in segments:
        prix_map[f"{s['point_a']}|{s['point_b']}"] = s["prix_normal"]
        prix_map[f"{s['point_b']}|{s['point_a']}"] = s["prix_normal"]

    cursor.execute(
        "SELECT type_tarif, pourcentage FROM billetterie.type_tarif "
        "ORDER BY pourcentage DESC"
    )
    tarif_types = cursor.fetchall()

    conn.close()
    return {
        "success":     True,
        "arrets":      arrets,
        "prix_map":    prix_map,
        "tarif_types": tarif_types,
    }


# ── Vérifier le statut d'un voyage ──
@router.get("/vente/{id_vente}/statut")
def get_statut_voyage(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT statut FROM billetterie.vente WHERE id_vente = %s",
        (id_vente,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return {"success": True, "statut": row["statut"]}
    return {"success": False, "message": "Voyage introuvable"}


# ── Clôturer un voyage ──
@router.put("/vente/{id_vente}/cloturer")
def cloturer_voyage(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT * FROM billetterie.vente WHERE id_vente = %s",
            (id_vente,))
        vente = cursor.fetchone()
        if not vente:
            return {"success": False, "message": "Voyage introuvable"}
        if vente["statut"] == "cloture":
            return {"success": False, "message": "Voyage déjà clôturé"}
        cursor.execute(
            "UPDATE billetterie.vente SET statut = 'cloture' "
            "WHERE id_vente = %s", (id_vente,))
        conn.commit()
        return {"success": True, "message": "Voyage clôturé"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ── Segment actif d'un voyage ──
@router.get("/voyages/{id_vente}/segment/actif")
def get_segment_actif(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT * FROM billetterie.segment_voyage
        WHERE id_vente = %s AND statut = 'actif'
        ORDER BY ordre LIMIT 1
    """, (id_vente,))
    segment = cursor.fetchone()

    if not segment:
        cursor.execute("""
            SELECT * FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut = 'en_attente'
            ORDER BY ordre LIMIT 1
        """, (id_vente,))
        prochain = cursor.fetchone()
        conn.close()
        return {
            "success":      True,
            "segment":      None,
            "prochain": {
                "id_segment":    prochain["id_segment"],
                "point_depart":  prochain["point_depart"],
                "point_arrivee": prochain["point_arrivee"],
                "ordre":         prochain["ordre"],
            } if prochain else None,
            "tous_clotures": prochain is None,
        }

    cursor.execute("""
        SELECT * FROM billetterie.segment_voyage
        WHERE id_vente = %s AND ordre > %s AND statut = 'en_attente'
        ORDER BY ordre LIMIT 1
    """, (id_vente, segment["ordre"]))
    prochain = cursor.fetchone()
    conn.close()

    return {
        "success": True,
        "segment": {
            "id_segment":     segment["id_segment"],
            "point_depart":   segment["point_depart"],
            "point_arrivee":  segment["point_arrivee"],
            "ordre":          segment["ordre"],
            "statut":         segment["statut"],
            "date_ouverture": str(segment["date_ouverture"])
                              if segment["date_ouverture"] else None,
        },
        "prochain": {
            "id_segment":    prochain["id_segment"],
            "point_depart":  prochain["point_depart"],
            "point_arrivee": prochain["point_arrivee"],
            "ordre":         prochain["ordre"],
        } if prochain else None,
        "tous_clotures": False,
    }


# ── Ouvrir le prochain segment ──
@router.put("/voyages/{id_vente}/segment/ouvrir")
def ouvrir_segment(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT id_segment FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut = 'actif'
        """, (id_vente,))
        if cursor.fetchone():
            return {"success": False,
                    "message": "Clôturez le segment actif avant d'ouvrir le suivant"}

        cursor.execute("""
            SELECT id_segment FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut = 'en_attente'
            ORDER BY ordre LIMIT 1
        """, (id_vente,))
        row = cursor.fetchone()
        if not row:
            return {"success": False, "message": "Aucun segment disponible"}

        cursor.execute("""
            UPDATE billetterie.segment_voyage
            SET statut = 'actif', date_ouverture = %s
            WHERE id_segment = %s
        """, (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), row["id_segment"]))
        conn.commit()
        return {"success": True, "message": "Segment ouvert"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ── Clôturer un segment ──
@router.put("/voyages/{id_vente}/segments/{id_segment}/cloturer")
def cloturer_segment(id_vente: int, id_segment: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT statut FROM billetterie.segment_voyage
            WHERE id_segment = %s AND id_vente = %s
        """, (id_segment, id_vente))
        row = cursor.fetchone()
        if not row:
            return {"success": False, "message": "Segment introuvable"}
        if row["statut"] != "actif":
            return {"success": False,
                    "message": "Ce segment n'est pas actif"}

        cursor.execute("""
            UPDATE billetterie.segment_voyage
            SET statut = 'cloture', date_cloture = %s
            WHERE id_segment = %s
        """, (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), id_segment))
        conn.commit()
        return {"success": True, "message": "Segment clôturé"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ── Tous les segments d'un voyage ──
@router.get("/voyages/{id_vente}/segments")
def get_segments(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT sv.id_segment, sv.point_depart, sv.point_arrivee,
               sv.ordre, sv.statut,
               sv.date_ouverture, sv.date_cloture,
               v.id_ligne, v.matricule_agent,
               l.nom_ligne,
               a.nom, a.prenom
        FROM billetterie.segment_voyage sv
        JOIN  billetterie.vente v  ON sv.id_vente = v.id_vente
        JOIN  base_global.ligne l  ON v.id_ligne  = l.id_ligne
        LEFT JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
        WHERE sv.id_vente = %s
        ORDER BY sv.ordre
    """, (id_vente,))
    segments = cursor.fetchall()
    conn.close()
    return {"success": True, "segments": [
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
        for s in segments
    ]}


# ── ENHANCED: Enregistrer un ticket vendu (with special passage validation) ──
@router.post("/tickets/vendre")
def vendre_ticket(data: dict):
    conn = get_db()
    cursor = conn.cursor()
    try:
        id_vente      = data.get("id_vente")
        id_segment    = data.get("id_segment", 0)
        type_tarif    = data.get("type_tarif", "")
        prix_unitaire = float(data.get("prix_unitaire", 0))
        montant_total = float(data.get("montant_total", 0))
        quantite      = int(data.get("quantite", 1))

        # ── FIX 3: Use the widened helper to detect all special passage types ──
        is_special = _is_special_passage(type_tarif)

        if is_special:
            # Enforce zero pricing for all special passages
            if prix_unitaire != 0 or montant_total != 0:
                return {
                    "success": False,
                    "error":   f"Passage spécial '{type_tarif}' doit avoir prix=0",
                }

        # ── Handle id_segment=0 (offline tickets saved without active segment) ──
        if id_segment == 0:
            # Try to find the currently active segment for this voyage
            cursor.execute("""
                SELECT id_segment FROM billetterie.segment_voyage
                WHERE id_vente = %s AND statut = 'actif'
                ORDER BY ordre LIMIT 1
            """, (id_vente,))
            row = cursor.fetchone()

            if row:
                id_segment = row[0]
            else:
                # Fall back to the last segment (closed or last in sequence)
                cursor.execute("""
                    SELECT id_segment FROM billetterie.segment_voyage
                    WHERE id_vente = %s
                    ORDER BY ordre DESC LIMIT 1
                """, (id_vente,))
                row = cursor.fetchone()
                if row:
                    id_segment = row[0]
                else:
                    return {"success": False,
                            "error": "Aucun segment trouvé pour ce voyage"}

        # ── Insert the ticket with resolved id_segment ──
        cursor.execute("""
            INSERT INTO billetterie.ticket_vendu
            (id_vente, id_segment, point_depart, point_arrivee,
             type_tarif, quantite, prix_unitaire, montant_total,
             date_heure, matricule_agent)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            id_vente,
            id_segment,
            data.get("point_depart"),
            data.get("point_arrivee"),
            type_tarif,
            quantite,
            prix_unitaire,
            montant_total,
            datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            data.get("matricule_agent"),
        ))
        conn.commit()

        last_id       = cursor.lastrowid
        passage_label = "Gratuit/Spécial" if is_special else "Ticket normal"
        print(
            f"✅ {passage_label} saved: id={last_id}, voyage={id_vente}, "
            f"segment={id_segment}, type={type_tarif}, qty={quantite}"
        )

        return {"success": True, "id_ticket": last_id}

    except Exception as e:
        print(f"❌ Ticket save error: {e}")
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ── CLEAN: Historique tickets d'un voyage (LEFT JOINs to handle NULL segment) ──
@router.get("/voyages/{id_vente}/tickets")
def get_tickets_voyage(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT t.id_ticket, t.point_depart, t.point_arrivee,
               t.type_tarif, t.quantite, t.prix_unitaire,
               t.montant_total, t.date_heure,
               t.id_segment,
               sv.ordre AS segment_ordre,
               l.nom_ligne,
               a.nom, a.prenom
        FROM billetterie.ticket_vendu t
        LEFT JOIN billetterie.segment_voyage sv ON t.id_segment = sv.id_segment
        LEFT JOIN billetterie.vente v           ON t.id_vente   = v.id_vente
        LEFT JOIN base_global.ligne l           ON v.id_ligne   = l.id_ligne
        LEFT JOIN base_global.agent a           ON t.matricule_agent = a.matricule_agent
        WHERE t.id_vente = %s
        ORDER BY t.date_heure DESC
    """, (id_vente,))
    rows = cursor.fetchall()
    conn.close()
    return {"success": True, "tickets": [
        {
            "id_ticket":     r["id_ticket"],
            "point_depart":  r["point_depart"],
            "point_arrivee": r["point_arrivee"],
            "type_tarif":    r["type_tarif"],
            "quantite":      r["quantite"],
            "prix_unitaire": r["prix_unitaire"],
            "montant_total": r["montant_total"],
            "date_heure":    str(r["date_heure"]),
            "segment_ordre": r["segment_ordre"],
            "nom_ligne":     r["nom_ligne"],
            "agent":         f"{r['prenom']} {r['nom']}" if r["nom"] else None,
            # FIX 3: use helper for consistent is_free detection
            "is_free":       _is_special_passage(r["type_tarif"] or ""),
        }
        for r in rows
    ]}


# ── Statistics on special passages (Gratuit / NFC / Abonnement / Agent) ──
@router.get("/voyages/{id_vente}/passages-speciaux/stats")
def get_special_passages_stats(id_vente: int):
    """Statistics on free/special passages for a voyage."""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT
            type_tarif,
            COUNT(*)       AS count,
            SUM(quantite)  AS total_quantite
        FROM billetterie.ticket_vendu
        WHERE id_vente = %s AND prix_unitaire = 0
        GROUP BY type_tarif
        ORDER BY count DESC
    """, (id_vente,))
    stats = cursor.fetchall()
    conn.close()
    return {
        "success":  True,
        "id_vente": id_vente,
        "passages_speciaux": [
            {
                "type":             s["type_tarif"],
                "nombre":           s["count"],
                "quantite_totale":  s["total_quantite"],
            }
            for s in stats
        ],
    }