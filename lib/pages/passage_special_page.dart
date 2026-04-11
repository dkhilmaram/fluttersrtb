// pubspec.yaml — add these dependencies:
//   mobile_scanner: ^5.2.3
//   nfc_manager: ^3.3.0
//
// Android: add to AndroidManifest.xml
//   <uses-permission android:name="android.permission.CAMERA"/>
//   <uses-permission android:name="android.permission.NFC"/>
//   <uses-feature android:name="android.hardware.nfc" android:required="false"/>
// iOS: add to Info.plist
//   <key>NSCameraUsageDescription</key>
//   <string>Scan transport tickets</string>
//   <key>NFCReaderUsageDescription</key>
//   <string>Read transport NFC cards</string>
// iOS: add to Runner.entitlements
//   <key>com.apple.developer.nfc.readersession.formats</key>
//   <array><string>TAG</string></array>

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter/services.dart';
import '../ticket_repository.dart';

// ── Shared color palette ──
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

// ── All categories ──
const List<Map<String, dynamic>> kCategories = [
  {'label': 'Armée nationale',        'icon': Icons.shield_rounded,            'color': Color(0xFF1E40AF)},
  {'label': 'Garde nationale',        'icon': Icons.security_rounded,          'color': Color(0xFF1D4ED8)},
  {'label': 'Police nationale',       'icon': Icons.local_police_rounded,      'color': Color(0xFF1E3A5F)},
  {'label': 'Douane',                 'icon': Icons.account_balance_rounded,   'color': Color(0xFF374151)},
  {'label': 'Ministère',              'icon': Icons.domain_rounded,            'color': Color(0xFF6B21A8)},
  {'label': 'Municipalité',           'icon': Icons.location_city_rounded,     'color': Color(0xFF065F46)},
  {'label': 'Établissement scolaire', 'icon': Icons.school_rounded,            'color': Color(0xFFB45309)},
  {'label': 'Autre institution',      'icon': Icons.groups_rounded,            'color': Color(0xFF9D174D)},
  {'label': 'Abonnement',             'icon': Icons.confirmation_number_rounded, 'color': Color(0xFF0369A1)},
  {'label': 'Agent',                  'icon': Icons.badge_rounded,             'color': Color(0xFF7C3AED)},
];

class PassageSpecialPage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;
  final bool embeddedMode;

  const PassageSpecialPage({
    super.key,
    required this.voyage,
    required this.segment,
    this.embeddedMode = false,
  });

  @override
  State<PassageSpecialPage> createState() => _PassageSpecialPageState();
}

class _PassageSpecialPageState extends State<PassageSpecialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _activeTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dep = widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '?';
    final arr = widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: surface,
      body: Column(children: [
        if (!widget.embeddedMode) _buildHeader(dep, arr),
        Container(
          color: cardWhite,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TabBar(
            controller: _tabCtrl,
            labelPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [navyDark, navyLight]),
              borderRadius: BorderRadius.circular(10),
            ),
            dividerColor: Colors.transparent,
            tabs: [
              _buildTab(Icons.card_membership_rounded,  'Passage Gratuit',   0),
              _buildTab(Icons.qr_code_scanner_rounded,  'NFC / Code-barres', 1),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _PassageGratuitTab(voyage: widget.voyage, segment: widget.segment),
              _ScanTab(voyage: widget.voyage, segment: widget.segment),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildTab(IconData icon, String label, int idx) {
    final selected = _activeTab == idx;
    return Tab(
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16,
              color: selected ? Colors.white : Colors.grey.shade400),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(String dep, String arr) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDark, navyMid, navyLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(children: [
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
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
        ),
        const SizedBox(height: 16),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
                blurRadius: 14, offset: const Offset(0, 5))],
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.directions_bus, size: 36, color: navyMid)),
        ),
        const SizedBox(height: 10),
        const Text('S R T B',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold, letterSpacing: 7)),
        const SizedBox(height: 3),
        Text('Titres & Passages spéciaux',
            style: TextStyle(color: Colors.white.withOpacity(0.7),
                fontSize: 11, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: goldLight, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(dep, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.4), size: 12),
            ),
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: goldLight, width: 2))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(arr, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// TAB 1 — PASSAGE GRATUIT
// ════════════════════════════════════════════════════

class _PassageGratuitTab extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;
  const _PassageGratuitTab({required this.voyage, required this.segment});
  @override
  State<_PassageGratuitTab> createState() => _PassageGratuitTabState();
}

