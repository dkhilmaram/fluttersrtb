// controleur_page.dart
//
// The main interface for the Contrôleur role.
//
// Access: only users whose employe data contains role == 'controleur'
//         (checked in LoginPage before Navigator.push).
//
// Features:
//   • NFC scan  → hardware UID → checks tickets table (abonnement)
//                              OR ticket_vendu_local (printed ticket)
//   • QR scan   → JSON payload → auto-detects ticket type:
//                   - has 'id' field that is a printed ticket ID → printed ticket
//                   - has 'id' field (card_id)                   → abonnement
//   • Result card: green = valid, orange = expired, red = not found
//   • Saves a control_log row locally (synced later by SyncService)
//   • Session stats banner (valid / expired / not found counts)
//
// Ticket type detection (QR):
//   QR from PrinterService contains: { id, vente, seg, dep, arr, tarif, pu, agent, date, idx, total }
//   QR from abonnement NFC card contains: { id, nom, type, expire, ligne, organisme }
//   Detection: _isPrintedTicketId(id) → printed ticket, else → abonnement.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/database/daos/controleur_dao.dart';

// ── palette ───────────────────────────────────────────────────
const _navyDark  = AppTheme.navyDark;
const _navyMid   = AppTheme.navyMid;
const _navyLight = AppTheme.navyLight;
const _goldLight = AppTheme.goldLight;

// ── scan states ───────────────────────────────────────────────
enum _ScanState { idle, loading, valid, expired, notFound }

// ── detected ticket type ──────────────────────────────────────
enum _TicketType { printed, abonnement, unknown }

// ── Printed ticket ID detection ───────────────────────────────
// Matches any known printed ticket prefix: SRTB-, AB-, TK-, etc.
// Add new prefixes here as needed.
bool _isPrintedTicketId(String id) {
  const prefixes = ['SRTB-', 'AB-', 'TK-', 'BT-'];
  return prefixes.any((p) => id.toUpperCase().startsWith(p));
}

// ═════════════════════════════════════════════════════════════
// ControleurPage
// ═════════════════════════════════════════════════════════════

class ControleurPage extends StatefulWidget {
  final Map<String, dynamic> agent;

  const ControleurPage({super.key, required this.agent});

  @override
  State<ControleurPage> createState() => _ControleurPageState();
}

