import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'vente_tickets.dart';

const Color srtbBlue = Color(0xFF1A3F7A);

class VoyageProgrammePage extends StatefulWidget {
  final Map<String, dynamic> agent; // ← added
  const VoyageProgrammePage({super.key, required this.agent}); // ← added

  @override
  State<VoyageProgrammePage> createState() => _VoyageProgrammePageState();
}

class _VoyageProgrammePageState extends State<VoyageProgrammePage> {
  List<dynamic> voyages = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVoyages();
  }

  Future<void> _fetchVoyages() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ← use agent matricule from widget
      final matricule = widget.agent['matricule_agent'] ?? widget.agent['matricule'];
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/ventes/programmees/$matricule'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          voyages = data['voyages'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erreur serveur : ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  String _getDate(String? dateHeure) {
    if (dateHeure == null) return '';
    return dateHeure.split(' ')[0];
  }

  String _getTime(String? dateHeure) {
    if (dateHeure == null) return '';
    final parts = dateHeure.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : '';
  }

  void _onStartVoyage(Map<String, dynamic> voyage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenteTicketsPage(voyage: voyage),
      ),
    ).then((_) => _fetchVoyages()); // ← refresh when coming back
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
              color: srtbBlue,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset('assets/images/logo_srtb.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.directions_bus, size: 80, color: srtbBlue)),
                  ),
                  const SizedBox(height: 16),
                  const Text('S R T B',
                      style: TextStyle(color: Colors.white, fontSize: 34,
                          fontWeight: FontWeight.bold, letterSpacing: 6)),
                  const SizedBox(height: 8),
                  const Text('Voyages Programmés',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  // ← show agent name
                  Text(
                    '${widget.agent['prenom']} ${widget.agent['nom']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(color: srtbBlue),
                      ))
                  : errorMessage != null
                      ? Center(
                          child: Column(children: [
                            const SizedBox(height: 40),
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 15),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _fetchVoyages,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: srtbBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ]))
                      : voyages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: Text('Aucun voyage programmé disponible',
                                    style: TextStyle(color: Colors.grey, fontSize: 15)),
                              ))
                          : Column(
                              children: voyages.map((v) {
                                final dateHeure = v['date_heure'] as String?;
                                final isCloture = v['statut'] == 'cloture'; // ← check status

                                return GestureDetector(
                                  onTap: () => _onStartVoyage(v),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: isCloture
                                              ? Colors.grey.shade400
                                              : srtbBlue.withOpacity(0.4),
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(14),
                                      color: isCloture
                                          ? Colors.grey.shade100
                                          : const Color(0xFFE8F1FF),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.directions_bus,
                                            color: isCloture ? Colors.grey : srtbBlue,
                                            size: 32),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Flexible(
                                                  child: Text(v['depart'] ?? '',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: isCloture
                                                              ? Colors.grey
                                                              : srtbBlue)),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                                  child: Icon(Icons.arrow_forward,
                                                      size: 16,
                                                      color: isCloture ? Colors.grey : srtbBlue),
                                                ),
                                                Flexible(
                                                  child: Text(v['arrivee'] ?? '',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: isCloture
                                                              ? Colors.grey
                                                              : srtbBlue)),
                                                ),
                                              ]),
                                              const SizedBox(height: 6),
                                              Row(children: [
                                                const Icon(Icons.access_time,
                                                    size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(_getTime(dateHeure),
                                                    style: const TextStyle(
                                                        color: Colors.grey, fontSize: 13)),
                                              ]),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(Icons.calendar_today,
                                                    size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(_getDate(dateHeure),
                                                    style: const TextStyle(
                                                        color: Colors.grey, fontSize: 13)),
                                              ]),
                                            ],
                                          ),
                                        ),
                                        // ← status badge
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isCloture
                                                    ? Colors.red.shade100
                                                    : Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                isCloture ? 'Clôturé' : 'Actif',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCloture
                                                        ? Colors.red.shade700
                                                        : Colors.green.shade700),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Icon(Icons.chevron_right,
                                                color: isCloture ? Colors.grey : srtbBlue),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}