class _PassageGratuitTabState extends State<_PassageGratuitTab> {
  String? selectedCategory;
  int    quantite         = 1;
  bool   isSaving         = false;
  int    totalEnregistres = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError ? Colors.red.shade700
        : isWarning ? Colors.orange.shade700
        : const Color(0xFF16A34A);
    final icon = isError ? Icons.error_outline
        : isWarning ? Icons.offline_bolt
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

  bool get _canSave => selectedCategory != null;

  String _buildTypeTarif(String category) {
    if (category == 'Agent' || category == 'Abonnement') return category;
    return 'Gratuit — $category';
  }

  Future<void> _enregistrer() async {
    if (!_canSave) return;
    setState(() => isSaving = true);

    final result = await TicketRepository.saveTicket({
      'id_vente':        widget.voyage['id'] as int? ?? 0,
      'id_segment':      widget.segment['id_segment'] as int? ?? 0,
      'point_depart':    widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '',
      'point_arrivee':   widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '',
      'type_tarif':      _buildTypeTarif(selectedCategory!),
      'quantite':        quantite,
      'prix_unitaire':   0,
      'montant_total':   0,
      'matricule_agent': widget.voyage['matricule_agent'] ?? 0,
    });

    if (result.success) {
      final saved = quantite;
      setState(() {
        totalEnregistres += saved;
        selectedCategory  = null;
        quantite          = 1;
      });
      _showToast('$saved passage(s) enregistré(s)');
    } else {
      _showToast('Erreur : ${result.error ?? "inconnue"}', isError: true);
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (totalEnregistres > 0)
          _SessionBanner(
            icon: Icons.how_to_reg_rounded,
            text: '$totalEnregistres passage(s) enregistré(s) cette session',
          ),
        _SectionLabel('Institution / Agence', Icons.domain_rounded),
        const SizedBox(height: 10),
        _CategoryGrid(
          items: kCategories.where((c) =>
              !(c['label'] as String).startsWith(RegExp(r'Abonnement|Agent'))).toList(),
          selected: selectedCategory,
          onSelect: (v) => setState(() => selectedCategory = v),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Type spécial', Icons.confirmation_number_rounded),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _CategoryButton(
            item: {'label': 'Abonnement', 'icon': Icons.confirmation_number_rounded,
                   'color': const Color(0xFF0369A1)},
            selected: selectedCategory == 'Abonnement',
            onTap: () => setState(() => selectedCategory = 'Abonnement'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _CategoryButton(
            item: {'label': 'Agent', 'icon': Icons.badge_rounded,
                   'color': const Color(0xFF7C3AED)},
            selected: selectedCategory == 'Agent',
            onTap: () => setState(() => selectedCategory = 'Agent'),
          )),
        ]),
        const SizedBox(height: 24),
        _SectionLabel('Nombre de personnes', Icons.people_rounded),
        const SizedBox(height: 10),
        _QuantiteCard(
          quantite: quantite,
          onDec: quantite > 1 ? () => setState(() => quantite--) : null,
          onInc: () => setState(() => quantite++),
        ),
        const SizedBox(height: 16),
        if (_canSave) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8C8F0)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: navyMid, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '$quantite personne(s) · ${_buildTypeTarif(selectedCategory!)}',
                style: const TextStyle(fontSize: 12, color: navyMid,
                    fontWeight: FontWeight.w600),
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        _BigBtn(
          label: isSaving ? 'Enregistrement...' : 'Enregistrer le passage',
          icon: Icons.how_to_reg_rounded,
          isLoading: isSaving,
          enabled: _canSave && !isSaving,
          colors: const [Color(0xFF065F46), Color(0xFF059669)],
          onTap: _enregistrer,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// TAB 2 — NFC / BARCODE SCAN
// ════════════════════════════════════════════════════

class _ScanTab extends StatefulWidget {
  final Map<String, dynamic> voyage;
  final Map<String, dynamic> segment;
  const _ScanTab({required this.voyage, required this.segment});
  @override
  State<_ScanTab> createState() => _ScanTabState();
}

enum _ScanState { idle, success, error }

class _ScanTabState extends State<_ScanTab> {
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

    final color = isError ? Colors.red.shade700
        : isWarning ? Colors.orange.shade700
        : const Color(0xFF16A34A);
    final icon = isError ? Icons.error_outline
        : isWarning ? Icons.offline_bolt
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

  // ── BARCODE: open camera page ──
  Future<void> _openBarcodeScanner() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _CameraScannerPage(),
        fullscreenDialog: true,
      ),
    );
    if (raw == null) return;
    _resolveCode(raw, 'Barcode');
  }

  // ── NFC: start foreground dispatch ──
  Future<void> _startNfcScan() async {
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      if (mounted) _showToast('NFC non disponible sur cet appareil', isWarning: true);
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
            if (mounted) setState(() {
              scanState = _ScanState.error;
              errorMsg  = 'Carte NFC illisible ou invalide';
            });
          } else {
            _resolveCode(raw, 'NFC');
          }
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: 'Erreur de lecture')
              .catchError((_) {});
          if (mounted) setState(() {
            scanState = _ScanState.error;
            errorMsg  = 'Erreur NFC : $e';
          });
        }
      },
      alertMessage: 'Approchez votre carte de transport',
    );
  }

  /// Extracts a readable string from the NFC tag.
  ///
  /// Priority order:
  ///   1. NDEF text record
  ///   2. NDEF URI record
  ///   3. NDEF generic payload (UTF-8)
  ///   4. Identifier bytes from tag.data (MifareClassic, MifareUltralight,
  ///      NFC-A/B, ISO-7816, FeliCa) — avoids platform-specific class imports
  ///      that are absent in nfc_manager ^3.x on all platforms.
  String? _extractRawFromTag(NfcTag tag) {
    // 1. Try NDEF records
    final ndef = Ndef.from(tag);
    if (ndef != null && ndef.cachedMessage != null) {
      for (final record in ndef.cachedMessage!.records) {
        // Text record (TNF wellknown, type byte 'T' = 0x54)
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
        // URI record (TNF wellknown, type byte 'U' = 0x55)
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
            record.type.isNotEmpty && record.type[0] == 0x55) {
          final payload = record.payload;
          if (payload.length > 1) {
            return utf8.decode(payload.sublist(1));
          }
        }
        // Generic payload — try UTF-8
        try {
          final text = utf8.decode(record.payload, allowMalformed: false).trim();
          if (text.isNotEmpty) return text;
        } catch (_) {}
      }
    }

    // 2. Identifier bytes from tag.data map
    //    nfc_manager 3.x exposes raw tag data as nested maps keyed by
    //    technology name (lowercase). We probe every known key that carries
    //    an identifier / UID / IDm field.
    final data = tag.data;

    // Helper: turn a dynamic list field into a hex string.
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

    // Android ISO-A (includes Mifare Classic & Mifare Ultralight)
    final hexA = hexFromField(data['nfca']?['identifier']);
    if (hexA != null) return hexA;

    // Android ISO-B
    final hexB = hexFromField(data['nfcb']?['applicationData']);
    if (hexB != null) return hexB;

    // Android Mifare Classic (redundant with nfca but kept for clarity)
    final hexMC = hexFromField(data['mifareClassic']?['identifier']);
    if (hexMC != null) return hexMC;

    // Android Mifare Ultralight
    final hexMU = hexFromField(data['mifareUltralight']?['identifier']);
    if (hexMU != null) return hexMU;

    // iOS Core NFC / ISO-7816
    final hexISO = hexFromField(data['iso7816']?['identifier']);
    if (hexISO != null) return hexISO;

    // FeliCa (Japan / some transit cards)
    final hexFelica = hexFromField(data['feliCa']?['currentIdm']);
    if (hexFelica != null) return hexFelica;

    // Android NFC-F (FeliCa via nfcf key)
    final hexF = hexFromField(data['nfcf']?['manufacturer']);
    if (hexF != null) return hexF;

    // Android NFC-V (ISO 15693)
    final hexV = hexFromField(data['nfcv']?['identifier']);
    if (hexV != null) return hexV;

    return null;
  }

  void _resolveCode(String raw, String mode) {
    String type = 'Inconnu';
    final up = raw.toUpperCase();
    if (up.contains('MEN'))      type = 'Mensuel';
    else if (up.contains('ANN')) type = 'Annuel';
    else if (up.contains('ETU')) type = 'Étudiant';
    else if (up.contains('RET')) type = 'Retraité';
    else if (up.contains('TRI')) type = 'Trimestriel';

    if (!mounted) return;
    setState(() {
      scanState   = _ScanState.success;
      scannedData = {
        'mode':        mode,
        'numero':      raw,
        'type':        type,
        'valid_until': '—',
        'ligne': widget.voyage['nom_ligne'] ??
                 'Ligne ${widget.voyage['id_ligne']}',
      };
    });
  }

  String _buildScanTypeTarif(String mode, String type) => 'Scan $mode — $type';

  Future<void> _validerEtVendre() async {
    if (scannedData == null) return;
    setState(() => isSaving = true);

    final result = await TicketRepository.saveTicket({
      'id_vente':        widget.voyage['id'] as int? ?? 0,
      'id_segment':      widget.segment['id_segment'] as int? ?? 0,
      'point_depart':    widget.segment['point_depart']  ?? widget.voyage['depart']  ?? '',
      'point_arrivee':   widget.segment['point_arrivee'] ?? widget.voyage['arrivee'] ?? '',
      'type_tarif':      _buildScanTypeTarif(
                             scannedData!['mode'] as String,
                             scannedData!['type'] as String),
      'quantite':        1,
      'prix_unitaire':   0,
      'montant_total':   0,
      'matricule_agent': widget.voyage['matricule_agent'] ?? 0,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// NFC listening bottom sheet
// ════════════════════════════════════════════════════

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
  Widget build(BuildContext context) {
    return Container(
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
}

// ════════════════════════════════════════════════════
// Barcode camera scanner page
// ════════════════════════════════════════════════════

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
  Widget build(BuildContext context) {
    return Scaffold(
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
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text(
                'Scanner le code-barres / QR',
                style: TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600),
              )),
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
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                const Flexible(child: Text('Centrez le code dans le cadre',
                    style: TextStyle(color: Colors.white70, fontSize: 12))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
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
        painter: _OverlayPainter(cutRect: Rect.fromLTWH(left, top, boxSz, boxSz)));
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

// ════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════

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
  final String text;
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

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({required this.items, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, mainAxisSpacing: 10,
      crossAxisSpacing: 10, childAspectRatio: 2.8,
    ),
    itemBuilder: (_, i) => _CategoryButton(
      item: items[i],
      selected: selected == items[i]['label'],
      onTap: () => onSelect(items[i]['label'] as String),
    ),
  );
}

class _CategoryButton extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryButton({required this.item, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = item['color'] as Color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: navyMid.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(item['icon'] as IconData, size: 16,
              color: selected ? Colors.white : color),
          const SizedBox(width: 7),
          Expanded(child: Text(item['label'] as String,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : navyDark))),
        ]),
      ),
    );
  }
}

