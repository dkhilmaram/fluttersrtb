from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_db
from datetime import datetime
from enum import Enum

router = APIRouter()


# ─────────────────────────────────────────────────────────────
# Models
# ─────────────────────────────────────────────────────────────

class VenteData(BaseModel):
    matricule_agent: int
    id_ligne:        int
    id_appareil:     int
    date_heure:      str
    code_agence:     int | None = None
    type:            str


class TypePassageSpecial(str, Enum):
    GRATUIT_ARMEE           = "Gratuit — Armée nationale"
    GRATUIT_GARDE           = "Gratuit — Garde nationale"
    GRATUIT_POLICE          = "Gratuit — Police nationale"
    GRATUIT_DOUANE          = "Gratuit — Douane"
    GRATUIT_MINISTERE       = "Gratuit — Ministère"
    GRATUIT_MUNICIPAL       = "Gratuit — Municipalité"
    GRATUIT_SCOLAIRE        = "Gratuit — Établissement scolaire"
    GRATUIT_AUTRE           = "Gratuit — Autre institution"
    ABONNEMENT              = "Abonnement"
    AGENT                   = "Agent"
    TITRE_NFC               = "Titre NFC"
    TITRE_BARCODE           = "Titre Code-barres"
    ABONNEMENT_MENSUEL      = "Abonnement Mensuel"
    ABONNEMENT_TRIMESTRIEL  = "Abonnement Trimestriel"
    ABONNEMENT_ANNUEL       = "Abonnement Annuel"
    ABONNEMENT_ETUDIANT     = "Abonnement Étudiant"
    ABONNEMENT_RETRAITE     = "Abonnement Retraité"


class TicketSpecialData(BaseModel):
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


# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

_SPECIAL_KEYWORDS = [
    "Gratuit", "Armée", "Armee", "Garde", "Police", "Douane",
    "Ministère", "Ministere", "Municipalité", "Municipalite",
    "Scolaire", "Institution", "Autre", "Abonnement",
    "Agent", "NFC", "Barcode", "Scan",
]

def _is_special_passage(type_tarif: str) -> bool:
    return any(kw.lower() in type_tarif.lower() for kw in _SPECIAL_KEYWORDS)

def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def _fmt_voyage_prog(v: dict) -> dict:
    """Serialize a programmé voyage row (no id_billet)."""
    return {
        "id":              v["id_vente"],
        "id_vente":        v["id_vente"],
        "id_ligne":        v["id_ligne"],
        "id_appareil":     v["id_appareil"],
        "matricule_agent": v["matricule_agent"],
        "code_agence":     v["code_agence"],
        "depart":          v["point_depart"],
        "arrivee":         v["point_arrive"],
        "nom_ligne":       v["nom_ligne"],
        "date_heure":      str(v["date_heure"]),
        "statut":          v["statut"],
    }

def _fmt_voyage_agent(v: dict) -> dict:
    """Serialize a voyage row from the agent endpoint (no id_billet)."""
    return {
        "id":              v["id_vente"],
        "id_vente":        v["id_vente"],
        "id_ligne":        v["id_ligne"],
        "id_appareil":     v["id_appareil"],
        "code_agence":     v["code_agence"],
        "matricule_agent": v["matricule_agent"],
        "depart":          v["point_depart"],
        "arrivee":         v["point_arrive"],
        "nom_ligne":       v["nom_ligne"],
        "date_heure":      str(v["date_heure"]),
        "type":            v["type"],
        "statut":          v["statut"],
    }


# ─────────────────────────────────────────────────────────────
# Ventes (voyages)
# ─────────────────────────────────────────────────────────────

@router.post("/ajouter_vente")
def ajouter_vente(data: VenteData):
    """Create a new vente (voyage). id_billet column no longer exists."""
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """INSERT INTO billetterie.vente
               (id_ligne, id_appareil, date_heure, matricule_agent, code_agence, type)
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (data.id_ligne, data.id_appareil, data.date_heure,
             data.matricule_agent, data.code_agence, data.type),
        )
        conn.commit()
        return {"success": True, "id_vente": cursor.lastrowid}
    except Exception as e:
        conn.rollback()
        print(f"❌ ajouter_vente: {e}")
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


@router.get("/ventes/programmees/{matricule_agent}")
def get_ventes_programmees(matricule_agent: int):
    """Return all programmé voyages for an agent, newest first."""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT v.id_vente, v.id_ligne, v.id_appareil,
                   v.date_heure, v.type, v.statut,
                   v.matricule_agent, v.code_agence,
                   l.nom_ligne, l.point_depart, l.point_arrive,
                   a.nom, a.prenom
            FROM billetterie.vente v
            JOIN  base_global.ligne  l ON v.id_ligne        = l.id_ligne
            LEFT JOIN base_global.agent  a ON v.matricule_agent = a.matricule_agent
            WHERE v.type = 'programmé' AND v.matricule_agent = %s
            ORDER BY v.date_heure DESC
        """, (matricule_agent,))
        ventes = cursor.fetchall()
        return {"voyages": [_fmt_voyage_prog(v) for v in ventes]}
    except Exception as e:
        print(f"❌ get_ventes_programmees: {e}")
        return {"voyages": [], "error": str(e)}
    finally:
        conn.close()


