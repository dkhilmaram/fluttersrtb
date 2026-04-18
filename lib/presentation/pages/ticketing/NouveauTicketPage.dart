import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/repositories/ticket_repository.dart';
import '../../../data/database/daos/voyage_dao.dart';
import '../../../core/constants/api_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/language_switcher.dart';
// Add import
import '../../widgets/offline_toast_notification.dart';


// ── Brand colours ───────────────────────────────────────────────────────────
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color gold      = Color(0xFFD4A017);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

// ── Widget ──────────────────────────────────────────────────────────────────

class NouveauTicketPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final bool embeddedMode;
  final VoidCallback? onOpenGratuit;
  final VoidCallback? onTicketSold;

  const NouveauTicketPage({
    super.key,
    required this.voyage,
    this.embeddedMode = false,
    this.onOpenGratuit,
    this.onTicketSold,
  });

  @override
  State<NouveauTicketPage> createState() => NouveauTicketPageState();
}

/// Public state so TicketingPage can call resetAfterGratuit() via GlobalKey.
class NouveauTicketPageState extends State<NouveauTicketPage> {
  String? pointDepart;
  String? pointArrivee;
  String? typeTarif;
  int quantite = 1;

  List<String> arrets = [];
  Map<String, int> prixMap = {};
  List<Map<String, dynamic>> tarifTypes = [];

  bool isLoading = true;
  bool isSaving  = false;
  bool isOffline = false;
  String? errorMessage;