class _QuantiteCard extends StatelessWidget {
  final int quantite;
  final VoidCallback? onDec;
  final VoidCallback onInc;
  const _QuantiteCard({required this.quantite, this.onDec, required this.onInc});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: cardWhite, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: navyMid.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      _QtyBtn(icon: Icons.remove, enabled: onDec != null, onTap: onDec ?? () {}),
      Expanded(child: Column(children: [
        Text('$quantite', style: const TextStyle(fontSize: 28,
            fontWeight: FontWeight.bold, color: navyDark)),
        Text(quantite == 1 ? 'personne' : 'personnes',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ])),
      _QtyBtn(icon: Icons.add, enabled: true, onTap: onInc),
    ]),
  );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: enabled ? navyMid : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [BoxShadow(color: navyMid.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
      ),
      child: Icon(icon,
          color: enabled ? Colors.white : Colors.grey.shade300, size: 18),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 14, color: navyLight.withOpacity(0.5)),
        const SizedBox(width: 10),
        Flexible(flex: 2, child: Text(label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
        const SizedBox(width: 4),
        Flexible(flex: 3, child: Text(value,
            textAlign: TextAlign.end, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 13, color: navyDark))),
      ]),
    ),
    Divider(height: 1, color: Colors.grey.shade100),
  ]);
}

