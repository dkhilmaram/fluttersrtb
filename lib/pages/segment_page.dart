import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'nouveauticketPage.dart';

const Color srtbBlue = Color(0xFF1A3F7A);
const Color srtbAccent = Color(0xFF2563EB);

class SegmentPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const SegmentPage({super.key, required this.voyage});

  @override
  State<SegmentPage> createState() => _SegmentPageState();
}

class _SegmentPageState extends State<SegmentPage> {
  Map<String, dynamic>? segmentActif;
  Map<String, dynamic>? prochainSegment;
  List<dynamic> tousSegments = [];
  bool tousClotures = false;
  bool isLoading = true;
  bool isActioning = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final id = widget.voyage['id'] as int?;
      if (id == null) throw Exception("ID du voyage manquant");

      final r1 = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/segment/actif'),
      );
      final r2 = await http.get(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/segments'),
      );

      if (r1.statusCode == 200 && r2.statusCode == 200) {
        final d1 = jsonDecode(r1.body);
        final d2 = jsonDecode(r2.body);
        if (d1['success'] == true) {
          setState(() {
            segmentActif    = d1['segment'] as Map<String, dynamic>?;
            prochainSegment = d1['prochain'] as Map<String, dynamic>?;
            tousClotures    = d1['tous_clotures'] == true;
            tousSegments    = d2['segments'] as List<dynamic>? ?? [];
            isLoading = false;
          });
        } else {
          throw Exception(d1['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur serveur (${r1.statusCode})');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _ouvrirProchainSegment() async {
    setState(() => isActioning = true);
    try {
      final id = widget.voyage['id'] as int?;
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/segment/ouvrir'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnack('Segment ouvert ✓', Colors.green);
        await _fetchAll();
      } else {
        _showSnack(data['message'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    }
    setState(() => isActioning = false);
  }

  Future<void> _cloturerSegmentActif() async {
    if (segmentActif == null) return;
    setState(() => isActioning = true);
    try {
      final id    = widget.voyage['id'] as int?;
      final idSeg = segmentActif!['id_segment'] as int?;
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/billetterie/voyages/$id/segments/$idSeg/cloturer'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnack('Segment clôturé ✓', Colors.orange);
        await _fetchAll();
      } else {
        _showSnack(data['message'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    }
    setState(() => isActioning = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  void _confirmCloture() {
    if (segmentActif == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Clôturer ?', style: TextStyle(color: srtbBlue, fontSize: 18)),
        ]),
        content: Text(
          '${segmentActif!['point_depart']} → ${segmentActif!['point_arrivee']}\n\nConfirmez-vous la clôture de ce segment ?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () { Navigator.pop(context); _cloturerSegmentActif(); },
            child: const Text('Clôturer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _goToSellTickets() {
    if (segmentActif == null) { _showSnack("Aucun segment actif", Colors.red); return; }
    final idLigne = widget.voyage['id_ligne'] as int?;
    if (idLigne == null) { _showSnack("Ligne introuvable", Colors.red); return; }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NouveauTicketPage(
        voyage: {
          ...widget.voyage,
          'depart':     segmentActif!['point_depart'],
          'arrivee':    segmentActif!['point_arrivee'],
          'id_segment': segmentActif!['id_segment'],
          'id_ligne':   idLigne,
        },
      ),
    ));
  }

  Color _statutColor(String s) {
    switch (s) {
      case 'actif':   return const Color(0xFF16A34A);
      case 'cloture': return Colors.grey.shade500;
      default:        return const Color(0xFFD97706);
    }
  }

  String _statutLabel(String s) {
    switch (s) {
      case 'actif':   return 'ACTIF';
      case 'cloture': return 'CLÔTURÉ';
      default:        return 'EN ATTENTE';
    }
  }

  IconData _statutIcon(String s) {
    switch (s) {
      case 'actif':   return Icons.play_circle_filled;
      case 'cloture': return Icons.check_circle;
      default:        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final departGlobal  = widget.voyage['depart']  ?? '?';
    final arriveeGlobal = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: SafeArea(
        child: Column(
          children: [
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
                    onPressed: _fetchAll,
                  ),
                ]),
                const SizedBox(height: 4),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_srtb.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.directions_bus, size: 44, color: srtbBlue),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('S R T B', style: TextStyle(
                  color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.bold, letterSpacing: 5,
                )),
                const SizedBox(height: 8),
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
                      '$departGlobal  →  $arriveeGlobal',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── Body ──
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: srtbBlue))
                  : errorMessage != null
                      ? _buildError()
                      : RefreshIndicator(
                          color: srtbBlue,
                          onRefresh: _fetchAll,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                // ── Active segment ──
                                if (segmentActif != null) ...[
                                  _sectionLabel('Segment en cours', Icons.play_circle_filled, const Color(0xFF16A34A)),
                                  const SizedBox(height: 10),
                                  _buildActiveCard(),
                                  const SizedBox(height: 16),

                                  // ── BIG Nouveau Ticket button ──
                                  _BigPrimaryButton(
                                    label: 'Nouveau Ticket',
                                    sublabel: '${segmentActif!['point_depart']} → ${segmentActif!['point_arrivee']}',
                                    icon: Icons.confirmation_number_rounded,
                                    color: srtbBlue,
                                    onPressed: _goToSellTickets,
                                  ),
                                  const SizedBox(height: 12),

                                  // ── BIG Clôturer button ──
                                  _BigPrimaryButton(
                                    label: 'Clôturer ce segment',
                                    sublabel: 'Terminer et passer au suivant',
                                    icon: Icons.check_circle_outline_rounded,
                                    color: const Color(0xFFEA580C),
                                    onPressed: _confirmCloture,
                                    isLoading: isActioning,
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // ── Next segment ──
                                if (segmentActif == null && !tousClotures && prochainSegment != null) ...[
                                  _sectionLabel('Prochain segment', Icons.skip_next_rounded, const Color(0xFFD97706)),
                                  const SizedBox(height: 10),
                                  _buildWaitingCard(),
                                  const SizedBox(height: 16),
                                  _BigPrimaryButton(
                                    label: 'Ouvrir ce segment',
                                    sublabel: 'Démarrer la vente de tickets',
                                    icon: Icons.play_arrow_rounded,
                                    color: const Color(0xFF16A34A),
                                    onPressed: _ouvrirProchainSegment,
                                    isLoading: isActioning,
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // ── All done ──
                                if (tousClotures) ...[
                                  _buildAllDone(),
                                  const SizedBox(height: 24),
                                ],

                                // ── Timeline ──
                                if (tousSegments.isNotEmpty) ...[
                                  _sectionLabel('Tous les segments (${tousSegments.length})', Icons.route, srtbBlue),
                                  const SizedBox(height: 10),
                                  _buildTimeline(),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.directions_bus, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(
              segmentActif!['point_depart'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF14532D)),
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF16A34A)),
            ),
            Flexible(child: Text(
              segmentActif!['point_arrivee'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF14532D)),
            )),
          ]),
          if (segmentActif!['date_ouverture'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ouvert : ${segmentActif!['date_ouverture']}',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700),
            ),
          ],
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('ACTIF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.schedule, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(
              prochainSegment!['point_depart'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF78350F)),
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFFD97706)),
            ),
            Flexible(child: Text(
              prochainSegment!['point_arrivee'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF78350F)),
            )),
          ]),
          const SizedBox(height: 4),
          Text('Prêt à ouvrir', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('EN ATTENTE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tousSegments.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 64, endIndent: 16),
        itemBuilder: (_, i) {
          final s      = tousSegments[i] as Map<String, dynamic>;
          final statut = s['statut'] as String? ?? 'en_attente';
          final color  = _statutColor(statut);
          final isLast = i == tousSegments.length - 1;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              // Step indicator
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(child: Text(
                    '${s['ordre']}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  )),
                ),
                if (!isLast)
                  Container(
                    width: 2, height: 20,
                    color: color.withOpacity(0.2),
                    margin: const EdgeInsets.only(top: 4),
                  ),
              ]),
              const SizedBox(width: 14),

              // Route info
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(s['point_depart'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 13, color: Colors.grey),
                  ),
                  Flexible(child: Text(s['point_arrivee'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                ]),
                if (s['date_ouverture'] != null) ...[
                  const SizedBox(height: 3),
                  Text('Ouvert : ${s['date_ouverture']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
                if (s['date_cloture'] != null) ...[
                  const SizedBox(height: 2),
                  Text('Clôturé : ${s['date_cloture']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ])),
              const SizedBox(width: 8),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statutIcon(statut), color: color, size: 12),
                  const SizedBox(width: 4),
                  Text(_statutLabel(statut),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: color,
        letterSpacing: 0.3,
      )),
    ]);
  }

  Widget _buildAllDone() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(children: const [
        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 64),
        SizedBox(height: 14),
        Text('Tous les segments sont clôturés',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
            textAlign: TextAlign.center),
        SizedBox(height: 6),
        Text('Vous pouvez maintenant clôturer le voyage',
            style: TextStyle(color: Color(0xFF16A34A), fontSize: 13),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
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
              backgroundColor: srtbBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _fetchAll,
          ),
        ]),
      ),
    );
  }
}

// ── Big Primary Button ──
class _BigPrimaryButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _BigPrimaryButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                )),
                const SizedBox(height: 2),
                Text(sublabel, style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12,
                )),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.6), size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}