class _ControleurPageState extends State<ControleurPage>
    with SingleTickerProviderStateMixin {
  _ScanState _scanState = _ScanState.idle;
  Map<String, dynamic>? _resultData;
  _TicketType _detectedType = _TicketType.unknown;

  // Session counters
  int _totalValid    = 0;
  int _totalExpired  = 0;
  int _totalNotFound = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  late AnimationController _pulseCtrl;

  AppLocalizations get _l => AppLocalizations.of(context)!;

  int get _matricule => widget.agent['matricule'] as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
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
    _toastTimer = Timer(const Duration(milliseconds: 3000), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  void _reset() => setState(() {
        _scanState    = _ScanState.idle;
        _resultData   = null;
        _detectedType = _TicketType.unknown;
      });

  // ══════════════════════════════════════════════════════════
  // NFC
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
      builder: (_) => _NfcSheet(l: _l, pulseCtrl: _pulseCtrl),
    ).then((_) => NfcManager.instance.stopSession().catchError((_) {}));

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _extractUid(tag);
          await NfcManager.instance.stopSession();
          HapticFeedback.mediumImpact();
          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          if (uid == null || uid.trim().length < 2) {
            setState(() => _scanState = _ScanState.notFound);
            _saveLog(
              ticketId:   'UNKNOWN',
              ticketType: 'abonnement',
              resultat:   'not_found',
              infoJson:   '{}',
            );
            return;
          }
          await _resolveNfc(uid.trim().toUpperCase());
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: _l.scanNfcReadError)
              .catchError((_) {});
          if (mounted) setState(() => _scanState = _ScanState.notFound);
        }
      },
      alertMessage: _l.scanNfcApproach,
    );
  }

  String? _extractUid(NfcTag tag) {
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

    return hexFromField(data['nfca']?['identifier']) ??
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
  }

  // ── NFC resolve: try abonnement table first ───────────────
  Future<void> _resolveNfc(String uid) async {
    if (!mounted) return;
    setState(() => _scanState = _ScanState.loading);

    final card = await ControleurDao.findAbonnement(uid);
    if (!mounted) return;

    if (card == null) {
      setState(() {
        _scanState    = _ScanState.notFound;
        _detectedType = _TicketType.abonnement;
        _resultData   = {'id': uid};
        _totalNotFound++;
      });
      _saveLog(
        ticketId:   uid,
        ticketType: 'abonnement',
        resultat:   'not_found',
        infoJson:   jsonEncode({'id': uid}),
      );
      return;
    }

    final isExpired = _checkExpired(card['expire'] as String? ?? '');
    final result    = isExpired ? _ScanState.expired : _ScanState.valid;

    final info = {
      'mode':      'NFC',
      'id':        uid,
      'nom':       card['nom']       ?? '—',
      'type':      card['type']      ?? '—',
      'expire':    card['expire']    ?? '',
      'ligne':     card['ligne']     ?? '—',
      'organisme': card['organisme'] ?? '—',
    };

    setState(() {
      _scanState    = result;
      _detectedType = _TicketType.abonnement;
      _resultData   = info;
      if (result == _ScanState.valid)   _totalValid++;
      if (result == _ScanState.expired) _totalExpired++;
    });

    _saveLog(
      ticketId:   uid,
      ticketType: 'abonnement',
      resultat:   isExpired ? 'expired' : 'valid',
      infoJson:   jsonEncode(info),
    );
  }

  // ══════════════════════════════════════════════════════════
  // QR
  // ══════════════════════════════════════════════════════════

  Future<void> _openQrScanner() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _QrScannerPage(l: _l),
        fullscreenDialog: true,
      ),
    );
    if (raw == null || !mounted) return;
    await _resolveQr(raw.trim());
  }

  Future<void> _resolveQr(String raw) async {
    if (!mounted) return;
    setState(() => _scanState = _ScanState.loading);

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      // Not JSON — treat as a raw ticket ID
      if (_isPrintedTicketId(raw)) {
        await _resolvePrintedTicket(raw);
      } else {
        setState(() {
          _scanState    = _ScanState.notFound;
          _detectedType = _TicketType.unknown;
          _totalNotFound++;
        });
        _saveLog(
          ticketId:   raw,
          ticketType: 'unknown',
          resultat:   'not_found',
          infoJson:   '{}',
        );
      }
      return;
    }

    final id = payload['id']?.toString() ?? '';

    if (_isPrintedTicketId(id)) {
      // ── Printed ticket QR ──────────────────────────────────
      await _resolvePrintedTicketFromQr(id, payload);
    } else if (id.isNotEmpty) {
      // ── Abonnement QR ──────────────────────────────────────
      final card = await ControleurDao.findAbonnement(id.toUpperCase());
      if (!mounted) return;

      if (card == null) {
        setState(() {
          _scanState    = _ScanState.notFound;
          _detectedType = _TicketType.abonnement;
          _resultData   = {'id': id};
          _totalNotFound++;
        });
        _saveLog(
          ticketId:   id,
          ticketType: 'abonnement',
          resultat:   'not_found',
          infoJson:   jsonEncode({'id': id}),
        );
        return;
      }

      final isExpired = _checkExpired(card['expire'] as String? ?? '');
      final info = {
        'mode':      'QR',
        'id':        id,
        'nom':       card['nom']       ?? payload['nom'] ?? '—',
        'type':      card['type']      ?? payload['type'] ?? '—',
        'expire':    card['expire']    ?? payload['expire'] ?? '',
        'ligne':     card['ligne']     ?? payload['ligne'] ?? '—',
        'organisme': card['organisme'] ?? payload['organisme'] ?? '—',
      };

      setState(() {
        _scanState    = isExpired ? _ScanState.expired : _ScanState.valid;
        _detectedType = _TicketType.abonnement;
        _resultData   = info;
        if (!isExpired) _totalValid++;
        else _totalExpired++;
      });

      _saveLog(
        ticketId:   id,
        ticketType: 'abonnement',
        resultat:   isExpired ? 'expired' : 'valid',
        infoJson:   jsonEncode(info),
      );
    } else {
      setState(() {
        _scanState    = _ScanState.notFound;
        _detectedType = _TicketType.unknown;
        _totalNotFound++;
      });
      _saveLog(
        ticketId:   'UNKNOWN',
        ticketType: 'unknown',
        resultat:   'not_found',
        infoJson:   jsonEncode(payload),
      );
    }
  }

  // ── Printed ticket: resolve from bare ID ─────────────────
  Future<void> _resolvePrintedTicket(String ticketId) async {
    final row = await ControleurDao.findPrintedTicket(ticketId);
    if (!mounted) return;

    if (row == null) {
      setState(() {
        _scanState    = _ScanState.notFound;
        _detectedType = _TicketType.printed;
        _resultData   = {'id': ticketId};
        _totalNotFound++;
      });
      _saveLog(
        ticketId:   ticketId,
        ticketType: 'printed',
        resultat:   'not_found',
        infoJson:   jsonEncode({'id': ticketId}),
      );
      return;
    }

    final info = _buildPrintedInfo(ticketId, row);
    setState(() {
      _scanState    = _ScanState.valid;
      _detectedType = _TicketType.printed;
      _resultData   = info;
      _totalValid++;
    });
    _saveLog(
      ticketId:   ticketId,
      ticketType: 'printed',
      resultat:   'valid',
      infoJson:   jsonEncode(info),
    );
  }

  // ── Printed ticket: resolve from QR payload + DB verify ──
  Future<void> _resolvePrintedTicketFromQr(
      String ticketId, Map<String, dynamic> payload) async {
    final row = await ControleurDao.findPrintedTicket(ticketId);
    if (!mounted) return;

    if (row == null) {
      setState(() {
        _scanState    = _ScanState.notFound;
        _detectedType = _TicketType.printed;
        _resultData   = {'id': ticketId, 'qr_payload': payload};
        _totalNotFound++;
      });
      _saveLog(
        ticketId:   ticketId,
        ticketType: 'printed',
        resultat:   'not_found',
        infoJson:   jsonEncode({'id': ticketId, ...payload}),
      );
      return;
    }

    final info = _buildPrintedInfo(ticketId, row, qrPayload: payload);
    setState(() {
      _scanState    = _ScanState.valid;
      _detectedType = _TicketType.printed;
      _resultData   = info;
      _totalValid++;
    });
    _saveLog(
      ticketId:   ticketId,
      ticketType: 'printed',
      resultat:   'valid',
      infoJson:   jsonEncode(info),
    );
  }

  // ── Build printed ticket result map ──────────────────────
  Map<String, dynamic> _buildPrintedInfo(
    String ticketId,
    Map<String, dynamic> row, {
    Map<String, dynamic>? qrPayload,
  }) {
    return {
      'mode':          'QR',
      'ticket_type':   'printed',
      'id':            ticketId,
      'depart':        row['point_depart']    ?? qrPayload?['dep']   ?? '—',
      'arrivee':       row['point_arrivee']   ?? qrPayload?['arr']   ?? '—',
      'tarif':         row['type_tarif']      ?? qrPayload?['tarif'] ?? '—',
      'prix':          row['prix_unitaire']   ?? qrPayload?['pu']    ?? 0,
      'quantite':      row['quantite']        ?? 1,
      'agent':         row['matricule_agent'] ?? qrPayload?['agent'] ?? '—',
      'date_vente':    row['date_heure']      ?? qrPayload?['date']  ?? '—',
      'voyage_id':     row['id_voyage']       ?? qrPayload?['vente'] ?? '—',
      'segment_id':    row['id_segment']      ?? qrPayload?['seg']   ?? '—',
      'nom_titulaire': row['nom_titulaire']   ?? '—',
    };
  }

  // ── Expiry check ──────────────────────────────────────────
  bool _checkExpired(String isoDate) {
    try {
      final expireDate = DateTime.parse(isoDate);
      final now        = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final expireDay  = DateTime(expireDate.year, expireDate.month, expireDate.day);
      return expireDay.isBefore(todayStart);
    } catch (_) {
      return false;
    }
  }

  // ── Save control log ──────────────────────────────────────
  Future<void> _saveLog({
    required String ticketId,
    required String ticketType,
    required String resultat,
    required String infoJson,
  }) async {
    await ControleurDao.insertControlLog(
      ticketId:       ticketId,
      ticketType:     ticketType,
      resultat:       resultat,
      matriculeAgent: _matricule,
      infoJson:       infoJson,
    );
  }

  // ══════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final nom   = widget.agent['prenom'] as String? ?? '';
    final total = _totalValid + _totalExpired + _totalNotFound;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _ControleurHeader(
            nom:      nom,
            total:    total,
            valid:    _totalValid,
            expired:  _totalExpired,
            notFound: _totalNotFound,
            onLogout: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                children: [
                  if (_scanState != _ScanState.loading) ...[
                    _ScanModeRow(
                      onNfc: _startNfcScan,
                      onQr:  _openQrScanner,
                    ),
                    const SizedBox(height: 20),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve:  Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: switch (_scanState) {
                      _ScanState.idle     => _IdleCard(key: const ValueKey('idle')),
                      _ScanState.loading  => _LoadingCard(key: const ValueKey('loading')),
                      _ScanState.valid    => _ResultCard(
                          key:        const ValueKey('valid'),
                          state:      _ScanState.valid,
                          data:       _resultData ?? {},
                          ticketType: _detectedType,
                          onReset:    _reset,
                        ),
                      _ScanState.expired  => _ResultCard(
                          key:        const ValueKey('expired'),
                          state:      _ScanState.expired,
                          data:       _resultData ?? {},
                          ticketType: _detectedType,
                          onReset:    _reset,
                        ),
                      _ScanState.notFound => _NotFoundCard(
                          key:     const ValueKey('notFound'),
                          data:    _resultData ?? {},
                          onReset: _reset,
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Header
// ═════════════════════════════════════════════════════════════

class _ControleurHeader extends StatelessWidget {
  final String nom;
  final int total, valid, expired, notFound;
  final VoidCallback onLogout;

  const _ControleurHeader({
    required this.nom,
    required this.total,
    required this.valid,
    required this.expired,
    required this.notFound,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navyDark, Color(0xFF1A3A6B), _navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldLight.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: _goldLight, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      'CONTRÔLEUR',
                      style: TextStyle(
                        color: _goldLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                tooltip: 'Déconnexion',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bonjour, $nom',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (total > 0)
            Row(
              children: [
                _StatChip(count: valid,    label: 'Valides',   color: const Color(0xFF22C55E),   icon: Icons.check_circle_rounded),
                const SizedBox(width: 8),
                _StatChip(count: expired,  label: 'Expirés',   color: Colors.orange.shade400,    icon: Icons.schedule_rounded),
                const SizedBox(width: 8),
                _StatChip(count: notFound, label: 'Invalides', color: Colors.red.shade400,       icon: Icons.cancel_rounded),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;
  const _StatChip({required this.count, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text('$count', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Scan mode buttons row
// ═════════════════════════════════════════════════════════════

class _ScanModeRow extends StatelessWidget {
  final VoidCallback onNfc, onQr;
  const _ScanModeRow({required this.onNfc, required this.onQr});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ScanBtn(
              icon:     Icons.nfc_rounded,
              label:    'Scanner NFC',
              sublabel: 'Carte abonnement',
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: onNfc,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ScanBtn(
              icon:     Icons.qr_code_2_rounded,
              label:    'Scanner QR',
              sublabel: 'Ticket ou abonnement',
              gradient: const LinearGradient(
                colors: [Color(0xFF4C1D95), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: onQr,
            ),
          ),
        ],
      );
}

class _ScanBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ScanBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 10),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(sublabel, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Idle card
// ═════════════════════════════════════════════════════════════

class _IdleCard extends StatelessWidget {
  const _IdleCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(color: _navyMid.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: Color(0xFFF0F4FF), shape: BoxShape.circle),
              child: const Icon(Icons.document_scanner_rounded, size: 36, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 16),
            const Text('Prêt à contrôler',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navyDark)),
            const SizedBox(height: 8),
            Text(
              'Scannez un ticket imprimé ou\nune carte d\'abonnement NFC / QR',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.6),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Loading card
// ═════════════════════════════════════════════════════════════

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 44, height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_navyMid),
              ),
            ),
            SizedBox(height: 18),
            Text('Vérification en cours…',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navyDark)),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Result card — valid / expired
// ═════════════════════════════════════════════════════════════

class _ResultCard extends StatelessWidget {
  final _ScanState state;
  final Map<String, dynamic> data;
  final _TicketType ticketType;
  final VoidCallback onReset;

  const _ResultCard({
    super.key,
    required this.state,
    required this.data,
    required this.ticketType,
    required this.onReset,
  });

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final months = ['jan.','fév.','mar.','avr.','mai','juin',
                      'juil.','août','sep.','oct.','nov.','déc.'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  String _formatDateTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/'
             '${d.month.toString().padLeft(2,'0')}/'
             '${d.year}  '
             '${d.hour.toString().padLeft(2,'0')}:'
             '${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final isValid   = state == _ScanState.valid;
    final isPrinted = ticketType == _TicketType.printed;

    final accent       = isValid ? const Color(0xFF16A34A) : Colors.orange.shade600;
    final accentLight  = isValid ? const Color(0xFFDCFCE7) : Colors.orange.shade50;
    final accentBorder = isValid ? const Color(0xFF86EFAC) : Colors.orange.shade200;
    final accentText   = isValid ? const Color(0xFF15803D) : Colors.orange.shade800;
    final statusLabel  = isValid ? 'VALIDE' : 'EXPIRÉ';
    final statusIcon   = isValid ? Icons.check_circle_rounded : Icons.schedule_rounded;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentBorder, width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // ── Status banner ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Icon(statusIcon, color: accent, size: 36),
                const SizedBox(height: 6),
                Text(statusLabel,
                    style: TextStyle(color: accentText, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPrinted ? '🎫 Ticket imprimé' : '💳 Abonnement',
                    style: TextStyle(color: accentText, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── Fields ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              children: isPrinted
                  ? _buildPrintedFields(context)
                  : _buildAbonnementFields(context),
            ),
          ),

          // ── Expired warning ──────────────────────────────
          if (!isValid)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ce titre de transport est expiré. Le passager ne peut pas voyager.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ── New scan button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Nouveau contrôle', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navyDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAbonnementFields(BuildContext context) {
    final nom       = data['nom']       as String? ?? '—';
    final id        = data['id']        as String? ?? '—';
    final type      = data['type']      as String? ?? '—';
    final organisme = data['organisme'] as String? ?? '—';
    final ligne     = data['ligne']     as String? ?? '—';
    final expire    = data['expire']    as String? ?? '';
    final mode      = data['mode']      as String? ?? '—';

    return [
      _Field(label: 'Titulaire',  value: nom),
      _Field(label: 'ID carte',   value: id, mono: true),
      _Field(label: 'Mode',       value: mode),
      _Field(label: 'Type',       value: type),
      _Field(label: 'Organisme',  value: organisme),
      _Field(label: 'Ligne',      value: ligne),
      _Field(label: 'Expiration', value: _formatDate(expire)),
    ];
  }

  List<Widget> _buildPrintedFields(BuildContext context) {
    final id        = data['id']            as String? ?? '—';
    final depart    = data['depart']        as String? ?? '—';
    final arrivee   = data['arrivee']       as String? ?? '—';
    final tarif     = data['tarif']         as String? ?? '—';
    final prix      = data['prix'];
    final quantite  = data['quantite'];
    final agent     = data['agent'];
    final dateVente = data['date_vente']    as String? ?? '';
    final nomTit    = data['nom_titulaire'] as String? ?? '—';

    final prixStr = (prix == null || prix == '0' || prix == 0) ? 'Gratuit' : '$prix millimes';

    return [
      _Field(label: 'N° ticket',     value: id, mono: true),
      _Field(label: 'Départ',        value: depart),
      _Field(label: 'Arrivée',       value: arrivee),
      _Field(label: 'Tarif',         value: tarif),
      _Field(label: 'Prix unitaire', value: prixStr),
      if (quantite != null)
        _Field(label: 'Quantité',    value: quantite.toString()),
      if (nomTit != '—')
        _Field(label: 'Titulaire',   value: nomTit),
      _Field(label: 'Agent',         value: agent?.toString() ?? '—'),
      _Field(label: 'Date vente',    value: _formatDateTime(dateVente)),
    ];
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _Field({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mono ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: _navyDark,
                      fontFamily: mono ? 'monospace' : null,
                      letterSpacing: mono ? 0.5 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
        ],
      );
}

// ═════════════════════════════════════════════════════════════
// Not found card
// ═════════════════════════════════════════════════════════════

class _NotFoundCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReset;
  const _NotFoundCard({super.key, required this.data, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.gpp_bad_rounded, color: Colors.red.shade400, size: 36),
          ),
          const SizedBox(height: 16),
          Text('TICKET INVALIDE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            'Ce titre de transport est introuvable\ndans la base de données.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade400, height: 1.6),
          ),
          if (id.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(id,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade800,
                      fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navyDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// NFC bottom sheet
// ═════════════════════════════════════════════════════════════

class _NfcSheet extends StatelessWidget {
  final AppLocalizations l;
  final AnimationController pulseCtrl;
  const _NfcSheet({required this.l, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _navyDark.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, child) => Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E40AF).withOpacity(0.08 + 0.08 * pulseCtrl.value),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withOpacity(0.15 + 0.15 * pulseCtrl.value),
                      blurRadius: 24 + 12 * pulseCtrl.value,
                      spreadRadius: 4 * pulseCtrl.value,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const Icon(Icons.nfc_rounded, size: 48, color: Color(0xFF1E40AF)),
            ),
            const SizedBox(height: 20),
            const Text('Approchez la carte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navyDark)),
            const SizedBox(height: 8),
            Text(
              'Placez la carte d\'abonnement\nprès du capteur NFC de l\'appareil',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Annuler'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// QR scanner page (full-screen camera)
// ═════════════════════════════════════════════════════════════

class _QrScannerPage extends StatefulWidget {
  final AppLocalizations l;
  const _QrScannerPage({required this.l});
  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
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
            _buildOverlay(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Contrôle — Scanner QR',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
                          _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text('Ticket imprimé ou carte abonnement',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildOverlay() => LayoutBuilder(
        builder: (_, c) {
          final sz    = c.biggest;
          final boxSz = sz.width * 0.72;
          final left  = (sz.width  - boxSz) / 2;
          final top   = (sz.height - boxSz) / 2 - 40;
          return CustomPaint(
            size: sz,
            painter: _OverlayPainter(cutRect: Rect.fromLTWH(left, top, boxSz, boxSz)),
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
        ..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(14)))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.62),
    );
    final b = Paint()
      ..color       = _goldLight
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const arm = 28.0;
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
// Toast
// ═════════════════════════════════════════════════════════════

class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color color;
  final IconData icon;
  const _ToastWidget({required this.msg, required this.color, required this.icon});

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2600), () { if (mounted) _ctrl.reverse(); });
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(widget.msg,
                          style: const TextStyle(color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w600, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}