class _IdleWidget extends StatelessWidget {
  const _IdleWidget({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: cardWhite, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100, width: 1.5),
      boxShadow: [BoxShadow(color: navyMid.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Column(children: [
      Icon(Icons.qr_code_scanner_rounded, size: 56, color: Colors.grey.shade200),
      const SizedBox(height: 14),
      Text('Prêt à scanner', style: TextStyle(fontSize: 15,
          fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
      const SizedBox(height: 6),
      Text('Choisissez NFC ou Code-barres\npour lancer la lecture',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.5)),
    ]),
  );
}

class _ScanResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSaving;
  final VoidCallback onCancel, onValidate;
  const _ScanResultWidget({super.key, required this.data, required this.isSaving,
      required this.onCancel, required this.onValidate});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: cardWhite, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.1),
          blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Color(0xFFDCFCE7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded,
                  color: Color(0xFF16A34A), size: 24)),
          const SizedBox(width: 12),
          const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Titre détecté', style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
            Text('Vérifiez et validez',
                style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(20)),
            child: Text(data['mode'] as String,
                style: const TextStyle(color: Colors.white,
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _InfoRow(Icons.confirmation_number_outlined, 'Code scanné', data['numero']),
          _InfoRow(Icons.sell_outlined, 'Type', data['type']),
          _InfoRow(Icons.event_rounded, "Valable jusqu'au", data['valid_until']),
          _InfoRow(Icons.route_rounded, 'Ligne', data['ligne']),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade500,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Annuler',
                style: TextStyle(fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: isSaving ? null : onValidate,
            icon: isSaving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(isSaving ? 'Enregistrement...' : 'Valider & Enregistrer',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ),
    ]),
  );
}

class _ScanErrorWidget extends StatelessWidget {
  final String msg;
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
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 30)),
      const SizedBox(height: 14),
      Text(msg, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
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

class _ScanModeBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
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
            gradient: enabled ? LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: enabled ? null : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon, color: enabled ? Colors.white : Colors.grey.shade400, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: enabled ? Colors.white : Colors.grey.shade400)),
              Text(sublabel, style: TextStyle(fontSize: 10,
                  color: enabled ? Colors.white.withOpacity(0.7) : Colors.grey.shade400)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading, enabled;
  final List<Color> colors;
  final VoidCallback onTap;
  const _BigBtn({required this.label, required this.icon,
      required this.isLoading, required this.enabled,
      required this.colors, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: Material(
      color: Colors.transparent, borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled ? LinearGradient(colors: colors,
                begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: enabled ? null : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(color: colors.first.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (isLoading)
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              Icon(icon, color: enabled ? Colors.white : Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: enabled ? Colors.white : Colors.grey.shade400))),
          ]),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════
// Toast widget
// ════════════════════════════════════════════════════

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
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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