@router.get("/ventes/agent/{matricule_agent}")
def get_ventes_agent(matricule_agent: int):
    """Return ALL voyages for an agent (programmés + non programmés)."""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT v.id_vente, v.id_ligne, v.date_heure, v.type,
                   v.statut, v.id_appareil, v.code_agence,
                   v.matricule_agent,
                   l.nom_ligne, l.point_depart, l.point_arrive
            FROM billetterie.vente v
            JOIN base_global.ligne l ON v.id_ligne = l.id_ligne
            WHERE v.matricule_agent = %s
            ORDER BY v.date_heure DESC
        """, (matricule_agent,))
        ventes = cursor.fetchall()
        return {"voyages": [_fmt_voyage_agent(v) for v in ventes]}
    except Exception as e:
        print(f"❌ get_ventes_agent: {e}")
        return {"voyages": [], "error": str(e)}
    finally:
        conn.close()


@router.delete("/supprimer_vente/{vente_id}")
def supprimer_vente(vente_id: int):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "DELETE FROM billetterie.vente WHERE id_vente = %s", (vente_id,)
        )
        conn.commit()
        return {"success": True, "message": "Vente supprimée"}
    except Exception as e:
        conn.rollback()
        return {"success": False, "message": str(e)}
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# Ligne / tarifs
# ─────────────────────────────────────────────────────────────

@router.get("/ligne/{id_ligne}/prix")
def get_prix_ligne(id_ligne: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT l.point_depart, l.point_arrive, b.prix
            FROM base_global.ligne l
            JOIN billetterie.billet b ON l.id_billet = b.id_billet
            WHERE l.id_ligne = %s
        """, (id_ligne,))
        result = cursor.fetchone()
        if result:
            return {
                "success":       True,
                "prix":          result["prix"],
                "point_depart":  result["point_depart"],
                "point_arrive":  result["point_arrive"],
            }
        return {"success": False, "message": "Ligne introuvable"}
    except Exception as e:
        return {"success": False, "message": str(e)}
    finally:
        conn.close()


