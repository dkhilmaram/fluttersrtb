import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Color palette ──
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color gold      = Color(0xFFD4A017);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

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
      if (id == null) throw Exception('ID du voyage manquant');

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/tickets'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['tickets'] as List<dynamic>? ?? [];
          int tTickets = 0, tMontant = 0;
          for (final t in list) {
            tTickets += (t['quantite']     as int? ?? 0);
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
        isLoading    = false;
      });
    }
  }

  // ── Tarif helpers ──
  Color _tarifColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('gratuit')) return const Color(0xFF16A34A);
    if (t.contains('75'))      return const Color(0xFF7C3AED);
    if (t.contains('50'))      return const Color(0xFFD97706);
    return navyMid;
  }

  IconData _tarifIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('gratuit')) return Icons.card_giftcard_rounded;
    if (t.contains('réduit'))  return Icons.discount_rounded;
    return Icons.person_rounded;
  }

  String _formatTime(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  String _formatDay(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(children: [

          // ── Header ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navyDark, navyMid, navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(children: [

              // ── Top row: back + refresh ──
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 17),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _fetchTickets,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh,
                        color: Colors.white70, size: 18),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Icon box ──
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 6),
                  )],
                ),
                child: const Icon(Icons.history_rounded,
                    color: navyMid, size: 38),
              ),

              const SizedBox(height: 12),
              const Text('Historique des tickets',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 14),

              // ── Route pill ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: goldLight, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(depart,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward,
                        color: Colors.white.withOpacity(0.4), size: 13),
                  ),
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: Colors.transparent, shape: BoxShape.circle,
                        border: Border.all(color: goldLight, width: 2),
                      )),
                  const SizedBox(width: 8),
                  Text(arrivee,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // ── Stats bar ──
          if (!isLoading && errorMessage == null)
            Container(
              color: cardWhite,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(children: [
                _statTile(Icons.confirmation_number_outlined,
                    'Tickets', '$totalTickets', navyMid),
                Container(width: 1, height: 36, color: Colors.grey.shade100),
                _statTile(Icons.receipt_long_outlined,
                    'Transactions', '${tickets.length}', const Color(0xFF7C3AED)),
                Container(width: 1, height: 36, color: Colors.grey.shade100),
                _statTile(Icons.account_balance_wallet_outlined,
                    'Total', '$totalMontant ms', const Color(0xFF16A34A)),
              ]),
            ),

          // ── Body ──
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: navyMid))
                : errorMessage != null
                    ? _buildError()
                    : tickets.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: navyMid,
                            onRefresh: _fetchTickets,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              itemCount: tickets.length,
                              itemBuilder: (_, i) {
                                final t   = tickets[i] as Map<String, dynamic>;
                                final prev = i > 0
                                    ? tickets[i - 1] as Map<String, dynamic>
                                    : null;
                                final showDay = prev == null ||
                                    _formatDay(t['date_heure']) !=
                                        _formatDay(prev['date_heure']);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showDay) ...[
                                      if (i > 0) const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: navyMid.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: navyMid.withOpacity(0.2)),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min,
                                                children: [
                                              const Icon(Icons.calendar_today,
                                                  size: 11, color: navyMid),
                                              const SizedBox(width: 6),
                                              Text(_formatDay(t['date_heure']),
                                                  style: const TextStyle(
                                                      color: navyMid, fontSize: 12,
                                                      fontWeight: FontWeight.bold)),
                                            ]),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Divider(
                                              color: navyMid.withOpacity(0.1))),
                                        ]),
                                      ),
                                    ],
                                    _buildTicketCard(t),
                                    const SizedBox(height: 10),
                                  ],
                                );
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
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: navyMid.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Column(children: [

        // ── Top: tarif badge + time + qty ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.12))),
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
                Text(type,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),

            const Spacer(),

            // Time
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(_formatTime(t['date_heure']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ]),

            // Qty badge
            if (qty > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: navyMid.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: navyMid.withOpacity(0.15)),
                ),
                child: Text('×$qty',
                    style: const TextStyle(color: navyMid,
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),

        // ── Bottom: route + price ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [

            // Route info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stops
                Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF16A34A), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(t['point_depart'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14, color: navyDark))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward,
                        size: 13, color: Colors.grey.shade300),
                  ),
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: Colors.transparent, shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade400, width: 2),
                      )),
                  const SizedBox(width: 6),
                  Flexible(child: Text(t['point_arrivee'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14, color: navyDark))),
                ]),

                const SizedBox(height: 8),

                // Segment + ligne row
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: navyMid.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: navyMid.withOpacity(0.15)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.route, size: 11, color: navyMid),
                      const SizedBox(width: 4),
                      Text('Segment ${t['segment_ordre']}',
                          style: const TextStyle(fontSize: 11,
                              color: navyMid, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (t['nom_ligne'] != null) ...[
                    const SizedBox(width: 8),
                    Flexible(child: Text(t['nom_ligne'],
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade500))),
                  ],
                ]),

                // Agent
                if (t['agent'] != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(t['agent'],
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade500)),
                  ]),
                ],
              ],
            )),

            const SizedBox(width: 16),

            // Price
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (qty > 1)
                Text('${t['prix_unitaire']} ms / ticket',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(height: 2),
              Text(
                isFree ? 'GRATUIT' : '${t['montant_total']} ms',
                style: TextStyle(
                  fontSize: isFree ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: isFree ? const Color(0xFF16A34A) : navyDark,
                ),
              ),
              if (!isFree)
                Text('millimes',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: TextStyle(fontSize: 10,
              color: Colors.grey.shade400, letterSpacing: 0.3)),
    ]));
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: navyMid.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.receipt_long_rounded,
            color: navyMid, size: 40),
      ),
      const SizedBox(height: 16),
      const Text('Aucun ticket vendu',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: navyDark)),
      const SizedBox(height: 6),
      Text('Les tickets vendus apparaîtront ici',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    ]));
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.shade50, shape: BoxShape.circle,
          ),
          child: Icon(Icons.wifi_off_rounded,
              color: Colors.red.shade400, size: 44),
        ),
        const SizedBox(height: 16),
        Text(errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _fetchTickets,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [navyDark, navyLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: navyMid.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Row(mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.refresh, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Réessayer',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    ));
  }
}