  int ticketsVendus = 0;
  int montantTotal  = 0;
  int _minDepartureIndex = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastTimer = null;
    try { _toastEntry?.remove(); } catch (_) {}
    _toastEntry = null;
    super.dispose();
  }

  // ── Public reset (called by parent after gratuit save) ────────────────────

  void resetAfterGratuit() {
    if (!mounted) return;
    final currentDepart = pointDepart;
    setState(() {
      if (currentDepart != null) {
        final usedIndex = arrets.indexOf(currentDepart);
        if (usedIndex >= 0) _minDepartureIndex = usedIndex;
      }
      pointArrivee = null;
      quantite     = 1;
    });
  }

  // ── Toast ─────────────────────────────────────────────────────────────────

  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    try { _toastEntry?.remove(); } catch (_) {}
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
            ? Colors.orange.shade700
            : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.offline_bolt
            : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: [_ToastWidget(msg: msg, color: color, icon: icon)],
      ),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);

    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (_toastEntry == entry) {
        try { entry.remove(); } catch (_) {}
        if (mounted) _toastEntry = null;
      }
    });
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    final idLigne = widget.voyage['id_ligne'] as int;
    final idVente = widget.voyage['id'] as int?;

    List<String>? segmentArrets;

    // 1. Try to load segment stops for this voyage
    if (idVente != null) {
      try {
        final r = await http
            .get(Uri.parse(
                '${ApiConstants.billetterie}/voyages/$idVente/arrets'))
            .timeout(ApiConstants.defaultTimeout);
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body) as Map<String, dynamic>;
          if (d['success'] == true) {
            segmentArrets = List<String>.from(d['arrets'] as List);
          }
        }
      } catch (_) {}
    }

    // 2. Try to load line tarifs from server
    try {
      final r = await http
          .get(Uri.parse(
              '${ApiConstants.billetterie}/ligne/$idLigne/tarifs'))
          .timeout(ApiConstants.defaultTimeout);
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        if (d['success'] == true) {
          if (segmentArrets != null && segmentArrets.isNotEmpty) {
            d['arrets'] = segmentArrets;
          }
          await VoyageDao.saveTarifs(idLigne, d);
          if (mounted) _applyTarifs(d, fromCache: false);
          return;
        }
      }
    } catch (_) {}

    // 3. Fallback: cache
    final cached = await VoyageDao.getTarifs(idLigne);
    if (cached != null) {
      if (segmentArrets == null && idVente != null) {
        final segCache = await VoyageDao.getSegments(idVente);
        if (segCache != null) {
          final segs = (segCache['segments'] as List<dynamic>?) ?? [];
          if (segs.isNotEmpty) {
            final sorted = List<Map<String, dynamic>>.from(
                segs.map((s) => s as Map<String, dynamic>))
              ..sort((a, b) =>
                  (a['ordre'] as int).compareTo(b['ordre'] as int));
            segmentArrets = [
              for (final s in sorted) s['point_depart'] as String,
              sorted.last['point_arrivee'] as String,
            ];
          }
        }
      }
      if (segmentArrets != null && segmentArrets.isNotEmpty) {
        cached['arrets'] = segmentArrets;
      }
      if (mounted) _applyTarifs(cached, fromCache: true);
    } else {
      if (mounted) {
        setState(() {
          errorMessage =
              AppLocalizations.of(context)!.horsLignePasDeCacheErreur;
          isLoading = false;
        });
      }
    }
  }

  void _applyTarifs(Map<String, dynamic> data, {required bool fromCache}) {
    final rawArrets     = List<String>.from(data['arrets'] as List);
    final orderedArrets = _orderArretsByDirection(rawArrets);
    final defaultDepart = orderedArrets.isNotEmpty ? orderedArrets.first : null;

    // Keep ALL tarif types (including pourcentage == 0); filtering at display time.
    final allTarifTypes =
        List<Map<String, dynamic>>.from(data['tarif_types'] as List);

    setState(() {
      isOffline    = fromCache;
      arrets       = orderedArrets;
      prixMap      = Map<String, int>.from(
        (data['prix_map'] as Map)
            .map((k, v) => MapEntry(k.toString(), v as int)),
      );
      tarifTypes   = allTarifTypes;
      isLoading    = false;
      pointDepart  = defaultDepart;
      pointArrivee = null;
      _minDepartureIndex = 0;

      // Default to 'Normal' tarif if available
      final normalTarif = tarifTypes.firstWhere(
        (tarif) =>
            (tarif['type_tarif'] as String).toLowerCase() == 'normal',
        orElse: () => tarifTypes.isNotEmpty ? tarifTypes.first : {},
      );
      if (normalTarif.isNotEmpty) {
        typeTarif = normalTarif['type_tarif'] as String;
      }
    });

    if (fromCache && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OfflineToastNotification.show(context);
      });
    }
  }

  /// Ensures stops are in departure→arrival order based on voyage metadata.
  List<String> _orderArretsByDirection(List<String> raw) {
    if (raw.isEmpty) return raw;
    final voyageArrivee = widget.voyage['arrivee'] as String? ?? '';
    if (raw.last.trim().toLowerCase() !=
        voyageArrivee.trim().toLowerCase()) {
      return raw.reversed.toList();
    }
    return raw;
  }

  // ── Computed getters ──────────────────────────────────────────────────────

  List<String> get _departureArrets {
    if (arrets.isEmpty) return [];
    final from = _minDepartureIndex.clamp(0, arrets.length - 1);
    if (from >= arrets.length - 1) return [];
    return arrets.sublist(from, arrets.length - 1);
  }

  List<String> get _arrivalArrets {
    if (pointDepart == null) return [];
    final idx = arrets.indexOf(pointDepart!);
    if (idx == -1 || idx >= arrets.length - 1) return [];
    return arrets.sublist(idx + 1);
  }

  int? get _prixNormal {
    if (pointDepart == null ||
        pointArrivee == null ||
        pointDepart == pointArrivee) return null;
    return prixMap['$pointDepart|$pointArrivee'] ??
        prixMap['$pointArrivee|$pointDepart'];
  }

  int? get _prixUnitaire {
    final base = _prixNormal;
    if (base == null || typeTarif == null) return null;
    final tarif = tarifTypes.firstWhere(
      (t) => t['type_tarif'] == typeTarif,
      orElse: () => {},
    );
    if (tarif.isEmpty) return null;
    return (base * (tarif['pourcentage'] as int) / 100).round();
  }

  int? get _prixTotal =>
      _prixUnitaire != null ? _prixUnitaire! * quantite : null;

  int get _discountPct {
    if (typeTarif == null) return 0;
    final tarif = tarifTypes.firstWhere(
      (t) => t['type_tarif'] == typeTarif,
      orElse: () => {},
    );
    if (tarif.isEmpty) return 0;
    return 100 - (tarif['pourcentage'] as int);
  }

  bool get _canValidate =>
      typeTarif != null &&
      pointDepart != null &&
      pointArrivee != null &&
      pointDepart != pointArrivee &&
      _prixUnitaire != null;

  bool get _canGratuit =>
      pointDepart != null &&
      pointArrivee != null &&
      pointDepart != pointArrivee;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _openGratuit() {
    if (!_canGratuit) return;
    widget.onOpenGratuit?.call();
  }

  void _vendreTicket() {
    if (!_canValidate) return;
    final t = AppLocalizations.of(context)!;

    // Snapshot all values before async gap / dialog
    final snapDep   = pointDepart!;
    final snapArr   = pointArrivee!;
    final snapTarif = typeTarif!;
    final snapQte   = quantite;
    final snapPrixU = _prixUnitaire!;
    final snapPrixT = _prixTotal!;
    final snapNorm  = _prixNormal;
    final snapDisc  = _discountPct;
    final snapAgent = widget.voyage['matricule_agent'] ?? 0;
    final snapVente = widget.voyage['id'] ?? 0;
    final snapSeg   = widget.voyage['id_segment'] ?? 0;
    final snapDate  = DateTime.now().toIso8601String();
    final isFree    = snapPrixT == 0;

    final qrPayload = jsonEncode({
      'vente': snapVente,
      'seg':   snapSeg,
      'dep':   snapDep,
      'arr':   snapArr,
      'tarif': snapTarif,
      'qty':   snapQte,
      'pu':    snapPrixU,
      'total': snapPrixT,
      'agent': snapAgent,
      'date':  snapDate,
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header icon ─────────────────────────────────────────
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [navyDark, navyLight]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.confirmation_number,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.confirmerTicket,
                  style: const TextStyle(
                    color: navyDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Recap rows ──────────────────────────────────────────
                _confirmRow(Icons.trip_origin,          t.monteeLabel,   snapDep),
                _dividerLine(),
                _confirmRow(Icons.location_on_outlined, t.descenteLabel, snapArr),
                _dividerLine(),
                _confirmRow(Icons.sell_outlined,        t.tarifLabel,   snapTarif),
                _dividerLine(),
                _confirmRow(
                  Icons.people_outline,
                  t.quantiteLabel,
                  '$snapQte ${snapQte > 1 ? t.ticketPluriel : t.ticketSingulier}',
                ),
                const SizedBox(height: 16),

                // ── Price summary ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isFree
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFEFF3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      if (snapDisc > 0 && snapNorm != null)
                        Text(
                          '${snapNorm * snapQte} ${t.millimes}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (snapQte > 1)
                        Text(
                          '$snapQte × $snapPrixU ${t.millimes}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                        ),
                      Text(
                        isFree
                            ? t.gratuit
                            : '$snapPrixT ${t.millimes}',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isFree
                              ? const Color(0xFF16A34A)
                              : navyDark,
                        ),
                      ),
                      if (snapDisc > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            t.pourcentageApplique(snapDisc),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── QR code ─────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: navyMid,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.qrCodeTicket,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: navyDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: navyMid.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: navyDark),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: navyDark),
                    ),
                  ),
                ),

                // ── Offline notice ───────────────────────────────────────
                if (isOffline) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.offline_bolt,
                            size: 13,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.horsLigneSynchronise,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // ── Buttons ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          side: BorderSide(
                              color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        child: Text(
                          t.annuler,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveTicket(
                            snapDep:   snapDep,
                            snapArr:   snapArr,
                            snapTarif: snapTarif,
                            snapQte:   snapQte,
                            snapPrixU: snapPrixU,
                            snapPrixT: snapPrixT,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyMid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        child: Text(
                          t.valider,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Save ticket ───────────────────────────────────────────────────────────

  Future<void> _saveTicket({
    required String snapDep,
    required String snapArr,
    required String snapTarif,
    required int snapQte,
    required int snapPrixU,
    required int snapPrixT,
  }) async {
    final idVente   = widget.voyage['id'] as int?;
    final idSegment = widget.voyage['id_segment'] as int?;
    final matricule = widget.voyage['matricule_agent'] as int?;

    if (idVente == null) {
      OfflineToastNotification.show(context);
      return;
    }

    if (!mounted) return;
    setState(() => isSaving = true);

    final result = await TicketRepository.saveTicket({
      'id_voyage':       idVente,
      'id_segment':      idSegment ?? 0,
      'point_depart':    snapDep,
      'point_arrivee':   snapArr,
      'type_tarif':      snapTarif,
      'quantite':        snapQte,
      'prix_unitaire':   snapPrixU,
      'montant_total':   snapPrixT,
      'matricule_agent': matricule ?? 0,
    });

    if (!mounted) return;
    final t = AppLocalizations.of(context)!;

    if (result.success) {
      final usedIndex = arrets.indexOf(snapDep);
      setState(() {
        ticketsVendus += snapQte;
        montantTotal  += snapPrixT;
        if (usedIndex >= 0) _minDepartureIndex = usedIndex;
        pointArrivee = null;
        quantite     = 1;
        isOffline    = result.wasOffline;
      });

      if (result.wasOffline) {
        _showToast(t.horsLigneTicketSauvegarde, isWarning: true);
      } else {
        _showToast(
          snapPrixT == 0
              ? t.passagesGratuitsEnregistres(snapQte)
              : t.ticketsVendusToast(snapQte, snapPrixT),
        );
      }

      widget.onTicketSold?.call();
    } else {
      _showToast(
        t.ticketErreur(result.error ?? t.inconnu),
        isError: true,
      );
    }

    if (mounted) setState(() => isSaving = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t             = AppLocalizations.of(context)!;
    final voyageDepart  = widget.voyage['depart']  ?? '?';
    final voyageArrivee = widget.voyage['arrivee'] ?? '?';

    final body = SingleChildScrollView(
      child: Column(
        children: [
          // ── Standalone header ────────────────────────────────────────
          if (!widget.embeddedMode)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [navyDark, navyMid, navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
              child: Column(
                children: [
                  // Back button  ←  spacer  →  language switcher
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const LanguageSwitcher(),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Logo
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
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_bus,
                        size: 44,
                        color: navyMid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Brand name
                  Text(
                    t.srtbLetters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle + offline badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.billetterie,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.offline_bolt,
                                  color: Colors.white, size: 10),
                              const SizedBox(width: 4),
                              Text(
                                t.modeHorsLigne.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Route pill
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
                              color: goldLight,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          voyageDepart,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.white.withOpacity(0.4),
                            size: 13,
                          ),
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: goldLight, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          voyageArrivee,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Counter bar ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: navyMid.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _counterTile(
                    Icons.confirmation_number_outlined,
                    t.ticketsVendusLabel,
                    '$ticketsVendus',
                    navyMid,
                  ),
                ),
                Container(
                    width: 1, height: 36, color: Colors.grey.shade100),
                Expanded(
                  child: _counterTile(
                    Icons.account_balance_wallet_outlined,
                    t.totalCollecte,
                    '$montantTotal ${t.millimes}',
                    const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),

          // ── Main form ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: CircularProgressIndicator(color: navyMid),
                    ),
                  )
                : errorMessage != null
                    ? _buildErrorState(t)
                    : _buildForm(t),
          ),
        ],
      ),
    );

    if (widget.embeddedMode) return body;
    return Scaffold(backgroundColor: surface, body: body);
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 52, color: Colors.orange.shade200),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  isLoading    = true;
                  errorMessage = null;
                });
                _fetchData();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(t.reessayer),
              style: TextButton.styleFrom(foregroundColor: navyMid),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Offline banner
        if (isOffline) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.sync, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    t.horsLigneActionsSync,
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Tarif grid
        _label(t.typeDeTarif),
        const SizedBox(height: 10),
        _buildTarifGrid(t),
        const SizedBox(height: 22),

        // Trajet dropdowns
        _label(t.trajetLabel),
        const SizedBox(height: 10),
        _card(
          child: Column(
            children: [
              _dropdownRow(
                icon: Icons.trip_origin,
                iconColor: const Color(0xFF16A34A),
                label: t.pointDeMontee,
                hint: t.choisirArret,
                value: pointDepart,
                items: _departureArrets,
                onChanged: (v) => setState(() {
                  pointDepart  = v;
                  pointArrivee = null;
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    Container(
                        width: 1.5,
                        height: 22,
                        color: Colors.grey.shade200),
                  ],
                ),
              ),
              _dropdownRow(
                icon: Icons.location_on,
                iconColor: Colors.red.shade500,
                label: t.pointDeDescente,
                hint: pointDepart == null
                    ? t.choisirDabordMontee
                    : _arrivalArrets.isEmpty
                        ? t.aucunArretDisponible
                        : t.choisirArret,
                value: pointArrivee,
                items: _arrivalArrets,
                onChanged: pointDepart == null
                    ? null
                    : (v) => setState(() => pointArrivee = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Quantity picker
        _label(t.nombreDeTickets),
        const SizedBox(height: 10),
        _card(
          child: Row(
            children: [
              _qtyBtn(
                  Icons.remove, quantite > 1, () => setState(() => quantite--)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$quantite',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    Text(
                      quantite == 1 ? t.ticketSingulier : t.ticketPluriel,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              _qtyBtn(Icons.add, true, () => setState(() => quantite++)),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Price preview
        if (_prixUnitaire != null) ...[
          _PriceCard(
            prixNormal:   _prixNormal,
            prixUnitaire: _prixUnitaire!,
            prixTotal:    _prixTotal!,
            quantite:     quantite,
            discountPct:  _discountPct,
          ),
          const SizedBox(height: 16),
        ],

        // Validate button
        _actionBtn(
          label: isSaving
              ? t.enregistrement
              : quantite > 1
                  ? t.validerTickets(quantite)
                  : t.validerLeTicket,
          icon: isSaving ? null : Icons.confirmation_number_rounded,
          isLoading: isSaving,
          enabled: _canValidate && !isSaving,
          colors: [navyDark, navyLight],
          onTap: _vendreTicket,
        ),
      ],
    );
  }

  // ── Tarif grid ────────────────────────────────────────────────────────────

  Widget _buildTarifGrid(AppLocalizations t) {
    final filtered = tarifTypes
        .where((tarif) =>
            (tarif['type_tarif'] as String).toLowerCase() != 'gratuit')
        .toList();
    final itemCount = filtered.length + 1; // +1 for Passage Gratuit chip

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3.8,
      ),
      itemBuilder: (_, i) {
        if (i == filtered.length) return _buildGratuitChip(t);

        final type     = filtered[i]['type_tarif'] as String;
        final pct      = filtered[i]['pourcentage'] as int;
        final discount = 100 - pct;
        final isSel    = typeTarif == type;
        final Color accent = pct <= 25
            ? const Color(0xFF7C3AED)
            : pct <= 50
                ? const Color(0xFFD97706)
                : navyMid;

        return GestureDetector(
          onTap: () => setState(() => typeTarif = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSel ? accent : cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? accent : accent.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    discount > 0
                        ? Icons.discount_rounded
                        : Icons.person_rounded,
                    color: isSel ? Colors.white : accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (discount > 0) _tarifBadge('−$discount%', accent, isSel),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Passage Gratuit chip ──────────────────────────────────────────────────

  Widget _buildGratuitChip(AppLocalizations t) {
    const Color accentGreen = Color(0xFF059669);
    final bool enabled = _canGratuit;

    return GestureDetector(
      onTap: enabled ? _openGratuit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? accentGreen : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accentGreen.withOpacity(0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                enabled
                    ? Icons.card_membership_rounded
                    : Icons.lock_rounded,
                color: enabled ? Colors.white : Colors.grey.shade400,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.passageGratuit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),
              if (!enabled)
                Icon(Icons.chevron_right,
                    size: 14, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable sub-widgets ──────────────────────────────────────────────────

  Widget _tarifBadge(String text, Color accent, bool isSel) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSel
              ? Colors.white.withOpacity(0.25)
              : accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isSel ? Colors.white : accent,
          ),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: navyDark,
          letterSpacing: 0.5,
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: navyMid.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );

  Widget _counterTile(
          IconData icon, String label, String value, Color color) =>
      Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
                letterSpacing: 0.3),
          ),
        ],
      );

  Widget _confirmRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 15, color: navyLight.withOpacity(0.6)),
            const SizedBox(width: 10),
            Text(
              '$label  ',
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: navyDark,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dividerLine() =>
      Divider(height: 1, color: Colors.grey.shade100);

  Widget _dropdownRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    final effectiveValue =
        (value != null && items.contains(value)) ? value : null;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: effectiveValue,
                  hint: Text(hint,
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
                  isExpanded: true,
                  isDense: true,
                  icon: Icon(
                    Icons.expand_more,
                    color: onChanged == null
                        ? Colors.grey.shade300
                        : navyLight.withOpacity(0.5),
                    size: 18,
                  ),
                  style: const TextStyle(
                    color: navyDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: onChanged,
                  items: items
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(a,
                                style: const TextStyle(
                                    color: navyDark, fontSize: 13)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? navyMid : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: navyMid.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.grey.shade300,
            size: 18,
          ),
        ),
      );

  Widget _actionBtn({
    required String label,
    required IconData? icon,
    required bool isLoading,
    required bool enabled,
    required List<Color> colors,
    required VoidCallback onTap,
  }) =>
      SizedBox(
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
                        color: enabled
                            ? Colors.white
                            : Colors.grey.shade400,
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

// ── Price card ───────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final int? prixNormal;
  final int prixUnitaire, prixTotal, quantite, discountPct;

  const _PriceCard({
    required this.prixNormal,
    required this.prixUnitaire,
    required this.prixTotal,
    required this.quantite,
    required this.discountPct,
  });

  @override
  Widget build(BuildContext context) {
    final t      = AppLocalizations.of(context)!;
    final isFree = prixTotal == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        gradient: isFree
            ? const LinearGradient(
                colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFEBF0FF), Color(0xFFF2F5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isFree ? const Color(0xFF86EFAC) : const Color(0xFFB8C8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            isFree ? t.gratuit : '$prixTotal ${t.millimes}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: isFree ? const Color(0xFF16A34A) : navyDark,
            ),
          ),
          if (quantite > 1 || discountPct > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (quantite > 1)
                  _pill('$quantite × $prixUnitaire ${t.millimes}', navyMid),
                if (discountPct > 0)
                  _pill('−$discountPct%', Colors.orange.shade700),
                if (discountPct > 0 && prixNormal != null)
                  Text(
                    '${prixNormal! * quantite} ${t.millimes}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700),
        ),
      );
}

// ── Toast widget ─────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color  color;
  final IconData icon;

  const _ToastWidget(
      {required this.msg, required this.color, required this.icon});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _opacity =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, right: 16),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.msg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}