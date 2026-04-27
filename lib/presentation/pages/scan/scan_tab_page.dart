import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../../../data/repositories/ticket_repository.dart';
import '../../../services/connectivity_service.dart';

// ── Palette aliases ───────────────────────────────────────────
const _navyDark  = AppTheme.navyDark;
const _navyMid   = AppTheme.navyMid;
const _navyLight = AppTheme.navyLight;
const _goldLight = AppTheme.goldLight;

enum _ScanState { idle, loading, success, error }

// ═════════════════════════════════════════════════════════════
// ScanTabPage
// ═════════════════════════════════════════════════════════════

class ScanTabPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;

  const ScanTabPage({
    super.key,
    required this.voyage,
    required this.segment,
  });

  @override
  State<ScanTabPage> createState() => _ScanTabPageState();
}

class _ScanTabPageState extends State<ScanTabPage> {
  _ScanState _scanState = _ScanState.idle;
  Map<String, dynamic>? _nfcData;
  String? _errorMsg;
  bool _isSaving     = false;
  int  _totalScanned = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  AppLocalizations get _l => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

  // ── Toast ─────────────────────────────────────────────────

  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
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
      builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ── Reset ─────────────────────────────────────────────────

  void _reset() => setState(() {
        _scanState = _ScanState.idle;
        _nfcData   = null;
        _errorMsg  = null;
      });

  // ══════════════════════════════════════════════════════════
  // QR scanner — JSON payload only, never touches server
  // ══════════════════════════════════════════════════════════

