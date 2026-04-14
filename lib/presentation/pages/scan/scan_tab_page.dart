// scan_tab_page.dart
//
// Extracted NFC / QR barcode scanner — now its own top-level tab
// inside TicketingPage (tab index 2).
//
// pubspec.yaml dependencies required:
//   mobile_scanner: ^5.2.3
//   nfc_manager: ^3.3.0
//
// Android AndroidManifest.xml:
//   <uses-permission android:name="android.permission.CAMERA"/>
//   <uses-permission android:name="android.permission.NFC"/>
//   <uses-feature android:name="android.hardware.nfc" android:required="false"/>
// iOS Info.plist:
//   NSCameraUsageDescription — "Scan transport tickets"
//   NFCReaderUsageDescription — "Read transport NFC cards"
// iOS Runner.entitlements:
//   com.apple.developer.nfc.readersession.formats → TAG

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../../../data/repositories/ticket_repository.dart';

// ── Palette ───────────────────────────────────────────────────
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

enum _ScanState { idle, success, error }

// ════════════════════════════════════════════════════════════════
// ScanTabPage
// ════════════════════════════════════════════════════════════════

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
  _ScanState            scanState    = _ScanState.idle;
  Map<String, dynamic>? scannedData;
  String?               errorMsg;
  bool                  isSaving     = false;
  int                   totalScanned = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

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
        builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon));
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ── Barcode scanner ────────────────────────────────────────
  Future<void> _openBarcodeScanner() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraScannerPage(),
        fullscreenDialog: true,
      ),
    );
    if (raw == null) return;
    _resolveCode(raw, 'QR');
  }

  // ── NFC scanner ────────────────────────────────────────────
  Future<void> _startNfcScan() async {
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      if (mounted) {
        _showToast('NFC non disponible sur cet appareil', isWarning: true);
      }
      return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NfcListeningSheet(),
    ).then((_) {
      NfcManager.instance.stopSession().catchError((_) {});
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final raw = _extractRawFromTag(tag);
          await NfcManager.instance.stopSession();
          HapticFeedback.mediumImpact();

          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          if (raw == null || raw.length < 4) {
            if (mounted) {
              setState(() {
                scanState = _ScanState.error;
                errorMsg  = 'Carte NFC illisible ou invalide';
              });
            }
          } else {
            _resolveCode(raw, 'NFC');
          }
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: 'Erreur de lecture')
              .catchError((_) {});
          if (mounted) {
            setState(() {
              scanState = _ScanState.error;
              errorMsg  = 'Erreur NFC : $e';
            });
          }
        }
      },
      alertMessage: 'Approchez votre carte de transport',
    );
  }

  String? _extractRawFromTag(NfcTag tag) {
    final ndef = Ndef.from(tag);
    if (ndef != null && ndef.cachedMessage != null) {
      for (final record in ndef.cachedMessage!.records) {
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
            record.type.isNotEmpty && record.type[0] == 0x54) {
          final payload = record.payload;
          if (payload.length > 1) {
            final langLen = payload[0] & 0x3F;
            if (payload.length > 1 + langLen) {
              return utf8.decode(payload.sublist(1 + langLen));
            }
          }
        }
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
            record.type.isNotEmpty && record.type[0] == 0x55) {
          final payload = record.payload;
          if (payload.length > 1) {
            return utf8.decode(payload.sublist(1));
          }
        }
        try {
          final text = utf8.decode(record.payload, allowMalformed: false).trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
      }
    }

    final data = tag.data;

    String? hexFromField(dynamic field) {
      if (field is List && field.isNotEmpty) {
        final bytes = Uint8List.fromList(List<int>.from(field));
        return bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
      }
      return null;
    }

    return hexFromField(data['nfca']?['identifier'])
        ?? hexFromField(data['nfcb']?['applicationData'])
        ?? hexFromField(data['mifareClassic']?['identifier'])
        ?? hexFromField(data['mifareUltralight']?['identifier'])
        ?? hexFromField(data['iso7816']?['identifier'])
        ?? hexFromField(data['feliCa']?['currentIdm'])
        ?? hexFromField(data['nfcf']?['manufacturer'])
        ?? hexFromField(data['nfcv']?['identifier']);
  }

  void _resolveCode(String raw, String mode) {
    if (!mounted) return;

    Map<String, dynamic>? parsed;
    try {
      parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      setState(() {
        scanState = _ScanState.error;
        errorMsg  = 'QR code illisible ou format non reconnu';
      });
      return;
    }

    final id        = parsed['id']?.toString()       ?? '';
    final nom       = parsed['nom']?.toString()       ?? 'Inconnu';
    final type      = parsed['type']?.toString()      ?? 'Inconnu';
    final expire    = parsed['expire']?.toString()    ?? '';
    final ligne     = parsed['ligne']?.toString()     ?? '—';
    final organisme = parsed['organisme']?.toString() ?? '—';

    if (id.isEmpty || type.isEmpty || expire.isEmpty) {
      setState(() {
        scanState = _ScanState.error;
        errorMsg  = 'Données du titre incomplètes (id, type ou expire manquant)';
      });
      return;
    }

    bool isExpired = false;
    try {
      isExpired = DateTime.parse(expire).isBefore(DateTime.now());
    } catch (_) {}

    setState(() {
      scanState   = _ScanState.success;
      scannedData = {
        'mode':      mode,
        'id':        id,
        'nom':       nom,
        'type':      type,
        'expire':    expire,
        'ligne':     ligne,
        'organisme': organisme,
        'isExpired': isExpired,
      };
    });
  }

  Future<void> _validerEtVendre() async {
    if (scannedData == null) return;
    if (scannedData!['isExpired'] == true) return;
    setState(() => isSaving = true);

    final result = await TicketRepository.saveTicket({
      'id_vente':        widget.voyage['id'] as int? ?? 0,
      'id_segment':      widget.segment['id_segment'] as int? ?? 0,
      'point_depart':    widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '',
      'point_arrivee':   widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '',
      'type_tarif':      'Scan ${scannedData!['mode']} — ${scannedData!['type']}',
      'quantite':        1,
      'prix_unitaire':   0,
      'montant_total':   0,
      'matricule_agent': widget.voyage['matricule_agent'] ?? 0,
      'numero_titre':    scannedData!['id'],
      'nom_titulaire':   scannedData!['nom'],
      'organisme':       scannedData!['organisme'],
      'ligne_titre':     scannedData!['ligne'],
    });

    if (result.success) {
      setState(() {
        totalScanned++;
        scanState   = _ScanState.idle;
        scannedData = null;
      });
      _showToast('Titre validé et enregistré ✓');
    } else {
      _showToast('Erreur : ${result.error}', isError: true);
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalScanned > 0)
            _SessionBanner(
              icon: Icons.qr_code_scanner_rounded,
              text: '$totalScanned titre(s) validé(s) cette session',
            ),

          _SectionLabel('Mode de lecture', Icons.tap_and_play_rounded),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(child: _ScanModeBtn(
              icon: Icons.nfc_rounded,
              label: 'NFC',
              sublabel: 'Approcher la carte',
              color: const Color(0xFF1E40AF),
              onTap: scanState == _ScanState.idle ? _startNfcScan : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _ScanModeBtn(
              icon: Icons.qr_code_2_rounded,
              label: 'Code-barres',
              sublabel: 'Scanner le QR / code',
              color: const Color(0xFF6B21A8),
              onTap: scanState == _ScanState.idle ? _openBarcodeScanner : null,
            )),
          ]),

          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: switch (scanState) {
              _ScanState.idle    => const _IdleWidget(key: ValueKey('idle')),
              _ScanState.success => _ScanResultWidget(
                key: const ValueKey('success'),
                data: scannedData!,
                isSaving: isSaving,
                onCancel: () => setState(() {
                  scanState   = _ScanState.idle;
                  scannedData = null;
                }),
                onValidate: _validerEtVendre,
              ),
              _ScanState.error   => _ScanErrorWidget(
                key: const ValueKey('error'),
                msg: errorMsg ?? 'Titre invalide',
                onRetry: () => setState(() => scanState = _ScanState.idle),
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NFC listening bottom sheet
// ════════════════════════════════════════════════════════════════

class _NfcListeningSheet extends StatefulWidget {
  const _NfcListeningSheet();
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
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: cardWhite,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: navyDark.withOpacity(0.12),
          blurRadius: 24, offset: const Offset(0, -4))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40, height: 4,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)),
      ),
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E40AF).withOpacity(0.08 + 0.08 * _pulse.value),
            boxShadow: [BoxShadow(
              color: const Color(0xFF1E40AF).withOpacity(0.15 + 0.15 * _pulse.value),
              blurRadius: 24 + 12 * _pulse.value,
              spreadRadius: 4 * _pulse.value,
            )],
          ),
          child: child,
        ),
        child: const Icon(Icons.nfc_rounded, size: 48, color: Color(0xFF1E40AF)),
      ),
      const SizedBox(height: 20),
      const Text('Approchez la carte NFC',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: navyDark)),
      const SizedBox(height: 8),
      Text('Maintenez la carte contre\nle dos de votre téléphone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
      const SizedBox(height: 24),
      TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close, size: 16),
        label: const Text('Annuler'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// Camera scanner full-screen page
// ════════════════════════════════════════════════════════════════

class _CameraScannerPage extends StatefulWidget {
  const _CameraScannerPage();
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
    body: Stack(children: [
      MobileScanner(controller: _ctrl, onDetect: _onDetect),
      const _ScanOverlay(),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Scanner le code-barres / QR',
                style: TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () async {
                await _ctrl.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _torchOn ? goldLight : Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _torchOn ? navyDark : Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),
      Positioned(
        left: 0, right: 0, bottom: 60,
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: Colors.black54,
              borderRadius: BorderRadius.circular(30)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 16),
            SizedBox(width: 8),
            Flexible(child: Text('Centrez le code dans le cadre',
                style: TextStyle(color: Colors.white70, fontSize: 12))),
          ]),
        )),
      ),
    ]),
  );
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    final sz    = c.biggest;
    final boxSz = sz.width * 0.72;
    final left  = (sz.width  - boxSz) / 2;
    final top   = (sz.height - boxSz) / 2 - 40;
    return CustomPaint(
      size: sz,
      painter: _OverlayPainter(
          cutRect: Rect.fromLTWH(left, top, boxSz, boxSz)));
  });
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
      ..color = Colors.white ..strokeWidth = 3
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    const arm = 24.0;
    final r = cutRect;
    canvas.drawLine(Offset(r.left, r.top + arm), Offset(r.left, r.top), b);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + arm, r.top), b);
    canvas.drawLine(Offset(r.right - arm, r.top), Offset(r.right, r.top), b);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + arm), b);
    canvas.drawLine(Offset(r.left, r.bottom - arm), Offset(r.left, r.bottom), b);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + arm, r.bottom), b);
    canvas.drawLine(Offset(r.right - arm, r.bottom), Offset(r.right, r.bottom), b);
    canvas.drawLine(Offset(r.right, r.bottom - arm), Offset(r.right, r.bottom), b);
  }

  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ════════════════════════════════════════════════════════════════
