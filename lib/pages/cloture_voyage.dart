import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color srtbBlue = Color(0xFF1A3F7A);

class ClotureVoyagePage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const ClotureVoyagePage({super.key, required this.voyage});

  @override
  State<ClotureVoyagePage> createState() => _ClotureVoyagePageState();
}

class _ClotureVoyagePageState extends State<ClotureVoyagePage> {
  bool isCloturing = false;
  bool isCloture = false;

  String get _date {
    final dh = widget.voyage['date_heure'] as String? ?? '';
    return dh.split(' ')[0];
  }

  String get _heure {
    final dh = widget.voyage['date_heure'] as String? ?? '';
    final parts = dh.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : '';
  }

  Future<void> _cloturerVoyage() async {
    setState(() => isCloturing = true);
    try {
      final id = widget.voyage['id'];
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/billetterie/vente/$id/cloturer'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            isCloture = true;
            isCloturing = false;
          });
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context); // back to VenteTicketsPage
            Navigator.pop(context); // back to voyage list
          }
        } else {
          setState(() => isCloturing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['message'] ?? 'Erreur'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }
    } catch (e) {
      setState(() => isCloturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de clôturer le voyage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: isCloturing ? null : () => Navigator.pop(context),
                  ),
                ),
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/logo_srtb.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.directions_bus, size: 80,
                          color: Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
                const Text('S R T B',
                    style: TextStyle(color: Colors.white, fontSize: 34,
                        fontWeight: FontWeight.bold, letterSpacing: 6)),
                const SizedBox(height: 8),
                const Text('Fin du Voyage',
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Clôture du service',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: isCloture

                  // ── Success state ──
                  ? Column(children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle),
                        child: Icon(Icons.check_circle,
                            color: Colors.green.shade600, size: 60),
                      ),
                      const SizedBox(height: 24),
                      const Text('Voyage clôturé !',
                          style: TextStyle(fontSize: 24,
                              fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      const Text('Retour en cours...',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ])

                  // ── Confirm state ──
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Voyage summary ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: srtbBlue.withOpacity(0.4), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Voyage en cours',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.directions_bus, color: srtbBlue, size: 24),
                                const SizedBox(width: 10),
                                Text(widget.voyage['depart'] ?? '',
                                    style: const TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.bold, color: srtbBlue)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward, size: 16, color: srtbBlue),
                                ),
                                Text(widget.voyage['arrivee'] ?? '',
                                    style: const TextStyle(fontSize: 16,
                                        fontWeight: FontWeight.bold, color: srtbBlue)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('$_heure  |  $_date',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ]),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Warning box ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.red.shade700, size: 22),
                                const SizedBox(width: 8),
                                Text('Attention',
                                    style: TextStyle(fontWeight: FontWeight.bold,
                                        fontSize: 15, color: Colors.red.shade700)),
                              ]),
                              const SizedBox(height: 12),
                              _warningItem('Cette action est irréversible'),
                              _warningItem('Aucune vente ne sera possible après clôture'),
                              _warningItem('Le voyage sera marqué comme terminé'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Confirm button ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: isCloturing
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.red))
                              : ElevatedButton.icon(
                                  onPressed: _cloturerVoyage,
                                  icon: const Icon(Icons.flag, size: 22),
                                  label: const Text('Confirmer la clôture',
                                      style: TextStyle(fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 14),

                        // ── Cancel button ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: isCloturing ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Annuler',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: srtbBlue,
                              side: const BorderSide(color: srtbBlue, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(Icons.close, color: Colors.red.shade700, size: 16),
        const SizedBox(width: 8),
        Flexible(child: Text(text,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
      ]),
    );
  }
}