  Future<void> _openBarcodeScanner() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _CameraScannerPage(l: _l),
        fullscreenDialog: true,
      ),
    );
    if (raw == null || !mounted) return;
    await _resolveQr(raw.trim());
  }

  Future<void> _resolveQr(String raw) async {
    if (!mounted) return;
    setState(() => _scanState = _ScanState.loading);

    try {
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      debugPrint('✅ QR JSON parsed successfully');
      await _applyParsedData(parsed, mode: _l.scanModeQr);
    } catch (_) {
      debugPrint('❌ QR payload is not valid JSON');
      setState(() {
        _scanState = _ScanState.error;
        _errorMsg  = _l.scanIncompleteData;
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  // NFC scanner — UID extracted → server lookup
  // ══════════════════════════════════════════════════════════

  Future<void> _startNfcScan() async {
    final available = await NfcManager.instance.isAvailable();
    if (!mounted) return;
    if (!available) {
      _showToast(_l.scanNfcUnavailable, isWarning: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NfcListeningSheet(l: _l),
    ).then((_) => NfcManager.instance.stopSession().catchError((_) {}));

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          debugPrint('📡 NFC tag data keys: ${tag.data.keys.toList()}');

          final uid = _extractUidFromTag(tag);
          debugPrint('🔑 NFC UID extracted: "$uid"');

          await NfcManager.instance.stopSession();
          HapticFeedback.mediumImpact();

          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          if (uid == null || uid.trim().length < 2) {
            setState(() {
              _scanState = _ScanState.error;
              _errorMsg  = _l.scanNfcUnreadable;
            });
          } else {
            await _resolveNfcByUid(uid.trim().toUpperCase());
          }
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: _l.scanNfcReadError)
              .catchError((_) {});
          if (mounted) {
            setState(() {
              _scanState = _ScanState.error;
              _errorMsg  = _l.scanNfcError(e.toString());
            });
          }
        }
      },
      alertMessage: _l.scanNfcApproach,
    );
  }

  // ── Extract hardware UID from NFC tag ─────────────────────

  String? _extractUidFromTag(NfcTag tag) {
    final data = tag.data;

    String? hexFromField(dynamic field) {
      if (field is List && field.isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(List<int>.from(field));
          return bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final hex =
        hexFromField(data['nfca']?['identifier']) ??
        hexFromField(data['nfcb']?['applicationData']) ??
        hexFromField(data['mifareClassic']?['identifier']) ??
        hexFromField(data['mifareUltralight']?['identifier']) ??
        hexFromField(data['iso7816']?['identifier']) ??
        hexFromField(data['isoDep']?['identifier']) ??
        hexFromField(data['isoDepA']?['identifier']) ??
        hexFromField(data['isoDepB']?['identifier']) ??
        hexFromField(data['feliCa']?['currentIdm']) ??
        hexFromField(data['nfcf']?['manufacturer']) ??
        hexFromField(data['nfcv']?['identifier']);

    debugPrint('🔑 NFC hardware UID (hex): "$hex"');
    return hex;
  }

  // ══════════════════════════════════════════════════════════
  // NFC resolve — calls GET /billetterie/nfc/lookup/{uid}
  //
  // Offline fallback: if the server is unreachable, falls back
  // to the local TicketDao cache so agents can still scan when
  // connectivity is lost.
  // ══════════════════════════════════════════════════════════

  Future<void> _resolveNfcByUid(String uid) async {
    if (!mounted) return;
    setState(() => _scanState = _ScanState.loading);

    debugPrint('🔎 NFC server lookup for UID: "$uid"');

    final isOnline = await ConnectivityService.isOnline();

    if (isOnline) {
      // ── Online path: ask the server ──────────────────────
      try {
        final uri      = Uri.parse(ApiConstants.nfcLookup(uid));
        final response = await http
            .get(uri)
            .timeout(ApiConstants.defaultTimeout);

        if (!mounted) return;

        if (response.statusCode == 404) {
          debugPrint('❌ UID not found on server: "$uid"');
          setState(() {
            _scanState = _ScanState.error;
            _errorMsg  = _l.scanCardNotFound(uid);
          });
          return;
        }

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final card = Map<String, dynamic>.from(
            jsonDecode(response.body) as Map);
        debugPrint('✅ UID found on server: $card');
        await _applyParsedData(card, mode: _l.scanModeNfc);
      } catch (e) {
        debugPrint('⚠️ Server lookup failed, trying local cache: $e');
        // Server reachable but threw — fall through to local
        await _resolveNfcFromLocal(uid);
      }
    } else {
      // ── Offline path: local cache only ───────────────────
      debugPrint('📴 Offline — using local NFC cache for "$uid"');
      await _resolveNfcFromLocal(uid);
    }
  }

  /// Local fallback (TicketDao cache, populated when online).
  Future<void> _resolveNfcFromLocal(String uid) async {
    try {
      final card = await TicketDao.findByCardId(uid);
      if (!mounted) return;

      if (card == null) {
        setState(() {
          _scanState = _ScanState.error;
          _errorMsg  = _l.scanCardNotFound(uid);
        });
        return;
      }

      _showToast(_l.scanOfflineCacheUsed, isWarning: true);
      await _applyParsedData(
        {
          'id':        uid,
          'nom':       card['nom']       ?? _l.scanUnknown,
          'type':      card['type']      ?? _l.scanUnknown,
          'expire':    card['expire']    ?? '',
          'ligne':     card['ligne']     ?? '—',
          'organisme': card['organisme'] ?? '—',
        },
        mode: _l.scanModeNfc,
      );
    } catch (e) {
      debugPrint('❌ Local cache error: $e');
      if (mounted) {
        setState(() {
          _scanState = _ScanState.error;
          _errorMsg  = _l.scanLookupError(e.toString());
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // Apply parsed data (shared by QR and NFC)
  // ══════════════════════════════════════════════════════════

  Future<void> _applyParsedData(
    Map<String, dynamic> data, {
    required String mode,
  }) async {
    final id        = data['id']?.toString()        ?? '';
    final nom       = data['nom']?.toString()       ?? _l.scanUnknown;
    final type      = data['type']?.toString()      ?? _l.scanUnknown;
    final expire    = data['expire']?.toString()    ?? '';
    final ligne     = data['ligne']?.toString()     ?? '—';
    final organisme = data['organisme']?.toString() ?? '—';

    if (id.isEmpty || type.isEmpty || expire.isEmpty) {
      setState(() {
        _scanState = _ScanState.error;
        _errorMsg  = _l.scanIncompleteData;
      });
      return;
    }

    // ── Duplicate check ───────────────────────────────────
    final idVoyage = widget.voyage['id'] as int? ?? 0;
    final alreadyScanned = await TicketDao.isAlreadyScannedToday(
      numeroTitre: id,
      idVoyage:    idVoyage,
    );
    if (!mounted) return;

    if (alreadyScanned) {
      setState(() {
        _scanState = _ScanState.error;
        _errorMsg  = _l.scanAlreadyValidated(nom);
      });
      return;
    }

    setState(() {
      _scanState = _ScanState.success;
      _nfcData   = {
        'mode':      mode,
        'id':        id,
        'nom':       nom,
        'type':      type,
        'expire':    expire,
        'ligne':     ligne,
        'organisme': organisme,
        'isExpired': _checkExpired(expire),
      };
    });
  }

  // ── Expiry check ──────────────────────────────────────────

  bool _checkExpired(String isoDate) {
    try {
      final expireDate = DateTime.parse(isoDate);
      final now        = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final expireDay  = DateTime(
          expireDate.year, expireDate.month, expireDate.day);
      return expireDay.isBefore(todayStart);
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // Save — offline-first (works for both QR and NFC)
  // ══════════════════════════════════════════════════════════

 Future<void> _validerNfc() async {
  if (_nfcData == null) return;
  if (_nfcData!['isExpired'] == true) return;

  setState(() => _isSaving = true);

  final now      = DateTime.now().toIso8601String();
  final idVoyage = widget.voyage['id']             as int? ?? 0;
  final agentId  = widget.voyage['matricule_agent'] as int? ?? 0;

  // id_segment is always 0 here — the server resolves the correct
  // segment from point_depart, same as every other ticket save.

  // Step 1: log the scan locally
  await TicketDao.insertScanLog(
    idVoyage:       idVoyage,
    idSegment:      0,             // server resolves from point_depart
    scanMode:       _nfcData!['mode']      as String,
    numeroTitre:    _nfcData!['id']        as String,
    nomTitulaire:   _nfcData!['nom']       as String,
    typeAbonnement: _nfcData!['type']      as String,
    organisme:      _nfcData!['organisme'] as String,
    ligneTitre:     _nfcData!['ligne']     as String,
    expire:         _nfcData!['expire']    as String,
    dateScan:       now,
    matriculeAgent: agentId,
  );

  // Step 2: save ticket row (offline-first via TicketRepository)
  final isOnline = await ConnectivityService.isOnline();

  final result = await TicketRepository.saveTicket({
    'id_voyage':       idVoyage,
    'id_segment':      0,          // server resolves from point_depart
    'point_depart':    widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '',
    'point_arrivee':   widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '',
    'type_tarif':      '${_l.scanPrefix} ${_nfcData!['mode']} — ${_nfcData!['type']}',
    'quantite':        1,
    'prix_unitaire':   0,
    'montant_total':   0,
    'matricule_agent': agentId,
    'numero_titre':    _nfcData!['id'],
    'nom_titulaire':   _nfcData!['nom'],
    'organisme':       _nfcData!['organisme'],
    'ligne_titre':     _nfcData!['ligne'],
  });

  if (!mounted) return;
  setState(() => _isSaving = false);

  if (result.success) {
    _showToast(
      isOnline ? _l.scanValidatedToast : _l.scanSavedOfflineToast,
      isWarning: !isOnline,
    );
    setState(() {
      _totalScanned++;
      _scanState = _ScanState.idle;
      _nfcData   = null;
    });
  } else {
    _showToast(_l.scanSaveError(result.error ?? ''), isError: true);
  }
}

  // ══════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final showScanBtns =
        _scanState == _ScanState.idle || _scanState == _ScanState.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_totalScanned > 0)
            _SessionBanner(
              icon: Icons.qr_code_scanner_rounded,
              text: l.scanSessionCount(_totalScanned),
            ),

          if (showScanBtns) ...[
            _SectionLabel(l.scanReadMode, Icons.tap_and_play_rounded),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ScanModeBtn(
                    icon: Icons.nfc_rounded,
                    label: l.scanModeNfc,
                    sublabel: l.scanNfcSublabel,
                    color: const Color(0xFF1E40AF),
                    onTap: _scanState == _ScanState.idle
                        ? _startNfcScan
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScanModeBtn(
                    icon: Icons.qr_code_2_rounded,
                    label: l.scanModeQr,
                    sublabel: l.scanQrSublabel,
                    color: const Color(0xFF6B21A8),
                    onTap: _scanState == _ScanState.idle
                        ? _openBarcodeScanner
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: switch (_scanState) {
              _ScanState.idle    => _IdleWidget(
                  key: const ValueKey('idle'), l: l),
              _ScanState.loading => _LoadingWidget(
                  key: const ValueKey('loading'), l: l),
              _ScanState.success => _NfcResultWidget(
                  key: const ValueKey('success'),
                  data:       _nfcData!,
                  isSaving:   _isSaving,
                  onCancel:   _reset,
                  onValidate: _validerNfc,
                  l: l,
                ),
              _ScanState.error   => _ScanErrorWidget(
                  key: const ValueKey('error'),
                  msg:     _errorMsg ?? l.scanInvalidTitle,
                  onRetry: _reset,
                  l: l,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _NfcResultWidget — rich subscriber card (QR + NFC)
// ═════════════════════════════════════════════════════════════

class _NfcResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSaving;
  final VoidCallback onCancel, onValidate;
  final AppLocalizations l;

  const _NfcResultWidget({
    super.key,
    required this.data,
    required this.isSaving,
    required this.onCancel,
    required this.onValidate,
    required this.l,
  });

  String _initials(String nom) {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  String _formatDate(String iso, AppLocalizations l) {
    try {
      final d = DateTime.parse(iso);
      final months = l.localeName == 'ar'
          ? ['يناير','فبراير','مارس','أبريل','ماي','يونيو',
             'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
          : ['jan.','fév.','mar.','avr.','mai','juin',
             'juil.','août','sep.','oct.','nov.','déc.'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  ({Color bg, Color fg}) _typeStyle(String type) {
    switch (type.toLowerCase()) {
      case 'mensuel':
        return (bg: const Color(0xFFEEF2FF), fg: const Color(0xFF3730A3));
      case 'annuel':
        return (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF166534));
      case 'étudiant':
      case 'etudiant':
        return (bg: const Color(0xFFFFF7ED), fg: const Color(0xFF9A3412));
      case 'retraité':
      case 'retraite':
        return (bg: const Color(0xFFF5F3FF), fg: const Color(0xFF5B21B6));
      case 'trimestriel':
        return (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1E40AF));
      default:
        return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151));
    }
  }

  IconData _modeIcon(String mode) {
    if (mode.toLowerCase().contains('nfc')) return Icons.nfc_rounded;
    return Icons.qr_code_2_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = data['isExpired'] as bool? ?? false;
    final nom       = data['nom']       as String;
    final id        = data['id']        as String;
    final type      = data['type']      as String;
    final organisme = data['organisme'] as String;
    final ligne     = data['ligne']     as String;
    final expire    = data['expire']    as String;
    final mode      = data['mode']      as String;
    final ts        = _typeStyle(type);

    final accent       = isExpired ? Colors.red.shade600      : const Color(0xFF16A34A);
    final accentLight  = isExpired ? Colors.red.shade50       : const Color(0xFFDCFCE7);
    final accentBorder = isExpired ? Colors.red.shade200      : const Color(0xFF86EFAC);
    final accentText   = isExpired ? Colors.red.shade800      : const Color(0xFF15803D);
    final accentSub    = isExpired ? Colors.red.shade400      : const Color(0xFF4ADE80);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(nom),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: accentText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: accentText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        id,
                        style: TextStyle(
                          fontSize: 11,
                          color: accentSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_modeIcon(mode), color: Colors.white, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        mode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Fields ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                _ScanField(
                  label: l.scanFieldSubscriptionType,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ts.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(type,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ts.fg)),
                  ),
                ),
                _ScanField(
                  label: l.scanFieldOrganisme,
                  child: Text(organisme,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _navyDark)),
                ),
                _ScanField(
                  label: l.scanFieldAuthorisedLine,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _navyMid,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(ligne,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                _ScanField(
                  label: l.scanFieldExpiry,
                  child: Text(
                    _formatDate(expire, l),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isExpired ? Colors.red.shade700 : _navyDark,
                    ),
                  ),
                ),
                _ScanField(
                  label: l.scanFieldStatus,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isExpired
                              ? Colors.red.shade500
                              : const Color(0xFF22C55E),
                        ),
                      ),
                      Text(
                        isExpired ? l.scanStatusExpired : l.scanStatusValid,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isExpired
                              ? Colors.red.shade700
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Expired warning banner ────────────────────────
          if (isExpired)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade400, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.scanExpiredWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Action buttons ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.annuler,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (isExpired || isSaving) ? null : onValidate,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            isExpired
                                ? Icons.block_rounded
                                : Icons.check_rounded,
                            size: 18),
                    label: Text(
                      isSaving
                          ? l.scanSaving
                          : isExpired
                              ? l.scanBtnExpired
                              : l.scanBtnValidate,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired
                          ? Colors.red.shade400
                          : const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isExpired
                          ? Colors.red.shade200
                          : Colors.grey.shade300,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
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
    );
  }
}

// ── _ScanField row ────────────────────────────────────────────

class _ScanField extends StatelessWidget {
  final String label;
  final Widget child;
  const _ScanField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
                const SizedBox(width: 12),
                child,
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
        ],
      );
}

// ═════════════════════════════════════════════════════════════
// NFC bottom sheet
// ═════════════════════════════════════════════════════════════

class _NfcListeningSheet extends StatefulWidget {
  final AppLocalizations l;
  const _NfcListeningSheet({required this.l});
  @override
  State<_NfcListeningSheet> createState() => _NfcListeningSheetState();
}

class _NfcListeningSheetState extends State<_NfcListeningSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _navyDark.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E40AF)
                      .withOpacity(0.08 + 0.08 * _pulse.value),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF)
                          .withOpacity(0.15 + 0.15 * _pulse.value),
                      blurRadius: 24 + 12 * _pulse.value,
                      spreadRadius: 4 * _pulse.value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.nfc_rounded,
                  size: 48, color: Color(0xFF1E40AF)),
            ),
            const SizedBox(height: 20),
            Text(widget.l.scanNfcSheetTitle,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _navyDark)),
            const SizedBox(height: 8),
            Text(widget.l.scanNfcSheetSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.5)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: Text(widget.l.annuler),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Camera scanner full-screen page
// ═════════════════════════════════════════════════════════════

class _CameraScannerPage extends StatefulWidget {
  final AppLocalizations l;
  const _CameraScannerPage({required this.l});
  @override
  State<_CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<_CameraScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _detected = false;
  bool _torchOn  = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _detected = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(controller: _ctrl, onDetect: _onDetect),
            const _ScanOverlay(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.l.scanCameraTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await _ctrl.toggleTorch();
                        setState(() => _torchOn = !_torchOn);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _torchOn ? _goldLight : Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _torchOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _torchOn ? _navyDark : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 60,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(widget.l.scanCameraHint,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Scan overlay ──────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final sz    = c.biggest;
          final boxSz = sz.width * 0.72;
          final left  = (sz.width  - boxSz) / 2;
          final top   = (sz.height - boxSz) / 2 - 40;
          return CustomPaint(
            size: sz,
            painter: _OverlayPainter(
                cutRect: Rect.fromLTWH(left, top, boxSz, boxSz)),
          );
        },
      );
}

class _OverlayPainter extends CustomPainter {
  final Rect cutRect;
  const _OverlayPainter({required this.cutRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(
            RRect.fromRectAndRadius(cutRect, const Radius.circular(14)))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.62),
    );
    final b = Paint()
      ..color       = Colors.white
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const arm = 24.0;
    final r = cutRect;
    for (final pts in [
      [Offset(r.left, r.top + arm),     Offset(r.left, r.top)],
      [Offset(r.left, r.top),           Offset(r.left + arm, r.top)],
      [Offset(r.right - arm, r.top),    Offset(r.right, r.top)],
      [Offset(r.right, r.top),          Offset(r.right, r.top + arm)],
      [Offset(r.left, r.bottom - arm),  Offset(r.left, r.bottom)],
      [Offset(r.left, r.bottom),        Offset(r.left + arm, r.bottom)],
      [Offset(r.right - arm, r.bottom), Offset(r.right, r.bottom)],
      [Offset(r.right, r.bottom - arm), Offset(r.right, r.bottom)],
    ]) {
      canvas.drawLine(pts[0], pts[1], b);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═════════════════════════════════════════════════════════════
// Shared small widgets
// ═════════════════════════════════════════════════════════════

class _SessionBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SessionBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF16A34A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: _navyMid.withOpacity(0.6)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navyDark,
                    letterSpacing: 0.4)),
          ),
        ],
      );
}

class _ScanModeBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final VoidCallback? onTap;
  const _ScanModeBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled ? Colors.white : Colors.grey.shade400,
                  size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: enabled
                                ? Colors.white
                                : Colors.grey.shade400)),
                    Text(sublabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: enabled
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleWidget extends StatelessWidget {
  final AppLocalizations l;
  const _IdleWidget({super.key, required this.l});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _navyMid.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.qr_code_scanner_rounded,
                size: 56, color: Colors.grey.shade200),
            const SizedBox(height: 14),
            Text(l.scanIdleTitle,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400)),
            const SizedBox(height: 6),
            Text(l.scanIdleSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade300,
                    height: 1.5)),
          ],
        ),
      );
}

class _LoadingWidget extends StatelessWidget {
  final AppLocalizations l;
  const _LoadingWidget({super.key, required this.l});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_navyMid),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.scanSearching,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
          ],
        ),
      );
}

class _ScanErrorWidget extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  final AppLocalizations l;
  const _ScanErrorWidget(
      {super.key, required this.msg, required this.onRetry, required this.l});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200, width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.cancel_rounded,
                  color: Colors.red.shade400, size: 30),
            ),
            const SizedBox(height: 14),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700)),
            const SizedBox(height: 6),
            Text(l.scanErrorSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l.reessayer),
              style: TextButton.styleFrom(foregroundColor: _navyMid),
            ),
          ],
        ),
      );
}

// ── Toast ─────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color color;
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
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
  Widget build(BuildContext context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        right: 16,
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
                      child: Text(widget.msg,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}