// Scan result card
// ════════════════════════════════════════════════════════════════

class _ScanResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool         isSaving;
  final VoidCallback onCancel, onValidate;

  const _ScanResultWidget({
    super.key,
    required this.data,
    required this.isSaving,
    required this.onCancel,
    required this.onValidate,
  });

  String _initials(String nom) {
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
        'jan.','fév.','mar.','avr.','mai','juin',
        'juil.','août','sep.','oct.','nov.','déc.'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  ({Color bg, Color fg}) _typeStyle(String type) {
    switch (type.toLowerCase()) {
      case 'mensuel':    return (bg: const Color(0xFFEEF2FF), fg: const Color(0xFF3730A3));
      case 'annuel':     return (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF166534));
      case 'étudiant':
      case 'etudiant':   return (bg: const Color(0xFFFFF7ED), fg: const Color(0xFF9A3412));
      case 'retraité':
      case 'retraite':   return (bg: const Color(0xFFF5F3FF), fg: const Color(0xFF5B21B6));
      case 'trimestriel':return (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1E40AF));
      default:           return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151));
    }
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

    final accent       = isExpired ? Colors.red.shade600  : const Color(0xFF16A34A);
    final accentLight  = isExpired ? Colors.red.shade50   : const Color(0xFFDCFCE7);
    final accentBorder = isExpired ? Colors.red.shade200  : const Color(0xFF86EFAC);
    final accentText   = isExpired ? Colors.red.shade800  : const Color(0xFF15803D);
    final accentSub    = isExpired ? Colors.red.shade400  : const Color(0xFF4ADE80);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBorder, width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: accentLight,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14))),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: accent.withOpacity(0.15)),
              alignment: Alignment.center,
              child: Text(_initials(nom),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: accentText)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: accentText)),
              const SizedBox(height: 2),
              Text(id, style: TextStyle(fontSize: 11, color: accentSub,
                  fontWeight: FontWeight.w600)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: accent,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(mode,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Fields
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(children: [
            _ScanField(label: "Type d'abonnement", child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: ts.bg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(type, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: ts.fg)),
            )),
            _ScanField(label: 'Organisme', child: Text(organisme,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: navyDark))),
            _ScanField(label: 'Ligne autorisée', child: Container(
              width: 28, height: 20,
              decoration: BoxDecoration(color: navyMid,
                  borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text(ligne, style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.bold)),
            )),
            _ScanField(label: 'Expire le', child: Text(_formatDate(expire),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: isExpired ? Colors.red.shade700 : navyDark))),
            _ScanField(label: 'Statut', child: Row(
                mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: isExpired
                          ? Colors.red.shade500
                          : const Color(0xFF22C55E))),
              Text(isExpired ? 'Expiré' : 'Valide',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: isExpired
                          ? Colors.red.shade700
                          : const Color(0xFF16A34A))),
            ])),
          ]),
        ),

        // Expired warning
        if (isExpired)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Ce titre est expiré et ne peut pas être validé.',
                  style: TextStyle(fontSize: 12,
                      color: Colors.red.shade700, fontWeight: FontWeight.w600))),
            ]),
          ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade500,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: (isExpired || isSaving) ? null : onValidate,
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(isExpired
                      ? Icons.block_rounded : Icons.check_rounded, size: 18),
              label: Text(
                isSaving
                    ? 'Enregistrement...'
                    : isExpired
                        ? 'Titre expiré'
                        : 'Valider & Enregistrer',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired
                    ? Colors.red.shade400 : const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isExpired
                    ? Colors.red.shade200 : Colors.grey.shade300,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _ScanField extends StatelessWidget {
  final String label;
  final Widget child;
  const _ScanField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          const SizedBox(width: 12),
          child,
        ],
      ),
    ),
    Divider(height: 1, color: Colors.grey.shade100),
  ]);
}

