import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color srtbBlue = Color(0xFF1A3F7A);

class NouveauTicketPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const NouveauTicketPage({super.key, required this.voyage});

  @override
  State<NouveauTicketPage> createState() => _NouveauTicketPageState();
}

class _NouveauTicketPageState extends State<NouveauTicketPage> {
  String? pointDepart;
  String? pointArrivee;
  String? typeTarif;
  int quantite = 1;

  List<String> arrets = [];
  Map<String, int> prixMap = {};
  List<Map<String, dynamic>> tarifTypes = [];

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  int ticketsVendus = 0;
  int montantTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final idLigne = widget.voyage['id_ligne'];
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/ligne/$idLigne/tarifs'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            arrets = List<String>.from(data['arrets']);
            prixMap = Map<String, int>.from(
              (data['prix_map'] as Map).map((k, v) => MapEntry(k.toString(), v as int)),
            );
            tarifTypes = List<Map<String, dynamic>>.from(data['tarif_types']);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de charger les données';
        isLoading = false;
      });
    }
  }

  int? get _prixNormal {
    if (pointDepart == null || pointArrivee == null || pointDepart == pointArrivee) return null;
    return prixMap['$pointDepart|$pointArrivee'];
  }

  int? get _prixUnitaire {
    final base = _prixNormal;
    if (base == null || typeTarif == null) return null;
    final tarif = tarifTypes.firstWhere((t) => t['type_tarif'] == typeTarif, orElse: () => {});
    if (tarif.isEmpty) return null;
    return (base * (tarif['pourcentage'] as int) / 100).round();
  }

  int? get _prixTotal => _prixUnitaire != null ? _prixUnitaire! * quantite : null;

  int get _discountPct {
    if (typeTarif == null) return 0;
    final tarif = tarifTypes.firstWhere((t) => t['type_tarif'] == typeTarif, orElse: () => {});
    if (tarif.isEmpty) return 0;
    return 100 - (tarif['pourcentage'] as int);
  }

  bool get _canValidate =>
      typeTarif != null &&
      pointDepart != null &&
      pointArrivee != null &&
      pointDepart != pointArrivee &&
      _prixUnitaire != null;

  Future<void> _saveTicket() async {
    final idVente   = widget.voyage['id'] as int?;
    final idSegment = widget.voyage['id_segment'] as int?;
    final matricule = widget.voyage['matricule_agent'] as int?;

    if (idVente == null) { _showSnack('ID du voyage manquant', Colors.red); return; }

    setState(() => isSaving = true);

    final qte    = quantite;
    final prixU  = _prixUnitaire!;
    final prixT  = _prixTotal!;
    final depart = pointDepart!;
    final arr    = pointArrivee!;
    final tarif  = typeTarif!;

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/billetterie/tickets/vendre'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_vente':        idVente,
          'id_segment':      idSegment ?? 0,
          'point_depart':    depart,
          'point_arrivee':   arr,
          'type_tarif':      tarif,
          'quantite':        qte,
          'prix_unitaire':   prixU,
          'montant_total':   prixT,
          'matricule_agent': matricule ?? 0,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          ticketsVendus += qte;
          montantTotal  += prixT;
          pointDepart  = null;
          pointArrivee = null;
          typeTarif    = null;
          quantite     = 1;
        });
        _showSnack(
          prixT == 0 ? 'ok $qte passage(s) gratuit(s) enregistre(s)'
                     : 'ok $qte ticket(s) - $prixT millimes',
          Colors.green,
        );
      } else {
        _showSnack('Erreur : ${data['error'] ?? 'inconnue'}', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur reseau : $e', Colors.red);
    }
    setState(() => isSaving = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _vendreTicket() {
    if (!_canValidate) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le ticket',
            style: TextStyle(color: srtbBlue, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _confirmRow(Icons.location_on, 'Montee', pointDepart!),
          const SizedBox(height: 8),
          _confirmRow(Icons.flag, 'Descente', pointArrivee!),
          const SizedBox(height: 8),
          _confirmRow(Icons.label, 'Tarif', typeTarif!),
          const SizedBox(height: 8),
          _confirmRow(Icons.people, 'Quantite', '$quantite ticket${quantite > 1 ? 's' : ''}'),
          if (_discountPct > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('-$_discountPct%',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
          ],
          const Divider(height: 24),
          if (quantite > 1) ...[
            Text('$quantite x $_prixUnitaire ms', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
          ],
          Text(
            _prixTotal == 0 ? 'GRATUIT' : '${_prixTotal} millimes',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: _prixTotal == 0 ? Colors.green : srtbBlue),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _saveTicket(); },
            style: ElevatedButton.styleFrom(backgroundColor: srtbBlue, foregroundColor: Colors.white),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: srtbBlue),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity, color: srtbBlue,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
            child: Column(children: [
              Align(alignment: Alignment.topLeft,
                child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context))),
              Container(width: 120, height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/logo_srtb.png', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.directions_bus, size: 80, color: srtbBlue))),
              const SizedBox(height: 16),
              const Text('S R T B', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 6)),
              const SizedBox(height: 8),
              const Text('Nouveau Ticket', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${widget.voyage['depart']} -> ${widget.voyage['arrivee']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          Container(
            color: const Color(0xFFE8F1FF),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _counterBox(Icons.confirmation_number, 'Tickets vendus', '$ticketsVendus', srtbBlue),
              Container(width: 1, height: 40, color: srtbBlue.withOpacity(0.2)),
              _counterBox(Icons.monetization_on, 'Total collecte', '$montantTotal ms', Colors.green.shade700),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: isLoading
                ? const Center(child: Padding(padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(color: srtbBlue)))
                : errorMessage != null
                    ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        const Text('Type de tarif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: srtbBlue)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8,
                          children: tarifTypes.map((t) {
                            final type = t['type_tarif'] as String;
                            final pct  = t['pourcentage'] as int;
                            final discount = 100 - pct;
                            final isSelected = typeTarif == type;
                            final color = pct == 0 ? Colors.green : pct <= 25 ? Colors.purple : pct <= 50 ? Colors.orange : srtbBlue;
                            return GestureDetector(
                              onTap: () => setState(() => typeTarif = type),
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 72) / 2,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? color : color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color, width: 1.5),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(pct == 0 ? Icons.card_giftcard : discount > 0 ? Icons.discount : Icons.person,
                                      color: isSelected ? Colors.white : color, size: 18),
                                  const SizedBox(width: 6),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(type, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : color)),
                                    if (discount > 0 && pct > 0)
                                      Text('-$discount%', style: TextStyle(fontSize: 11,
                                          color: isSelected ? Colors.white70 : color.withOpacity(0.8))),
                                    if (pct == 0)
                                      Text('Gratuit', style: TextStyle(fontSize: 11,
                                          color: isSelected ? Colors.white70 : color.withOpacity(0.8))),
                                  ]),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),
                        const Text('Point de montee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: srtbBlue)),
                        const SizedBox(height: 8),
                        _dropdownCard(icon: Icons.location_on, hint: 'Choisir le point de montee',
                          value: pointDepart, items: arrets,
                          onChanged: (v) => setState(() { pointDepart = v; if (pointArrivee == v) pointArrivee = null; })),

                        const SizedBox(height: 16),
                        const Text('Point de descente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: srtbBlue)),
                        const SizedBox(height: 8),
                        _dropdownCard(icon: Icons.flag, hint: 'Choisir le point de descente',
                          value: pointArrivee, items: arrets,
                          onChanged: (v) => setState(() => pointArrivee = v)),

                        const SizedBox(height: 24),
                        const Text('Nombre de tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: srtbBlue)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: srtbBlue.withOpacity(0.4), width: 1.5)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            GestureDetector(
                              onTap: quantite > 1 ? () => setState(() => quantite--) : null,
                              child: Container(width: 40, height: 40,
                                decoration: BoxDecoration(color: quantite > 1 ? srtbBlue : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.remove, color: Colors.white, size: 20)),
                            ),
                            Column(children: [
                              Text('$quantite', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: srtbBlue)),
                              Text(quantite == 1 ? 'ticket' : 'tickets', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ]),
                            GestureDetector(
                              onTap: () => setState(() => quantite++),
                              child: Container(width: 40, height: 40,
                                decoration: BoxDecoration(color: srtbBlue, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.add, color: Colors.white, size: 20)),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        if (_prixUnitaire != null)
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(color: const Color(0xFFE8F1FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: srtbBlue.withOpacity(0.4), width: 1.5)),
                            child: Column(children: [
                              if (_discountPct > 0) ...[
                                Text('${_prixNormal! * quantite} millimes',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                const SizedBox(height: 4),
                              ],
                              if (quantite > 1)
                                Text('$quantite x $_prixUnitaire ms', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.monetization_on, color: _prixTotal == 0 ? Colors.green : srtbBlue, size: 28),
                                const SizedBox(width: 10),
                                Text(_prixTotal == 0 ? 'GRATUIT' : '${_prixTotal} millimes',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                        color: _prixTotal == 0 ? Colors.green : srtbBlue)),
                              ]),
                              if (_discountPct > 0)
                                Padding(padding: const EdgeInsets.only(top: 6),
                                  child: Text('Reduction de $_discountPct% appliquee',
                                      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600))),
                            ]),
                          ),

                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton.icon(
                            onPressed: (_canValidate && !isSaving) ? _vendreTicket : null,
                            icon: isSaving
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.confirmation_number, size: 22),
                            label: Text(
                              isSaving ? 'Enregistrement...' : quantite > 1 ? 'Valider $quantite tickets' : 'Valider le ticket',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(backgroundColor: srtbBlue, foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300, disabledForegroundColor: Colors.grey.shade500,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4),
                          ),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _counterBox(IconData icon, String label, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _dropdownCard({required IconData icon, required String hint, required String? value,
      required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: srtbBlue.withOpacity(0.4), width: 1.5)),
      child: Row(children: [
        Icon(icon, color: srtbBlue),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(value: value,
            hint: Text(hint, style: const TextStyle(color: Colors.grey)), isExpanded: true,
            items: items.map((a) => DropdownMenuItem(value: a,
                child: Text(a, style: const TextStyle(color: srtbBlue)))).toList(),
            onChanged: onChanged),
        )),
      ]),
    );
  }
}