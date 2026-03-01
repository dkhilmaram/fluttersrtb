import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'HistoriquePage.dart';
import 'cloture_voyage.dart';
import 'segment_page.dart';

const Color srtbBlue = Color(0xFF1A3F7A);

class VenteTicketsPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const VenteTicketsPage({super.key, required this.voyage});

  @override
  State<VenteTicketsPage> createState() => _VenteTicketsPageState();
}

class _VenteTicketsPageState extends State<VenteTicketsPage> {
  bool isCloture = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatut();
  }

  Future<void> _checkStatut() async {
    final id = widget.voyage['id'] as int?;
    if (id == null) {
      setState(() => isLoading = false);
      return;
    }
    try {
      final response = await http.get(
       Uri.parse('http://127.0.0.1:8000/billetterie/vente/$id/statut'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          isCloture = data['statut'] == 'cloture';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String get _date {
    final dh = widget.voyage['date_heure'] as String? ?? '';
    return dh.split(' ').firstOrNull ?? '';
  }

  String get _heure {
    final dh = widget.voyage['date_heure'] as String? ?? '';
    final parts = dh.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : '';
  }

  @override
  Widget build(BuildContext context) {
    final voyageId = widget.voyage['id'] as int?;
    final hasId = voyageId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              color: isCloture ? Colors.grey.shade700 : srtbBlue,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/logo_srtb.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.directions_bus, size: 80, color: srtbBlue),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'S R T B',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vente & Historique des Tickets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gestion des opérations de voyage',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ]),
            ),

            // ── Warning if no ID ──
            if (!hasId)
              Container(
                width: double.infinity,
                color: Colors.orange.shade700,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: const Text(
                  'Erreur : ID du voyage manquant.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Cloture banner ──
            if (isCloture)
              Container(
                width: double.infinity,
                color: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Voyage clôturé — Aucune vente possible',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Voyage info card ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCloture ? Colors.grey.shade100 : const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCloture ? Colors.grey.shade400 : srtbBlue.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: isCloture ? Colors.grey : srtbBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(
                              widget.voyage['depart'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isCloture ? Colors.grey : srtbBlue,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward, size: 16,
                                  color: isCloture ? Colors.grey : srtbBlue),
                            ),
                            Text(
                              widget.voyage['arrivee'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isCloture ? Colors.grey : srtbBlue,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            '$_heure  |  $_date',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCloture ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCloture ? 'Clôturé' : 'Actif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCloture ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Buttons ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: srtbBlue))
                  : Column(                          // ← THIS was the missing `: Column(`
                      children: [
                        // ── Segments du voyage ──
                        _actionButton(
                          context,
                          icon: Icons.route,
                          label: 'Segments du voyage',
                          onTap: !hasId
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SegmentPage(voyage: widget.voyage),
                                    ),
                                  );
                                },
                          color: Colors.teal.shade700,
                        ),
                        const SizedBox(height: 14),

                       

                        
                        // ── Historique ──
_actionButton(
  context,
  icon: Icons.history,
  label: 'Historique',
  onTap: !hasId ? null : () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriquePage(voyage: widget.voyage),
      ),
    );
  },
),
                        const SizedBox(height: 14),

                        // ── Fin du Voyage ──
                        if (!isCloture && hasId)
                          _actionButton(
                            context,
                            icon: Icons.flag,
                            label: 'Fin du Voyage',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClotureVoyagePage(voyage: widget.voyage),
                                ),
                              );
                              _checkStatut();
                            },
                            color: Colors.red.shade700,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color color = srtbBlue,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }
}