@router.get("/ligne/{id_ligne}/tarifs")
def get_tarifs_ligne(id_ligne: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
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

        return {
            "success":     True,
            "arrets":      arrets,
            "prix_map":    prix_map,
            "tarif_types": tarif_types,
        }
    except Exception as e:
        return {"success": False, "message": str(e)}
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# Voyage statut & cloture
# ─────────────────────────────────────────────────────────────

@router.get("/vente/{id_vente}/statut")
def get_statut_voyage(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT statut FROM billetterie.vente WHERE id_vente = %s",
            (id_vente,),
        )
        row = cursor.fetchone()
        if row:
            return {"success": True, "statut": row["statut"]}
        return {"success": False, "message": "Voyage introuvable"}
    finally:
        conn.close()


@router.put("/vente/{id_vente}/cloturer")
def cloturer_voyage(id_vente: int):
    """
    Clôture a voyage and cascade-clôture all open segments.
    Segments in 'en_attente' are briefly activated then immediately clôturés
    so that DB constraints (only actif → cloture) are respected.
    """
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        # 1 — Fetch voyage
        cursor.execute(
            "SELECT * FROM billetterie.vente WHERE id_vente = %s", (id_vente,)
        )
        vente = cursor.fetchone()
        if not vente:
            return {"success": False, "message": "Voyage introuvable"}
        if vente["statut"] == "cloture":
            return {"success": False, "message": "Voyage déjà clôturé"}

        now = _now()

        # 2 — Fetch all non-clôturé segments
        cursor.execute("""
            SELECT id_segment, statut
            FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut != 'cloture'
            ORDER BY ordre
        """, (id_vente,))
        open_segments = cursor.fetchall()

        # 3 — Cascade: activate (if needed) then clôture each segment
        for seg in open_segments:
            id_seg = seg["id_segment"]
            if seg["statut"] == "en_attente":
                cursor.execute("""
                    UPDATE billetterie.segment_voyage
                    SET statut = 'actif', date_ouverture = %s
                    WHERE id_segment = %s
                """, (now, id_seg))
            cursor.execute("""
                UPDATE billetterie.segment_voyage
                SET statut = 'cloture', date_cloture = %s
                WHERE id_segment = %s
            """, (now, id_seg))

        # 4 — Clôture the voyage itself
        cursor.execute(
            "UPDATE billetterie.vente "
            "SET statut = 'cloture', date_cloture = %s "
            "WHERE id_vente = %s",
            (now, id_vente),
        )
        conn.commit()

        segments_closed = len(open_segments)
        print(
            f"✅ Voyage {id_vente} clôturé à {now} — "
            f"{segments_closed} segment(s) cascade-clôturés"
        )
        return {
            "success":         True,
            "message":         "Voyage clôturé",
            "date_cloture":    now,
            "segments_closed": segments_closed,
        }

    except Exception as e:
        conn.rollback()
        print(f"❌ cloturer_voyage {id_vente}: {e}")
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# Segments
# ─────────────────────────────────────────────────────────────

@router.get("/voyages/{id_vente}/segment/actif")
def get_segment_actif(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        # Try to find the currently active segment
        cursor.execute("""
            SELECT * FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut = 'actif'
            ORDER BY ordre LIMIT 1
        """, (id_vente,))
        segment = cursor.fetchone()

        def _fmt_seg(s):
            return {
                "id_segment":     s["id_segment"],
                "point_depart":   s["point_depart"],
                "point_arrivee":  s["point_arrivee"],
                "ordre":          s["ordre"],
                "statut":         s["statut"],
                "date_ouverture": str(s["date_ouverture"]) if s.get("date_ouverture") else None,
                "date_cloture":   str(s["date_cloture"])   if s.get("date_cloture")   else None,
            }

        def _fmt_prochain(s):
            return {
                "id_segment":    s["id_segment"],
                "point_depart":  s["point_depart"],
                "point_arrivee": s["point_arrivee"],
                "ordre":         s["ordre"],
            }

        if not segment:
            # No active segment — find the next en_attente one
            cursor.execute("""
                SELECT * FROM billetterie.segment_voyage
                WHERE id_vente = %s AND statut = 'en_attente'
                ORDER BY ordre LIMIT 1
            """, (id_vente,))
            prochain = cursor.fetchone()
            return {
                "success":      True,
                "segment":      None,
                "prochain":     _fmt_prochain(prochain) if prochain else None,
                "tous_clotures": prochain is None,
            }

        # Active segment found — look for the next en_attente one
        cursor.execute("""
            SELECT * FROM billetterie.segment_voyage
            WHERE id_vente = %s AND ordre > %s AND statut = 'en_attente'
            ORDER BY ordre LIMIT 1
        """, (id_vente, segment["ordre"]))
        prochain = cursor.fetchone()

        return {
            "success":      True,
            "segment":      _fmt_seg(segment),
            "prochain":     _fmt_prochain(prochain) if prochain else None,
            "tous_clotures": False,
        }
    except Exception as e:
        print(f"❌ get_segment_actif {id_vente}: {e}")
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


@router.put("/voyages/{id_vente}/segment/ouvrir")
def ouvrir_segment(id_vente: int):
    """Activate the next en_attente segment (only if no segment is currently active)."""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT id_segment FROM billetterie.segment_voyage
            WHERE id_vente = %s AND statut = 'actif'
        """, (id_vente,))
        if cursor.fetchone():
            return {
                "success": False,
                "message": "Clôturez le segment actif avant d'ouvrir le suivant",
            }

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
        """, (_now(), row["id_segment"]))
        conn.commit()
        return {"success": True, "message": "Segment ouvert", "id_segment": row["id_segment"]}
    except Exception as e:
        conn.rollback()
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


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
            return {"success": False, "message": "Ce segment n'est pas actif"}

        cursor.execute("""
            UPDATE billetterie.segment_voyage
            SET statut = 'cloture', date_cloture = %s
            WHERE id_segment = %s
        """, (_now(), id_segment))
        conn.commit()
        return {"success": True, "message": "Segment clôturé"}
    except Exception as e:
        conn.rollback()
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


@router.get("/voyages/{id_vente}/segments")
def get_segments(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT sv.id_segment, sv.point_depart, sv.point_arrivee,
                   sv.ordre, sv.statut,
                   sv.date_ouverture, sv.date_cloture,
                   v.id_ligne, v.matricule_agent,
                   l.nom_ligne,
                   a.nom, a.prenom
            FROM billetterie.segment_voyage sv
            JOIN  billetterie.vente   v  ON sv.id_vente       = v.id_vente
            JOIN  base_global.ligne   l  ON v.id_ligne        = l.id_ligne
            LEFT JOIN base_global.agent a ON v.matricule_agent = a.matricule_agent
            WHERE sv.id_vente = %s
            ORDER BY sv.ordre
        """, (id_vente,))
        segments = cursor.fetchall()
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
                for s in segments
            ],
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# Tickets
# ─────────────────────────────────────────────────────────────

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

        is_special = _is_special_passage(type_tarif)

        if is_special and (prix_unitaire != 0 or montant_total != 0):
            return {
                "success": False,
                "error":   f"Passage spécial '{type_tarif}' doit avoir prix=0",
            }

        # Resolve id_segment if not supplied
        if id_segment == 0:
            cursor.execute("""
                SELECT id_segment FROM billetterie.segment_voyage
                WHERE id_vente = %s AND statut = 'actif'
                ORDER BY ordre LIMIT 1
            """, (id_vente,))
            row = cursor.fetchone()
            if row:
                id_segment = row[0]
            else:
                # Fall back to the last segment of the voyage
                cursor.execute("""
                    SELECT id_segment FROM billetterie.segment_voyage
                    WHERE id_vente = %s
                    ORDER BY ordre DESC LIMIT 1
                """, (id_vente,))
                row = cursor.fetchone()
                if row:
                    id_segment = row[0]
                else:
                    return {"success": False, "error": "Aucun segment trouvé pour ce voyage"}

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
            _now(),
            data.get("matricule_agent"),
        ))
        conn.commit()

        last_id = cursor.lastrowid
        label   = "Gratuit/Spécial" if is_special else "Ticket normal"
        print(
            f"✅ {label} saved: id={last_id}, voyage={id_vente}, "
            f"segment={id_segment}, type={type_tarif}, qty={quantite}"
        )
        return {"success": True, "id_ticket": last_id}

    except Exception as e:
        conn.rollback()
        print(f"❌ vendre_ticket: {e}")
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


@router.get("/voyages/{id_vente}/tickets")
def get_tickets_voyage(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT t.id_ticket, t.point_depart, t.point_arrivee,
                   t.type_tarif, t.quantite, t.prix_unitaire,
                   t.montant_total, t.date_heure,
                   t.id_segment,
                   sv.ordre AS segment_ordre,
                   l.nom_ligne,
                   a.nom, a.prenom
            FROM billetterie.ticket_vendu t
            LEFT JOIN billetterie.segment_voyage sv ON t.id_segment  = sv.id_segment
            LEFT JOIN billetterie.vente          v  ON t.id_vente    = v.id_vente
            LEFT JOIN base_global.ligne          l  ON v.id_ligne    = l.id_ligne
            LEFT JOIN base_global.agent          a  ON t.matricule_agent = a.matricule_agent
            WHERE t.id_vente = %s
            ORDER BY t.date_heure DESC
        """, (id_vente,))
        rows = cursor.fetchall()
        return {
            "success": True,
            "tickets": [
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
                    "is_free":       _is_special_passage(r["type_tarif"] or ""),
                }
                for r in rows
            ],
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()


# ─────────────────────────────────────────────────────────────
# Special passages stats
# ─────────────────────────────────────────────────────────────

@router.get("/voyages/{id_vente}/passages-speciaux/stats")
def get_special_passages_stats(id_vente: int):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT
                type_tarif,
                COUNT(*)      AS count,
                SUM(quantite) AS total_quantite
            FROM billetterie.ticket_vendu
            WHERE id_vente = %s AND prix_unitaire = 0
            GROUP BY type_tarif
            ORDER BY count DESC
        """, (id_vente,))
        stats = cursor.fetchall()
        return {
            "success":  True,
            "id_vente": id_vente,
            "passages_speciaux": [
                {
                    "type":            s["type_tarif"],
                    "nombre":          s["count"],
                    "quantite_totale": s["total_quantite"],
                }
                for s in stats
            ],
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        conn.close()