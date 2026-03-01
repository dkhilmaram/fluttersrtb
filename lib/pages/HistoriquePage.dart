import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color srtbBlue = Color(0xFF1A3F7A);

class HistoriquePage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const HistoriquePage({super.key, required this.voyage});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  List<dynamic> tickets = [];
  bool isLoading = true;
  String? errorMessage;

  // Stats
  int totalTickets = 0;
  int totalMontant = 0;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final id = widget.voyage['id'] as int?;
      if (id == null) throw Exception("ID du voyage manquant");

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/tickets'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['tickets'] as List<dynamic>? ?? [];
          int tTickets = 0;
          int tMontant = 0;
          for (final t in list) {
            tTickets += (t['quantite'] as int? ?? 0);
            tMontant += (t['montant_total'] as int? ?? 0);
          }
          setState(() {
            tickets      = list;
            totalTickets = tTickets;
            totalMontant = tMontant;
            isLoading    = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Erreur');
        }
      } else {
        throw Exception('Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Color _tarifColor(String type) {
    if (type.toLowerCase().contains('gratuit')) return Colors.green;
    if (type.toLowerCase().contains('75'))      return Colors.purple;
    if (type.toLowerCase().contains('50'))      return Colors.orange;
    return srtbBlue;
  }

  IconData _tarifIcon(String type) {
    if (type.toLowerCase().contains('gratuit')) return Icons.card_giftcard;
    if (type.toLowerCase().contains('réduit'))  return Icons.discount;
    return Icons.person;
  }

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDay(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: SafeArea(
        child: Column(children: [

          // ── Header ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2557), srtbBlue, Color(0xFF1E56A0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 28),
            child: Column(children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: _fetchTickets,
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.history_rounded, color: srtbBlue, size: 40),
              ),
              const SizedBox(height: 12),
              const Text('Historique des tickets', style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5,
              )),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.route, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.voyage['depart'] ?? '?'}  →  ${widget.voyage['arrivee'] ?? '?'}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Stats bar ──
          if (!isLoading && errorMessage == null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _statBox(Icons.confirmation_number_rounded, 'Tickets vendus', '$totalTickets', srtbBlue),
                Container(width: 1, height: 44, color: Colors.grey.shade200),
                _statBox(Icons.receipt_long_rounded, 'Transactions', '${tickets.length}', Colors.indigo),
                Container(width: 1, height: 44, color: Colors.grey.shade200),
                _statBox(Icons.monetization_on_rounded, 'Total', '$totalMontant ms', Colors.green.shade700),
              ]),
            ),

          // ── Body ──
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: srtbBlue))
                : errorMessage != null
                    ? _buildError()
                    : tickets.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: srtbBlue,
                            onRefresh: _fetchTickets,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              itemCount: tickets.length,
                              itemBuilder: (_, i) {
                                final t = tickets[i] as Map<String, dynamic>;
                                final prev = i > 0 ? tickets[i - 1] as Map<String, dynamic> : null;
                                final showDayHeader = prev == null ||
                                    _formatDay(t['date_heure']) != _formatDay(prev['date_heure']);

                                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  // Date separator
                                  if (showDayHeader) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: srtbBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: srtbBlue.withOpacity(0.3)),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.calendar_today, size: 12, color: srtbBlue),
                                            const SizedBox(width: 6),
                                            Text(_formatDay(t['date_heure']),
                                                style: const TextStyle(
                                                    color: srtbBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ]),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Divider(color: srtbBlue.withOpacity(0.15))),
                                      ]),
                                    ),
                                  ],
                                  _buildTicketCard(t),
                                  const SizedBox(height: 10),
                                ]);
                              },
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final type   = t['type_tarif'] as String? ?? '';
    final color  = _tarifColor(type);
    final isFree = (t['montant_total'] as int? ?? 0) == 0;
    final qty    = t['quantite'] as int? ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [

        // ── Top: time + tarif ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(children: [
            // Tarif badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_tarifIcon(type), color: Colors.white, size: 12),
                const SizedBox(width: 5),
                Text(type, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),

            const Spacer(),

            // Time
            Row(children: [
              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(_formatTime(t['date_heure']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ]),

            // Quantity badge
            if (qty > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: srtbBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('×$qty', style: const TextStyle(
                    color: srtbBlue, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),

        // ── Middle: route ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [

            // Route column
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Segment route
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(child: Text(t['point_depart'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                ),
                const Icon(Icons.flag, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(child: Text(t['point_arrivee'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              ]),

              const SizedBox(height: 8),

              // Segment order + ligne
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.route, size: 12, color: srtbBlue),
                    const SizedBox(width: 4),
                    Text('Segment ${t['segment_ordre']}',
                        style: const TextStyle(fontSize: 11, color: srtbBlue, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (t['nom_ligne'] != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: Text(t['nom_ligne'],
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                ],
              ]),

              // Agent
              if (t['agent'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(t['agent'],
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ]),
              ],
            ])),

            const SizedBox(width: 16),

            // Price
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (qty > 1)
                Text('${t['prix_unitaire']} ms / ticket',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(
                isFree ? 'GRATUIT' : '${t['montant_total']} ms',
                style: TextStyle(
                  fontSize: isFree ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: isFree ? Colors.green : srtbBlue,
                ),
              ),
              if (!isFree)
                Text('millimes', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: srtbBlue.withOpacity(0.07),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.receipt_long_rounded, color: srtbBlue, size: 52),
      ),
      const SizedBox(height: 16),
      const Text('Aucun ticket vendu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: srtbBlue)),
      const SizedBox(height: 6),
      Text('Les tickets vendus apparaîtront ici', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
    ]));
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
        ),
        const SizedBox(height: 16),
        Text(errorMessage!, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: srtbBlue, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _fetchTickets,
        ),
      ]),
    ));
  }
}