// ════════════════════════════════════════════════════════════════
// Shared small widgets
// ════════════════════════════════════════════════════════════════

class _SessionBanner extends StatelessWidget {
  final IconData icon;
  final String   text;
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
    child: Row(children: [
      Icon(icon, color: const Color(0xFF16A34A), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(color: Color(0xFF15803D),
              fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String   text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: navyMid.withOpacity(0.6)),
    const SizedBox(width: 7),
    Flexible(child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: navyDark, letterSpacing: 0.4))),
  ]);
}

class _ScanModeBtn extends StatelessWidget {
  final IconData     icon;
  final String       label, sublabel;
  final Color        color;
  final VoidCallback? onTap;
  const _ScanModeBtn({required this.icon, required this.label,
      required this.sublabel, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent, borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: enabled ? null : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(color: color.withOpacity(0.3),
                    blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon,
                color: enabled ? Colors.white : Colors.grey.shade400, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.white : Colors.grey.shade400)),
              Text(sublabel, style: TextStyle(fontSize: 10,
                  color: enabled
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade400)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _IdleWidget extends StatelessWidget {
  const _IdleWidget({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: cardWhite, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100, width: 1.5),
      boxShadow: [BoxShadow(color: navyMid.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Column(children: [
      Icon(Icons.qr_code_scanner_rounded,
          size: 56, color: Colors.grey.shade200),
      const SizedBox(height: 14),
      Text('Prêt à scanner', style: TextStyle(fontSize: 15,
          fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
      const SizedBox(height: 6),
      Text('Choisissez NFC ou Code-barres\npour lancer la lecture',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12,
              color: Colors.grey.shade300, height: 1.5)),
    ]),
  );
}

class _ScanErrorWidget extends StatelessWidget {
  final String       msg;
  final VoidCallback onRetry;
  const _ScanErrorWidget({super.key, required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: cardWhite, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade200, width: 1.5),
    ),
    child: Column(children: [
      Container(width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.red.shade50,
              shape: BoxShape.circle),
          child: Icon(Icons.cancel_rounded,
              color: Colors.red.shade400, size: 30)),
      const SizedBox(height: 14),
      Text(msg, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: Colors.red.shade700)),
      const SizedBox(height: 6),
      Text('Ce titre de transport ne peut pas être accepté.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Réessayer'),
        style: TextButton.styleFrom(foregroundColor: navyMid),
      ),
    ]),
  );
}

// ── Toast ────────────────────────────────────────────────────
class _ToastWidget extends StatefulWidget {
  final String   msg;
  final Color    color;
  final IconData icon;
  const _ToastWidget({required this.msg, required this.color, required this.icon});
  @override State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100),
        () { if (mounted) _ctrl.reverse(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.of(context).padding.top + 16, right: 16,
    child: FadeTransition(opacity: _opacity,
      child: SlideTransition(position: _slide,
        child: Material(color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35),
                  blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.msg,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600, height: 1.3))),
            ]),
          ),
        ),
      ),
    ),
  );
}