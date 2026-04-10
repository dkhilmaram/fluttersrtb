import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../local_database.dart';

const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color gold      = Color(0xFFD4A017);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

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

  // ── Main entry point ──
  Future<void> _cloturerVoyage() async {
    setState(() => isCloturing = true);
    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline) {
        await _cloturerOnline();
      } else {
        await _cloturerOffline();
      }
    } catch (e) {
      setState(() => isCloturing = false);
      if (mounted) _showSnack('Erreur inattendue', isError: true);
    }
  }

  // ── Online: call server, update local cache ──
  Future<void> _cloturerOnline() async {
    final id = widget.voyage['id'];
    try {
      final response = await http
          .put(
            Uri.parse(
                'http://192.168.1.22:8000/billetterie/vente/$id/cloturer'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          await LocalDatabase.saveVoyageStatut(id as int, 'cloture');
          _onClotureDone();
        } else {
          setState(() => isCloturing = false);
          if (mounted) {
            _showSnack(data['message'] ?? 'Erreur', isError: true);
          }
        }
      } else {
        // Server returned an error — fall back to offline queue
        await _cloturerOffline();
      }
    } catch (e) {
      // Network error during call — fall back to offline queue
      await _cloturerOffline();
    }
  }

  // ── Offline: save intent locally, sync later ──
  Future<void> _cloturerOffline() async {
    final id = widget.voyage['id'] as int;
    await LocalDatabase.saveCloturePending(id);
    await LocalDatabase.saveVoyageStatut(id, 'cloture_pending');
    if (mounted) {
      _showSnack('Hors ligne — clôture enregistrée, sera envoyée à la reconnexion');
    }
    _onClotureDone();
  }

  // ── Shared success handler ──
  void _onClotureDone() {
    setState(() {
      isCloture = true;
      isCloturing = false;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: Colors.white,
                size: 17,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(14),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7F1D1D),
                    Color(0xFFB91C1C),
                    Color(0xFFDC2626),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: isCloturing ? null : () => Navigator.pop(context),
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
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/logo_srtb.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.directions_bus,
                        size: 44,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'S R T B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fin du Voyage',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Route pill ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: goldLight, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(depart,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward,
                              color: Colors.white.withOpacity(0.4),
                              size: 13),
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: goldLight, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(arrivee,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: isCloture
                  // ── Success state ──
                  ? Column(
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: navyMid.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: navyMid.withOpacity(0.3),
                                width: 2),
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: navyMid, size: 52),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Voyage clôturé !',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: navyDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Retour en cours...',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    )
                  // ── Confirm state ──
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Voyage summary card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: navyLight.withOpacity(0.15),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: navyMid.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voyage en cours',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: navyMid.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                        Icons.directions_bus,
                                        color: navyMid,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$depart → $arrivee',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: navyDark),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                                Icons.access_time_rounded,
                                                size: 11,
                                                color:
                                                    Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_heure  ·  $_date',
                                              style: TextStyle(
                                                  color:
                                                      Colors.grey.shade400,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Warning box ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.red.shade100, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red.shade700,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Attention',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.red.shade700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _warningItem('Cette action est irréversible'),
                              _warningItem(
                                  'Aucune vente ne sera possible après clôture'),
                              _warningItem(
                                  'Le voyage sera marqué comme terminé'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Confirm button ──
                        _actionBtn(
                          label: isCloturing
                              ? 'Clôture en cours...'
                              : 'Confirmer la clôture',
                          icon: isCloturing ? null : Icons.flag_rounded,
                          isLoading: isCloturing,
                          enabled: !isCloturing,
                          colors: const [
                            Color(0xFF7F1D1D),
                            Color(0xFFDC2626),
                          ],
                          onTap: _cloturerVoyage,
                        ),

                        const SizedBox(height: 12),

                        // ── Cancel button ──
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: isCloturing
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: navyMid,
                              side: BorderSide(
                                  color: navyMid.withOpacity(0.3),
                                  width: 1.5),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_new,
                                    size: 14,
                                    color: isCloturing
                                        ? Colors.grey.shade300
                                        : navyMid),
                                const SizedBox(width: 8),
                                Text(
                                  'Annuler',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isCloturing
                                          ? Colors.grey.shade300
                                          : navyMid),
                                ),
                              ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.red.shade700, size: 12),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style:
                  TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData? icon,
    required bool isLoading,
    required bool enabled,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: colors.first.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                else if (icon != null)
                  Icon(icon,
                      color:
                          enabled ? Colors.white : Colors.grey.shade400,
                      size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color:
                        enabled ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}