import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/database/daos/voyage_dao.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../ticketing/vente_tickets.dart';
import '../../widgets/language_switcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/offline_toast_notification.dart';

// ─────────────────────────────────────────────────────────────
// ⚠️  CONFIGURE THIS before shipping
// ─────────────────────────────────────────────────────────────
const String _kReportRecipient = 'dkhilmaram12@gmail.com';
const String _kSmtpHost        = 'smtp.gmail.com';
const int    _kSmtpPort        = 587;
const String _kSmtpUser        = 'dkhilmaram0@gmail.com';
const String _kSmtpPassword    = 'ppax xarr sfwc wejn';
// ─────────────────────────────────────────────────────────────

class VoyageProgrammePage extends StatefulWidget {
  final Map<String, dynamic> agent;
  const VoyageProgrammePage({super.key, required this.agent});

  @override
  State<VoyageProgrammePage> createState() => _VoyageProgrammePageState();
}

class _VoyageProgrammePageState extends State<VoyageProgrammePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Programmés state ──
  List<dynamic> voyagesProgrammes    = [];
  bool isLoadingProgrammes           = true;
  bool isOfflineProgrammes           = false;
  String? errorProgrammes;

  // ── Non programmés state ──
  List<dynamic> voyagesNonProgrammes = [];
  bool isLoadingNonProgrammes        = true;
  bool isOfflineNonProgrammes        = false;
  String? errorNonProgrammes;

  // ── Shared top-level action state ──
  bool _clotureConfirming = false;
  bool _clotureLoading    = false;
  bool _reopenLoading     = false;
  bool _exportLoading     = false;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  final String _todayLabel = () {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    return '$d/$m/$y';
  }();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProgrammes();
    _fetchNonProgrammes();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Toast
  // ─────────────────────────────────────────────────────────────
  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final Color color;
    final IconData icon;
    if (isError) {
      color = const Color(0xFF8B1A1A);
      icon  = Icons.error_outline;
    } else if (isWarning) {
      color = Colors.orange.shade700;
      icon  = Icons.offline_bolt;
    } else {
      color = const Color(0xFF16A34A);
      icon  = Icons.check_circle_outline;
    }

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────
  int get _matricule =>
      widget.agent['matricule_agent'] ?? widget.agent['matricule'];

  int get _matriculeNonProg => -_matricule;

  int get _activeIndex {
    for (int i = 0; i < voyagesProgrammes.length; i++) {
      if (voyagesProgrammes[i]['statut'] != 'cloture') return i;
    }
    return -1;
  }

  bool get _allClotures {
    final hasProg    = voyagesProgrammes.isNotEmpty;
    final hasNonProg = voyagesNonProgrammes.isNotEmpty;
    if (!hasProg && !hasNonProg) return false;
    final progDone    = !hasProg    || voyagesProgrammes.every((v) => v['statut'] == 'cloture');
    final nonProgDone = !hasNonProg || voyagesNonProgrammes.every((v) => v['statut'] == 'cloture');
    return progDone && nonProgDone;
  }

  // ─────────────────────────────────────────────────────────────
  // Merge local offline statuts
  // ─────────────────────────────────────────────────────────────
  Future<List<dynamic>> _mergeLocalStatuts(List<dynamic> voyages) async {
    final pendingClotures   = await VoyageDao.getPendingClotures();
    final pendingClotureIds = pendingClotures
        .map((r) => r['id_voyage'] as int)
        .toSet();

    final merged = <dynamic>[];
    for (final v in voyages) {
      final voyage  = Map<String, dynamic>.from(v as Map);
      final idVente = (voyage['id_voyage'] ?? voyage['id']) as int?;

      if (idVente != null) {
        final reopenPending = await VoyageDao.isReopenPending(idVente);
        if (reopenPending) {
          voyage['statut'] = 'actif';
          merged.add(voyage);
          continue;
        }
        if (pendingClotureIds.contains(idVente)) {
          voyage['statut'] = 'cloture';
          merged.add(voyage);
          continue;
        }
        final localStatut = await VoyageDao.getVoyageStatut(idVente);
        if (localStatut == 'cloture' || localStatut == 'cloture_pending') {
          voyage['statut'] = 'cloture';
        }
      }
      merged.add(voyage);
    }
    return merged;
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch — Programmés
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchProgrammes() async {
    setState(() { isLoadingProgrammes = true; errorProgrammes = null; });
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.voyagesProgrammes(_matricule)),
              headers: {'Content-Type': 'application/json'})
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body)['voyages'] as List<dynamic>;
        await VoyageDao.clearStaleVoyageStatuts(list);
        await VoyageDao.saveVoyages(_matricule, list);
        final merged = await _mergeLocalStatuts(list);
        setState(() {
          voyagesProgrammes   = merged;
          isOfflineProgrammes = false;
          isLoadingProgrammes = false;
        });
        return;
      }
    } catch (_) {}

    final cached = await VoyageDao.getVoyages(_matricule);
    if (cached != null) {
      final merged = await _mergeLocalStatuts(cached);
      setState(() {
        voyagesProgrammes   = merged;
        isOfflineProgrammes = true;
        isLoadingProgrammes = false;
      });
      _maybeShowOfflineToast();
    } else {
      final t = AppLocalizations.of(context)!;
      setState(() { errorProgrammes = t.horsLignePasDeDonnees; isLoadingProgrammes = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch — Non programmés
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchNonProgrammes() async {
    setState(() { isLoadingNonProgrammes = true; errorNonProgrammes = null; });
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.voyagesNonProgrammes(_matricule)),
              headers: {'Content-Type': 'application/json'})
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final all  = jsonDecode(response.body)['voyages'] as List<dynamic>;
        final list = all.where((v) => v['type'] != 'programmé').map((v) {
          final voyage = Map<String, dynamic>.from(v as Map);
          voyage['matricule_agent'] ??= _matricule;
          voyage['id_appareil']     ??= widget.agent['id_appareil'];
          voyage['id_billet']       ??= widget.agent['id_billet'];
          voyage['code_agence']     ??= widget.agent['code_agence'];
          voyage['statut']          ??= 'actif';
          return voyage;
        }).toList();
        await VoyageDao.clearStaleVoyageStatuts(list);
        await VoyageDao.saveVoyages(_matriculeNonProg, list);
        final merged = await _mergeLocalStatuts(list);
        setState(() {
          voyagesNonProgrammes   = merged;
          isOfflineNonProgrammes = false;
          isLoadingNonProgrammes = false;
        });
        return;
      }
    } catch (_) {}

    final cached = await VoyageDao.getVoyages(_matriculeNonProg);
    if (cached != null) {
      final list = cached.map((v) {
        final voyage = Map<String, dynamic>.from(v as Map);
        voyage['matricule_agent'] ??= _matricule;
        voyage['id_appareil']     ??= widget.agent['id_appareil'];
        voyage['id_billet']       ??= widget.agent['id_billet'];
        voyage['code_agence']     ??= widget.agent['code_agence'];
        voyage['statut']          ??= 'actif';
        return voyage;
      }).toList();
      final merged = await _mergeLocalStatuts(list);
      setState(() {
        voyagesNonProgrammes   = merged;
        isOfflineNonProgrammes = true;
        isLoadingNonProgrammes = false;
      });
      _maybeShowOfflineToast();
    } else {
      final t = AppLocalizations.of(context)!;
      setState(() { errorNonProgrammes = t.horsLignePasDeDonnees; isLoadingNonProgrammes = false; });
    }
  }

  void _maybeShowOfflineToast() {
    if (_toastEntry == null) OfflineToastNotification.show(context);
  }

  // ─────────────────────────────────────────────────────────────
  // Clôture Journée
  // ─────────────────────────────────────────────────────────────
  Future<void> _clotureJourneeAll() async {
    final t = AppLocalizations.of(context)!;
    setState(() { _clotureLoading = true; _clotureConfirming = false; });

    final toCloseProg    = voyagesProgrammes.where((v) => v['statut'] != 'cloture').toList();
    final toCloseNonProg = voyagesNonProgrammes.where((v) => v['statut'] != 'cloture').toList();
    final allToClose     = [...toCloseProg, ...toCloseNonProg];

    if (allToClose.isEmpty) {
      setState(() => _clotureLoading = false);
      _showToast(t.tousDejaClotureToast);
      return;
    }

    final ids = allToClose
        .map((v) => (v['id_voyage'] ?? v['id']) as int?)
        .whereType<int>()
        .toList();

    bool success = false;
    bool offline = false;
    int  closedQt = 0;

    try {
      final response = await http
          .put(Uri.parse(ApiConstants.clotureJournee),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'ids': ids}))
          .timeout(ApiConstants.actionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          success  = true;
          closedQt = (data['closed'] as int?) ?? ids.length;
        } else { offline = true; }
      } else { offline = true; }
    } catch (_) { offline = true; }

    if (offline) {
      for (final id in ids) {
        await VoyageDao.saveCloturePending(id);
        await VoyageDao.saveVoyageStatut(id, 'cloture', serverStatut: 'actif');
      }
      success  = true;
      closedQt = ids.length;
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        for (final v in toCloseProg)    v['statut'] = 'cloture';
        for (final v in toCloseNonProg) v['statut'] = 'cloture';
        _clotureLoading = false;
      });
      _showToast(
        offline ? t.journeeClotureOffline(closedQt) : t.journeeCloture(closedQt),
        isWarning: offline,
      );
      if (!offline) {
        await _fetchProgrammes();
        await _fetchNonProgrammes();
      }
    } else {
      setState(() => _clotureLoading = false);
      _showToast(t.echecCloture, isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Réouvrir Journée
  // ─────────────────────────────────────────────────────────────
  Future<void> _reopenJourneeAll() async {
    final t = AppLocalizations.of(context)!;
    final allClotures = [
      ...voyagesProgrammes.where((v) => v['statut'] == 'cloture'),
      ...voyagesNonProgrammes.where((v) => v['statut'] == 'cloture'),
    ];

    if (allClotures.isEmpty) { _showToast(t.aucunAReouvrirToast); return; }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReopenJourneeConfirmSheet(
          count: allClotures.length, todayLabel: _todayLabel),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reopenLoading = true);
    _showToast(t.reouvertureEnCours);

    final ids = allClotures
        .map((v) => (v['id_voyage'] ?? v['id']) as int?)
        .whereType<int>()
        .toList();

    bool success = false;
    bool offline = false;

    try {
      final response = await http
          .put(Uri.parse(ApiConstants.reopenJournee),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'ids': ids}))
          .timeout(ApiConstants.actionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) { success = true; } else { offline = true; }
      } else { offline = true; }
    } catch (_) { offline = true; }

    if (offline) {
      for (final id in ids) {
        await VoyageDao.clearVoyageStatut(id);
        await VoyageDao.saveReopenPending(id, scope: 'journee');
      }
      success = true;
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        for (final v in allClotures) v['statut'] = 'actif';
        _reopenLoading = false;
      });
      _showToast(
        offline ? t.journeeReouverteOffline(ids.length) : t.journeeReouverte(ids.length),
        isWarning: offline,
      );
      if (!offline) {
        await _fetchProgrammes();
        await _fetchNonProgrammes();
      }
    } else {
      setState(() => _reopenLoading = false);
      _showToast(t.echecReouverture, isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reopen single voyage
  // ─────────────────────────────────────────────────────────────
  Future<void> _reopenVoyage(Map<String, dynamic> voyage) async {
    final t       = AppLocalizations.of(context)!;
    final idVente = (voyage['id_voyage'] ?? voyage['id']) as int?;
    if (idVente == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReopenConfirmSheet(voyage: voyage),
    );
    if (confirmed != true || !mounted) return;
    _showToast(t.reouvertureEnCours);

    bool success = false;
    bool offline = false;

    try {
      final response = await http
          .put(Uri.parse(ApiConstants.reopenVoyage(idVente)),
              headers: {'Content-Type': 'application/json'})
          .timeout(ApiConstants.reopenTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await VoyageDao.clearVoyageStatut(idVente);
          success = true;
        } else { offline = true; }
      } else { offline = true; }
    } catch (_) { offline = true; }

    if (offline) {
      await VoyageDao.clearVoyageStatut(idVente);
      await VoyageDao.saveReopenPending(idVente, scope: 'single');
      success = true;
    }

    if (!mounted) return;

    if (success) {
      setState(() => voyage['statut'] = 'actif');
      _showToast(
        offline ? t.voyageReouvertOffline : t.voyageReouvert,
        isWarning: offline,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Export
  // ─────────────────────────────────────────────────────────────
  Future<void> _showExportDialog() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExportFormatSheet(todayLabel: _todayLabel),
    );
    if (choice == null || !mounted) return;
    await _doExport(choice);
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final dt  = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) { return false; }
  }

  /// Returns "HH:mm:ss" from a DateTime, padded.
  String _formatTime(DateTime dt) {
    final h  = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s  = dt.second.toString().padLeft(2, '0');
    return '$h:$mi:$s';
  }

  /// Returns "dd/MM/yyyy" from a DateTime.
  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  /// Fetches segment metadata for all voyages.
  /// Returns Map<id_segment, segment_row> so we can look up labels by int key.
  Future<Map<int, Map<String, dynamic>>> _fetchAllSegments(
      List<dynamic> voyages) async {
    final result = <int, Map<String, dynamic>>{};
    for (final v in voyages) {
      final id = (v['id_voyage'] ?? v['id']) as int?;
      if (id == null) continue;
      try {
        final response = await http
            .get(Uri.parse('${ApiConstants.billetterie}/voyages/$id/segments'))
            .timeout(ApiConstants.defaultTimeout);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            for (final s in (data['segments'] as List<dynamic>)) {
              final seg = Map<String, dynamic>.from(s as Map);
              result[seg['id_segment'] as int] = seg;
            }
          }
        }
      } catch (_) {}
    }
    return result;
  }

  Future<void> _doExport(String format) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _exportLoading = true);
    _showToast(
      format == 'excel' ? t.generationExcel : t.generationPdf,
      isWarning: true,
    );

    final allVoyages = [...voyagesProgrammes, ...voyagesNonProgrammes];

    try {
      // ── Collect today's tickets ──
      final List<Map<String, dynamic>> allTickets = [];
      for (final v in allVoyages) {
        final id = (v['id_voyage'] ?? v['id']) as int?;
        if (id == null) continue;
        final rows = await TicketDao.getTicketsByVoyage(id);
        for (final r in rows) {
          final ticket = Map<String, dynamic>.from(r);
          if (_isToday(ticket['date_heure'] as String?)) allTickets.add(ticket);
        }
      }

      // ── Fetch segment metadata for all voyages ──
      final segmentMap = await _fetchAllSegments(allVoyages);

      final agent     = widget.agent;
      final agentName = '${agent['prenom'] ?? ''} ${agent['nom'] ?? ''}'.trim();
      final now       = DateTime.now();
      final dateStr   =
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.year}';

      final int totalRecette = allTickets.fold(
          0, (s, tk) => s + ((tk['montant_total'] as num? ?? 0).toInt()));
      final int totalTickets = allTickets.fold(
          0, (s, tk) => s + ((tk['quantite'] as num? ?? 1).toInt()));
      final int totalGratuits = allTickets
          .where((tk) => ((tk['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, tk) => s + ((tk['quantite'] as num? ?? 1).toInt()));

      final dir = await getTemporaryDirectory();
      File file;

      if (format == 'excel') {
        file = await _buildExcel(
          allTickets:    allTickets,
          voyages:       allVoyages,
          segmentMap:    segmentMap,
          agentName:     agentName,
          dateStr:       dateStr,
          label:         'journee_complete',
          totalRecette:  totalRecette,
          totalTickets:  totalTickets,
          totalGratuits: totalGratuits,
          dir:           dir,
        );
      } else {
        file = await _buildPdf(
          allTickets:    allTickets,
          voyages:       allVoyages,
          segmentMap:    segmentMap,
          agentName:     agentName,
          dateStr:       dateStr,
          totalRecette:  totalRecette,
          totalTickets:  totalTickets,
          totalGratuits: totalGratuits,
          dir:           dir,
        );
      }

      await _sendEmail(
        file:          file,
        format:        format,
        agentName:     agentName,
        dateStr:       dateStr,
        totalRecette:  totalRecette,
        totalTickets:  totalTickets,
        voyageCount:   allVoyages.length,
      );

      _showToast(t.rapportEnvoye);
    } catch (e) {
      debugPrint('❌ Export error: $e');
      _showToast(t.erreurExport(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build Excel  (6 sheets)
  // ─────────────────────────────────────────────────────────────
  Future<File> _buildExcel({
    required List<Map<String, dynamic>> allTickets,
    required List<dynamic> voyages,
    required Map<int, Map<String, dynamic>> segmentMap,
    required String agentName,
    required String dateStr,
    required String label,
    required int totalRecette,
    required int totalTickets,
    required int totalGratuits,
    required Directory dir,
  }) async {

    // ── Local helper: int id_segment → "Seg. 1 · ras jebel → aousja" ──
  String segLabel(dynamic rawId) {
      final id = rawId == null ? null : int.tryParse(rawId.toString());
      if (id == null || id == 0) return '—';
      final seg = segmentMap[id];
      if (seg == null) return 'Seg. #$id';
      return 'Seg. ${seg['ordre']}';
    }

    // ── Local helper: raw id_segment → int or null ──
   int? segIdInt(dynamic rawId) {
  if (rawId == null) return null;
  final str = rawId.toString().trim();
  if (str.isEmpty || str == '0' || str == 'null') return null;
  return int.tryParse(str);
}

    final excel = xl.Excel.createExcel();
    excel.delete('Sheet1');

    void header(xl.Sheet s, int row, int col, String text) {
      final c = s.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = xl.TextCellValue(text);
      c.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#1A3260'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    void cell(xl.Sheet s, int row, int col, dynamic value,
        {bool bold = false, String? bgHex, String? fgHex}) {
      final c = s.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is int)         c.value = xl.IntCellValue(value);
      else if (value is double) c.value = xl.DoubleCellValue(value);
      else                      c.value = xl.TextCellValue(value?.toString() ?? '');
      c.cellStyle = xl.CellStyle(
        bold: bold,
        backgroundColorHex: xl.ExcelColor.fromHexString(bgHex ?? '#FFFFFF'),
        fontColorHex: xl.ExcelColor.fromHexString(fgHex ?? '#000000'),
      );
    }

    // ── 1. Résumé ──
    final resume = excel['Résumé'];
    cell(resume, 0, 0, 'RAPPORT JOURNÉE — $_todayLabel', bold: true, fgHex: '#0D1B3E');
    cell(resume, 1, 0, 'Agent : $agentName', fgHex: '#374151');
    cell(resume, 2, 0, 'Généré le $dateStr', fgHex: '#6B7280');
    header(resume, 4, 0, 'Indicateur');
    header(resume, 4, 1, 'Valeur');

    final payants   = totalTickets - totalGratuits;
    final prixMoyen = payants > 0
        ? (allTickets
                .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) > 0)
                .fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt())) /
            payants)
            .round()
        : 0;

    final kpis = [
      ['Recette totale (ms)',         totalRecette],
      ['Recette totale (DT)',          '${(totalRecette / 1000).toStringAsFixed(3)} DT'],
      ['Total tickets vendus',         totalTickets],
      ['Tickets payants',              payants],
      ['Tickets gratuits',             totalGratuits],
      ['Prix moyen/ticket (ms)',       prixMoyen],
      ['Taux de gratuité',             totalTickets > 0
          ? '${((totalGratuits / totalTickets) * 100).toStringAsFixed(1)}%' : '0%'],
      ['Voyages programmés',           voyagesProgrammes.length],
      ['Voyages non programmés',       voyagesNonProgrammes.length],
      ['Total voyages',                voyages.length],
    ];

    for (int i = 0; i < kpis.length; i++) {
      final bg = i.isEven ? '#F2F5FB' : '#FFFFFF';
      cell(resume, 5 + i, 0, kpis[i][0], bgHex: bg, bold: true);
      cell(resume, 5 + i, 1, kpis[i][1], bgHex: bg,
          fgHex: kpis[i][0].toString().contains('Recette')
              ? '#0D1B3E'
              : kpis[i][0].toString().contains('gratuit')
                  ? '#16A34A'
                  : '#111827');
    }
    resume.setColumnWidth(0, 32);
    resume.setColumnWidth(1, 22);

    // ── 2. Tickets ──
    // Columns: #, id_segment, Date, Heure (HH:mm:ss), Voyage, Départ, Arrivée,
    //          Segment label, Tarif, Qté, Prix unit. (ms), Total (ms), Sync
    final ticketsSheet = excel['Tickets'];
    final tHeaders = [
      '#', 'id_segment', 'Date', 'Heure', 'Voyage', 'Départ', 'Arrivée',
      'Segment', 'Tarif', 'Qté', 'Prix unit. (ms)', 'Total (ms)', 'Sync',
    ];
    for (int c = 0; c < tHeaders.length; c++) header(ticketsSheet, 0, c, tHeaders[c]);

    for (int i = 0; i < allTickets.length; i++) {
      final t      = allTickets[i];
      final isFree = ((t['montant_total'] as num? ?? 0).toInt()) == 0;
      final dt     = DateTime.tryParse(t['date_heure'] ?? '');
      final bg     = i.isEven ? '#F9FAFB' : '#FFFFFF';
      final rawSegId = t['id_segment'];
      final segId    = segIdInt(rawSegId);

      cell(ticketsSheet, i + 1, 0,  i + 1,                                       bgHex: bg);
      // ── NEW: raw id_segment ──
     cell(ticketsSheet, i + 1, 1,
    rawSegId != null && rawSegId.toString() != '0' && rawSegId.toString() != 'null'
        ? rawSegId.toString()
        : '—',
    bgHex: bg, fgHex: '#6B7280');
      cell(ticketsSheet, i + 1, 2,  dt != null ? _formatDate(dt) : '',           bgHex: bg);
      // ── Time now includes seconds: HH:mm:ss ──
      cell(ticketsSheet, i + 1, 3,  dt != null ? _formatTime(dt) : '',           bgHex: bg);
      cell(ticketsSheet, i + 1, 4,  t['id_voyage'] != null ? '#${t['id_voyage']}' : '—', bgHex: bg);
      cell(ticketsSheet, i + 1, 5,  t['point_depart']  ?? '',                    bgHex: bg);
      cell(ticketsSheet, i + 1, 6,  t['point_arrivee'] ?? '',                    bgHex: bg);
      cell(ticketsSheet, i + 1, 7,  segLabel(rawSegId),                          bgHex: bg);
      cell(ticketsSheet, i + 1, 8,  t['type_tarif'] ?? '',                       bgHex: bg);
      cell(ticketsSheet, i + 1, 9,  (t['quantite'] as num? ?? 1).toInt(),        bgHex: bg);
      cell(ticketsSheet, i + 1, 10, (t['prix_unitaire'] as num? ?? 0).toInt(),   bgHex: bg);
      cell(ticketsSheet, i + 1, 11, (t['montant_total'] as num? ?? 0).toInt(),
          bgHex: bg, bold: isFree, fgHex: isFree ? '#16A34A' : '#0D1B3E');
      cell(ticketsSheet, i + 1, 12, t['statut_sync'] ?? 'synced',                bgHex: bg,
          fgHex: t['statut_sync'] == 'pending'
              ? '#D97706'
              : t['statut_sync'] == 'failed'
                  ? '#DC2626'
                  : '#16A34A');
    }

    final tTotalRow = allTickets.length + 2;
    cell(ticketsSheet, tTotalRow, 8,  'TOTAL',       bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    cell(ticketsSheet, tTotalRow, 9,  totalTickets,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(ticketsSheet, tTotalRow, 11, totalRecette,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');

    // Column widths: #, id_seg, Date, Heure, Voyage, Départ, Arrivée, Seg label, Tarif, Qté, Prix, Total, Sync
    final tColWidths = [5.0, 12.0, 13.0, 12.0, 10.0, 22.0, 22.0, 30.0, 28.0, 8.0, 16.0, 14.0, 12.0];
    for (int c = 0; c < tColWidths.length; c++) {
      ticketsSheet.setColumnWidth(c, tColWidths[c]);
    }

    // ── 3. Par tarif ──
    final tarifSheet = excel['Par tarif'];
    for (int c = 0; c < ['Type de tarif','Quantité','Prix unitaire (ms)','Total (ms)','% du total'].length; c++) {
      header(tarifSheet, 0, c, ['Type de tarif','Quantité','Prix unitaire (ms)','Total (ms)','% du total'][c]);
    }
   final tarifMap = <String, Map<String, int>>{};
    final tarifDisplayNames = <String, String>{};
    for (final t in allTickets) {
      final rawType  = ((t['type_tarif'] ?? '') as String).trim();
      final qty      = (t['quantite']     as num? ?? 1).toInt();
      final tot      = (t['montant_total'] as num? ?? 0).toInt();
      final unit     = (t['prix_unitaire'] as num? ?? 0).toInt();
      final isFree   = tot == 0;
      final normType = rawType.isEmpty ? 'inconnu' : rawType.toLowerCase();
      final groupKey = isFree ? normType : '${normType}_$unit';
      tarifDisplayNames.putIfAbsent(groupKey, () => isFree
          ? (rawType.isEmpty ? 'Inconnu' : rawType)
          : '${rawType.isEmpty ? 'Inconnu' : rawType} · $unit ms');
      tarifMap[groupKey] ??= {'count': 0, 'total': 0, 'unitaire': unit};
      tarifMap[groupKey]!['count']    = tarifMap[groupKey]!['count']! + qty;
      tarifMap[groupKey]!['total']    = tarifMap[groupKey]!['total']! + tot;
      tarifMap[groupKey]!['unitaire'] = unit;
    }
    final tarifEntries = tarifMap.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));
    int tRow = 1;
   for (final e in tarifEntries) {
      final isFree  = e.value['total']! == 0;
      final pct     = totalTickets > 0
          ? '${((e.value['count']! / totalTickets) * 100).toStringAsFixed(1)}%' : '0%';
      final bg      = tRow.isOdd ? '#F9FAFB' : '#FFFFFF';
      final display = tarifDisplayNames[e.key] ?? e.key;
      cell(tarifSheet, tRow, 0, display,             bgHex: bg, bold: true);
      cell(tarifSheet, tRow, 1, e.value['count']!,   bgHex: bg);
      cell(tarifSheet, tRow, 2, isFree ? '—' : '${e.value['unitaire']}', bgHex: bg);
      cell(tarifSheet, tRow, 3, e.value['total']!,   bgHex: bg, bold: true,
          fgHex: isFree ? '#16A34A' : '#0D1B3E');
      cell(tarifSheet, tRow, 4, pct, bgHex: bg);
      tRow++;
    }
    cell(tarifSheet, tRow + 1, 0, 'TOTAL',       bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    cell(tarifSheet, tRow + 1, 1, totalTickets,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(tarifSheet, tRow + 1, 3, totalRecette,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(tarifSheet, tRow + 1, 4, '100%',        bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    tarifSheet.setColumnWidth(0, 30); tarifSheet.setColumnWidth(1, 12);
    tarifSheet.setColumnWidth(2, 20); tarifSheet.setColumnWidth(3, 16);
    tarifSheet.setColumnWidth(4, 14);

    // ── 4. Gratuits / catégorie ──
    final gratuitSheet = excel['Gratuits / catégorie'];
    final gHeaders = ['Type de tarif','Total tickets','Dont gratuits','% gratuits','Tickets payants','Recette payants (ms)'];
    for (int c = 0; c < gHeaders.length; c++) header(gratuitSheet, 0, c, gHeaders[c]);
    final catMap = <String, Map<String, int>>{};
    final catDisplayNames = <String, String>{};
    for (final t in allTickets) {
      final rawType  = ((t['type_tarif'] ?? '') as String).trim();
      final normType = rawType.isEmpty ? 'inconnu' : rawType.toLowerCase();
      catDisplayNames.putIfAbsent(normType, () => rawType.isEmpty ? 'Inconnu' : rawType);
      final qty  = (t['quantite']     as num? ?? 1).toInt();
      final tot  = (t['montant_total'] as num? ?? 0).toInt();
      catMap[normType] ??= {'total': 0, 'gratuits': 0, 'payants': 0, 'recettePayants': 0};
      catMap[normType]!['total'] = catMap[normType]!['total']! + qty;
      if (tot == 0) {
        catMap[normType]!['gratuits'] = catMap[normType]!['gratuits']! + qty;
      } else {
        catMap[normType]!['payants']        = catMap[normType]!['payants']! + qty;
        catMap[normType]!['recettePayants'] = catMap[normType]!['recettePayants']! + tot;
      }
    }
    final catEntries = catMap.entries.toList()
      ..sort((a, b) => b.value['gratuits']!.compareTo(a.value['gratuits']!));
    int gRow = 1;
    int gTotalTickets = 0, gTotalGratuits = 0, gTotalPayants = 0, gTotalRecette = 0;
    for (final e in catEntries) {
      final bgG      = gRow.isOdd ? '#F0FDF4' : '#FFFFFF';
      final gratuits = e.value['gratuits']!;
      final totalCat = e.value['total']!;
      final pctG     = totalCat > 0
          ? '${((gratuits / totalCat) * 100).toStringAsFixed(1)}%' : '0%';
    cell(gratuitSheet, gRow, 0, catDisplayNames[e.key] ?? e.key, bgHex: bgG, bold: true);
      cell(gratuitSheet, gRow, 1, totalCat,                     bgHex: bgG);
      cell(gratuitSheet, gRow, 2, gratuits,                     bgHex: bgG,
          bold: gratuits > 0, fgHex: gratuits > 0 ? '#16A34A' : '#6B7280');
      cell(gratuitSheet, gRow, 3, pctG,                         bgHex: bgG,
          fgHex: gratuits > 0 ? '#16A34A' : '#6B7280');
      cell(gratuitSheet, gRow, 4, e.value['payants']!,          bgHex: bgG);
      cell(gratuitSheet, gRow, 5, e.value['recettePayants']!,   bgHex: bgG, fgHex: '#0D1B3E');
      gTotalTickets += totalCat;
      gTotalGratuits += gratuits;
      gTotalPayants  += e.value['payants']!;
      gTotalRecette  += e.value['recettePayants']!;
      gRow++;
    }
    final gTotalRow = gRow + 1;
    cell(gratuitSheet, gTotalRow, 0, 'TOTAL',        bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    cell(gratuitSheet, gTotalRow, 1, gTotalTickets,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(gratuitSheet, gTotalRow, 2, gTotalGratuits, bold: true, bgHex: '#1A3260', fgHex: '#4ADE80');
    cell(gratuitSheet, gTotalRow, 3,
        gTotalTickets > 0
            ? '${((gTotalGratuits / gTotalTickets) * 100).toStringAsFixed(1)}%' : '0%',
        bold: true, bgHex: '#1A3260', fgHex: '#4ADE80');
    cell(gratuitSheet, gTotalRow, 4, gTotalPayants,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(gratuitSheet, gTotalRow, 5, gTotalRecette,  bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    for (int c = 0; c < [30.0,16.0,16.0,14.0,16.0,22.0].length; c++) {
      gratuitSheet.setColumnWidth(c, [30.0,16.0,16.0,14.0,16.0,22.0][c]);
    }

    // ── 5. Par segment ──
    // Now includes id_segment as first column
    final segSheet = excel['Par segment'];
    final sHeaders = [
      'id_segment', 'Segment', 'Départ', 'Arrivée',
      'Total tickets', 'Gratuits', 'Payants', 'Recette (ms)',
    ];
    for (int c = 0; c < sHeaders.length; c++) header(segSheet, 0, c, sHeaders[c]);

    final segGroupMap = <int?, List<Map<String, dynamic>>>{};
    for (final t in allTickets) {
      final raw = t['id_segment'];
      final id  = raw == null ? null : int.tryParse(raw.toString());
      final key = (id == null || id == 0) ? null : id;
      segGroupMap[key] ??= [];
      segGroupMap[key]!.add(t);
    }
    final segEntries = segGroupMap.entries.toList()
      ..sort((a, b) {
        if (a.key == null) return 1;
        if (b.key == null) return -1;
        final aOrdre = (segmentMap[a.key]?['ordre'] as int?) ?? 9999;
        final bOrdre = (segmentMap[b.key]?['ordre'] as int?) ?? 9999;
        return aOrdre.compareTo(bOrdre);
      });

    int sRow = 1;
    int sTotalTickets = 0, sTotalGratuits = 0, sTotalRecette = 0;
    for (final e in segEntries) {
      final tickets    = e.value;
      final segRecette = tickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      final segCount   = tickets.fold(0, (s, t) => s + ((t['quantite']      as num? ?? 1).toInt()));
      final segGratis  = tickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final dep  = tickets.isNotEmpty ? tickets.first['point_depart']  ?? '' : '';
      final arr  = tickets.isNotEmpty ? tickets.first['point_arrivee'] ?? '' : '';
      final bg   = sRow.isOdd ? '#F9FAFB' : '#FFFFFF';

      // col 0: raw id_segment
      cell(segSheet, sRow, 0,
          e.key == null ? '—' : e.key,
          bgHex: bg, fgHex: '#6B7280');
      // col 1: human label
      cell(segSheet, sRow, 1,
          e.key == null ? 'Non classé' : segLabel(e.key),
          bgHex: bg, bold: true, fgHex: e.key == null ? '#9CA3AF' : '#0D1B3E');
      cell(segSheet, sRow, 2, dep,       bgHex: bg);
      cell(segSheet, sRow, 3, arr,       bgHex: bg);
      cell(segSheet, sRow, 4, segCount,  bgHex: bg);
      cell(segSheet, sRow, 5, segGratis, bgHex: bg,
          bold: segGratis > 0, fgHex: segGratis > 0 ? '#16A34A' : '#9CA3AF');
      cell(segSheet, sRow, 6, segCount - segGratis, bgHex: bg);
      cell(segSheet, sRow, 7, segRecette, bgHex: bg, bold: true, fgHex: '#0D1B3E');
      sTotalTickets  += segCount;
      sTotalGratuits += segGratis;
      sTotalRecette  += segRecette;
      sRow++;
    }

    // Detail section header
    sRow += 1;
    cell(segSheet, sRow, 0, '— DÉTAIL PAR SEGMENT ET TARIF —', bold: true, fgHex: '#6B7280');
    sRow += 2;
    for (final e in segEntries) {
      // Merge-style header row for this segment
      cell(segSheet, sRow, 0, e.key == null ? '—' : e.key,
          bold: true, bgHex: '#1A3260', fgHex: '#D1D5DB');
      cell(segSheet, sRow, 1, e.key == null ? 'Non classé' : segLabel(e.key),
          bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
      for (int c = 2; c < 8; c++) cell(segSheet, sRow, c, '', bgHex: '#1A3260');
      sRow++;
    final tarifInSeg = <String, Map<String, int>>{};
      for (final t in e.value) {
        final rawType = ((t['type_tarif'] ?? '') as String).trim();
        final qty     = (t['quantite']     as num? ?? 1).toInt();
        final tot     = (t['montant_total'] as num? ?? 0).toInt();
        final unit    = (t['prix_unitaire'] as num? ?? 0).toInt();
        final isFree  = tot == 0;
        final display = isFree
            ? (rawType.isEmpty ? 'Inconnu' : rawType)
            : '${rawType.isEmpty ? 'Inconnu' : rawType} · $unit ms';
        tarifInSeg[display] ??= {'count': 0, 'gratuits': 0, 'recette': 0};
        tarifInSeg[display]!['count']   = tarifInSeg[display]!['count']! + qty;
        if (tot == 0) tarifInSeg[display]!['gratuits'] = tarifInSeg[display]!['gratuits']! + qty;
        tarifInSeg[display]!['recette'] = tarifInSeg[display]!['recette']! + tot;
      }
      for (final te in tarifInSeg.entries) {
        final isFree = te.value['recette']! == 0;
        final bg     = sRow.isOdd ? '#F9FAFB' : '#FFFFFF';
        cell(segSheet, sRow, 0, '',                  bgHex: bg); // id col empty for detail
        cell(segSheet, sRow, 1, '   └ ${te.key}',    bgHex: bg);
        cell(segSheet, sRow, 4, te.value['count']!,  bgHex: bg);
        cell(segSheet, sRow, 5, te.value['gratuits']!, bgHex: bg,
            fgHex: te.value['gratuits']! > 0 ? '#16A34A' : '#9CA3AF');
        cell(segSheet, sRow, 6, te.value['count']! - te.value['gratuits']!, bgHex: bg);
        cell(segSheet, sRow, 7, te.value['recette']!, bgHex: bg,
            fgHex: isFree ? '#16A34A' : '#0D1B3E');
        sRow++;
      }
      sRow++;
    }
    cell(segSheet, sRow, 0, '',              bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    cell(segSheet, sRow, 1, 'TOTAL',         bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    cell(segSheet, sRow, 4, sTotalTickets,   bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(segSheet, sRow, 5, sTotalGratuits,  bold: true, bgHex: '#1A3260', fgHex: '#4ADE80');
    cell(segSheet, sRow, 6, sTotalTickets - sTotalGratuits, bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    cell(segSheet, sRow, 7, sTotalRecette,   bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    // widths: id_seg, label, dep, arr, tickets, gratuits, payants, recette
    for (int c = 0; c < [12.0, 30.0, 22.0, 22.0, 14.0, 14.0, 14.0, 18.0].length; c++) {
      segSheet.setColumnWidth(c, [12.0, 30.0, 22.0, 22.0, 14.0, 14.0, 14.0, 18.0][c]);
    }

    // ── 6. Par voyage ──
    final voyageSheet = excel['Par voyage'];
    final vHeaders = ['Voyage','Type','Trajet','Tickets','Gratuits','Payants','Recette (ms)'];
    for (int c = 0; c < vHeaders.length; c++) header(voyageSheet, 0, c, vHeaders[c]);
    int vRow = 1;
    for (final v in voyages) {
      final id      = (v['id_voyage'] ?? v['id']) as int?;
      final depart  = v['depart']  ?? '?';
      final arrivee = v['arrivee'] ?? '?';
      final typeStr = (v['type'] as String?) ?? 'programmé';
      final vTickets = id == null
          ? <Map<String, dynamic>>[]
          : allTickets.where((t) => t['id_voyage'] == id).toList();
      final vTotal  = vTickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      final vCount  = vTickets.fold(0, (s, t) => s + ((t['quantite']      as num? ?? 1).toInt()));
      final vGratis = vTickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final bg = vRow.isOdd ? '#F9FAFB' : '#FFFFFF';
      cell(voyageSheet, vRow, 0, '#${id ?? '?'}',     bgHex: bg, bold: true);
      cell(voyageSheet, vRow, 1, typeStr,              bgHex: bg);
      cell(voyageSheet, vRow, 2, '$depart → $arrivee', bgHex: bg);
      cell(voyageSheet, vRow, 3, vCount,               bgHex: bg);
      cell(voyageSheet, vRow, 4, vGratis,              bgHex: bg,
          fgHex: vGratis > 0 ? '#16A34A' : '#111827');
      cell(voyageSheet, vRow, 5, vCount - vGratis,     bgHex: bg);
      cell(voyageSheet, vRow, 6, vTotal,               bgHex: bg, bold: true, fgHex: '#0D1B3E');
      vRow++;
      if (vTickets.isNotEmpty) {
        // Sub-header: now includes id_segment and Heure with seconds
        for (final col in [
          [0, 'id_segment'], [1, 'Départ'], [2, 'Arrivée'],
          [3, 'Segment'], [4, 'Tarif'], [5, 'Heure'], [6, 'Qté'], [7, 'Gratuits'], [8, 'Total (ms)'],
        ]) {
          cell(voyageSheet, vRow, col[0] as int, col[1],
              bold: true, bgHex: '#E8EDF5', fgHex: '#374151');
        }
        vRow++;
        for (final t in vTickets) {
          final isFree   = ((t['montant_total'] as num? ?? 0).toInt()) == 0;
          final tQty     = (t['quantite'] as num? ?? 1).toInt();
          final tGrat    = isFree ? tQty : 0;
          final tbg      = vRow.isOdd ? '#F9FAFB' : '#FFFFFF';
          final tDt      = DateTime.tryParse(t['date_heure'] ?? '');
          final rawSegId = t['id_segment'];
          final tSegId   = segIdInt(rawSegId);

          final tSegOrdre = tSegId != null ? (segmentMap[tSegId]?['ordre']?.toString()) : null;
          final tSegDisplay = tSegOrdre != null ? 'Seg. $tSegOrdre' : (tSegId != null ? '$tSegId' : '—');
          cell(voyageSheet, vRow, 0, tSegDisplay, bgHex: tbg, fgHex: '#6B7280');
          cell(voyageSheet, vRow, 1, '   ${t['point_depart'] ?? ''}', bgHex: tbg);
          cell(voyageSheet, vRow, 2, t['point_arrivee'] ?? '',         bgHex: tbg);
          cell(voyageSheet, vRow, 3, segLabel(rawSegId),               bgHex: tbg);
          cell(voyageSheet, vRow, 4, t['type_tarif'] ?? '',            bgHex: tbg);
          // ── Time with seconds ──
          cell(voyageSheet, vRow, 5, tDt != null ? _formatTime(tDt) : '', bgHex: tbg);
          cell(voyageSheet, vRow, 6, tQty,                              bgHex: tbg);
          cell(voyageSheet, vRow, 7, tGrat, bgHex: tbg,
              fgHex: tGrat > 0 ? '#16A34A' : '#9CA3AF');
          cell(voyageSheet, vRow, 8, (t['montant_total'] as num? ?? 0).toInt(),
              bgHex: tbg, bold: isFree, fgHex: isFree ? '#16A34A' : '#0D1B3E');
          vRow++;
        }
        vRow++;
      }
    }
    // widths: voyage, type, trajet, tickets, gratuits, payants, recette + sub-cols
    for (int c = 0; c < [12.0, 16.0, 32.0, 12.0, 28.0, 12.0, 28.0, 12.0, 16.0].length; c++) {
      voyageSheet.setColumnWidth(c, [12.0, 16.0, 32.0, 12.0, 28.0, 12.0, 28.0, 12.0, 16.0][c]);
    }

    final bytes    = excel.encode()!;
    final fileName = 'rapport_${label}_${_matricule}_$dateStr.xlsx';
    final file     = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ─────────────────────────────────────────────────────────────
  // Build PDF
  // ─────────────────────────────────────────────────────────────
  Future<File> _buildPdf({
    required List<Map<String, dynamic>> allTickets,
    required List<dynamic> voyages,
    required Map<int, Map<String, dynamic>> segmentMap,
    required String agentName,
    required String dateStr,
    required int totalRecette,
    required int totalTickets,
    required int totalGratuits,
    required Directory dir,
  }) async {

    // ── Local helper: id → readable label ──
  String segLabel(dynamic rawId) {
      if (rawId == null) return '—';
      final str = rawId.toString().trim();
      if (str.isEmpty || str == '0' || str == 'null') return '—';
      final id = int.tryParse(str);
      if (id == null) return '—';
      final seg = segmentMap[id];
      if (seg == null) return 'Seg. #$id';
      return 'Seg. ${seg['ordre'] ?? '?'}';
    }

    // ── Local helper: raw id → display string ──
   String segIdStr(dynamic rawId) {
  if (rawId == null) return '—';
  final str = rawId.toString().trim();
  if (str.isEmpty || str == '0' || str == 'null') return '—';
  return str;
}

    final pdf     = pw.Document();
    final payants = totalTickets - totalGratuits;
    final prixMoyen = payants > 0
        ? (allTickets
                .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) > 0)
                .fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt())) /
            payants)
            .round()
        : 0;

    final catMap = <String, Map<String, int>>{};
    for (final t in allTickets) {
      final type = ((t['type_tarif'] ?? '') as String).trim().isEmpty
          ? 'Inconnu' : (t['type_tarif'] as String).trim();
      final qty = (t['quantite']     as num? ?? 1).toInt();
      final tot = (t['montant_total'] as num? ?? 0).toInt();
      catMap[type] ??= {'total': 0, 'gratuits': 0};
      catMap[type]!['total'] = catMap[type]!['total']! + qty;
      if (tot == 0) catMap[type]!['gratuits'] = catMap[type]!['gratuits']! + qty;
    }
    final catEntries = catMap.entries.toList()
      ..sort((a, b) => b.value['gratuits']!.compareTo(a.value['gratuits']!));

    final segGroupMap = <int?, List<Map<String, dynamic>>>{};
    for (final t in allTickets) {
      final raw = t['id_segment'];
      final id  = raw == null ? null : int.tryParse(raw.toString());
      final key = (id == null || id == 0) ? null : id;
      segGroupMap[key] ??= [];
      segGroupMap[key]!.add(t);
    }
    final segEntries = segGroupMap.entries.toList()
      ..sort((a, b) {
        if (a.key == null) return 1;
        if (b.key == null) return -1;
        final aOrdre = (segmentMap[a.key]?['ordre'] as int?) ?? 9999;
        final bOrdre = (segmentMap[b.key]?['ordre'] as int?) ?? 9999;
        return aOrdre.compareTo(bOrdre);
      });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0D1B3E'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RAPPORT DE JOURNÉE — $_todayLabel',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Agent : $agentName   |   Généré le $dateStr',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xB3FFFFFF), fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('INDICATEURS CLÉS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
            children: [
              _pdfTableRow(['Recette totale', '$totalRecette ms',
                  '≈ ${(totalRecette / 1000).toStringAsFixed(3)} DT'], highlight: true),
              _pdfTableRow(['Total tickets', '$totalTickets',
                  '$payants payants + $totalGratuits gratuits']),
              _pdfTableRow(['Prix moyen (payants)', '$prixMoyen ms', ''], highlight: true),
              _pdfTableRow(['Taux de gratuité',
                  totalTickets > 0
                      ? '${((totalGratuits / totalTickets) * 100).toStringAsFixed(1)}%' : '0%', '']),
              _pdfTableRow(['Voyages programmés', '${voyagesProgrammes.length}', ''], highlight: true),
              _pdfTableRow(['Voyages non programmés', '${voyagesNonProgrammes.length}', '']),
              _pdfTableRow(['Total voyages', '${voyages.length}', ''], highlight: true),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('RÉPARTITION PAR TARIF',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfTarifTable(allTickets, totalTickets),
          pw.SizedBox(height: 24),
          pw.Text('GRATUITS PAR CATÉGORIE',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfGratuitsTable(catEntries, totalGratuits),
          pw.SizedBox(height: 24),
          pw.Text('TICKETS PAR SEGMENT',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfSegmentTable(segEntries, segmentMap, totalTickets),
          pw.SizedBox(height: 24),
          pw.Text('VENTES PAR VOYAGE',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfVoyagesTable(allTickets, voyages, segLabel),
          pw.SizedBox(height: 24),
          pw.Text('DÉTAIL DES TICKETS',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfTicketsTable(allTickets, segLabel, segIdStr),
        ],
      ),
    );

    final fileName = 'rapport_journee_${_matricule}_$dateStr.pdf';
    final file     = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.TableRow _pdfTableRow(List<String> cells,
      {bool isHeader = false, bool highlight = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader
            ? PdfColor.fromHex('1A3260')
            : highlight
                ? PdfColor.fromHex('F2F5FB')
                : PdfColors.white,
      ),
      children: cells.map((c) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(c,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? pw.FontWeight.bold : null,
              color: isHeader ? PdfColors.white : PdfColor.fromHex('111827'),
            )),
      )).toList(),
    );
  }

  pw.Widget _buildPdfTarifTable(
      List<Map<String, dynamic>> tickets, int totalTickets) {
 final tarifMap = <String, Map<String, int>>{};
    final tarifDisplayNames = <String, String>{};
    for (final t in tickets) {
      final rawType  = ((t['type_tarif'] ?? '') as String).trim();
      final qty      = (t['quantite']     as num? ?? 1).toInt();
      final tot      = (t['montant_total'] as num? ?? 0).toInt();
      final unit     = (t['prix_unitaire'] as num? ?? 0).toInt();
      final isFree   = tot == 0;
      final normType = rawType.isEmpty ? 'inconnu' : rawType.toLowerCase();
      final groupKey = isFree ? normType : '${normType}_$unit';
      tarifDisplayNames.putIfAbsent(groupKey, () => isFree
          ? (rawType.isEmpty ? 'Inconnu' : rawType)
          : '${rawType.isEmpty ? 'Inconnu' : rawType} · $unit ms');
      tarifMap[groupKey] ??= {'count': 0, 'total': 0};
      tarifMap[groupKey]!['count'] = tarifMap[groupKey]!['count']! + qty;
      tarifMap[groupKey]!['total'] = tarifMap[groupKey]!['total']! + tot;
    }
    final entries = tarifMap.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      children: [
        _pdfTableRow(['Type de tarif', 'Qté', 'Total (ms)', '% voyageurs'], isHeader: true),
       ...entries.map((e) {
          final pct = totalTickets > 0
              ? '${((e.value['count']! / totalTickets) * 100).toStringAsFixed(1)}%' : '0%';
          final display = tarifDisplayNames[e.key] ?? e.key;
          return _pdfTableRow(
              [display, '${e.value['count']}', '${e.value['total']}', pct],
              highlight: entries.indexOf(e).isEven);
        }),
        _pdfTableRow([
          'TOTAL', '$totalTickets',
          '${tickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()))}',
          '100%',
        ], isHeader: true),
      ],
    );
  }

  pw.Widget _buildPdfGratuitsTable(
      List<MapEntry<String, Map<String, int>>> catEntries, int totalGratuits) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      children: [
        _pdfTableRow(['Catégorie', 'Total tickets', 'Gratuits', '% gratuits'], isHeader: true),
        ...catEntries.map((e) {
          final gratuits = e.value['gratuits']!;
          final total    = e.value['total']!;
          final pct      = total > 0
              ? '${((gratuits / total) * 100).toStringAsFixed(1)}%' : '0%';
          return _pdfTableRow(
              [e.key, '$total', '$gratuits', pct],
              highlight: catEntries.indexOf(e).isEven);
        }),
        _pdfTableRow([
          'TOTAL',
          '${catEntries.fold(0, (s, e) => s + e.value['total']!)}',
          '$totalGratuits',
          catEntries.fold(0, (s, e) => s + e.value['total']!) > 0
              ? '${((totalGratuits / catEntries.fold(0, (s, e) => s + e.value['total']!)) * 100).toStringAsFixed(1)}%'
              : '0%',
        ], isHeader: true),
      ],
    );
  }

  // ── NOW includes id_segment column ──
  pw.Widget _buildPdfSegmentTable(
    List<MapEntry<int?, List<Map<String, dynamic>>>> segEntries,
    Map<int, Map<String, dynamic>> segmentMap,
    int totalTickets,
  ) {
   String segLabel(int? id) {
      if (id == null) return 'Non classé';
      final seg = segmentMap[id];
      if (seg == null) return 'Seg. #$id';
      return 'Seg. ${seg['ordre'] ?? '?'}';
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      children: [
        _pdfTableRow(
          ['id_segment', 'Segment', 'Tickets', 'Gratuits', 'Payants', 'Recette (ms)'],
          isHeader: true,
        ),
        ...segEntries.map((e) {
          final count    = e.value.fold(0, (s, t) => s + ((t['quantite']      as num? ?? 1).toInt()));
          final gratuits = e.value
              .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
              .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
          final recette  = e.value.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
          return _pdfTableRow(
            [
              e.key == null ? '—' : '${e.key}',   // ← raw id_segment
              segLabel(e.key),                      // ← human label
              '$count', '$gratuits', '${count - gratuits}', '$recette',
            ],
            highlight: segEntries.indexOf(e).isEven,
          );
        }),
      ],
    );
  }

  pw.Widget _buildPdfVoyagesTable(
    List<Map<String, dynamic>> allTickets,
    List<dynamic> voyages,
    String Function(dynamic) segLabel,
  ) {
    final rows = <pw.TableRow>[
      _pdfTableRow(['Voyage', 'Trajet', 'Tickets', 'Gratuits', 'Recette (ms)'], isHeader: true),
    ];
    for (int i = 0; i < voyages.length; i++) {
      final v       = voyages[i];
      final id      = (v['id_voyage'] ?? v['id']) as int?;
      final depart  = v['depart']  ?? '?';
      final arrivee = v['arrivee'] ?? '?';
      final vTickets = id == null
          ? <Map<String, dynamic>>[]
          : allTickets.where((t) => t['id_voyage'] == id).toList();
      final vCount  = vTickets.fold(0, (s, t) => s + ((t['quantite']      as num? ?? 1).toInt()));
      final vGratis = vTickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final vRecette = vTickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      rows.add(_pdfTableRow(
          ['#${id ?? '?'}', '$depart → $arrivee', '$vCount', '$vGratis', '$vRecette'],
          highlight: i.isEven));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      children: rows,
    );
  }

  // ── NOW includes id_segment column and HH:mm:ss time ──
  pw.Widget _buildPdfTicketsTable(
    List<Map<String, dynamic>> tickets,
    String Function(dynamic) segLabel,
    String Function(dynamic) segIdStr,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),   // #
        1: pw.FixedColumnWidth(30),   // id_segment  ← NEW
        2: pw.FixedColumnWidth(55),   // Heure (HH:mm:ss needs more space)
        3: pw.FlexColumnWidth(2),     // Départ
        4: pw.FlexColumnWidth(2),     // Arrivée
        5: pw.FlexColumnWidth(2.5),   // Segment label
        6: pw.FlexColumnWidth(1.5),   // Tarif
        7: pw.FixedColumnWidth(28),   // Qté
        8: pw.FixedColumnWidth(46),   // Total
      },
      children: [
        _pdfTableRow(
          ['#', 'Seg.ID', 'Heure', 'Départ', 'Arrivée', 'Segment', 'Tarif', 'Qté', 'Total (ms)'],
          isHeader: true,
        ),
        ...tickets.asMap().entries.map((entry) {
          final i  = entry.key;
          final t  = entry.value;
          final dt = DateTime.tryParse(t['date_heure'] ?? '');
          // ── Time now shows HH:mm:ss ──
          final timeStr = dt != null ? _formatTime(dt) : '—';
          return _pdfTableRow([
            '${i + 1}',
            segIdStr(t['id_segment']),         // ← raw id
            timeStr,                            // ← HH:mm:ss
            t['point_depart']  ?? '',
            t['point_arrivee'] ?? '',
            segLabel(t['id_segment']),          // ← human label
            t['type_tarif']    ?? '',
            '${(t['quantite'] as num? ?? 1).toInt()}',
            '${(t['montant_total'] as num? ?? 0).toInt()}',
          ], highlight: i.isEven);
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Send email
  // ─────────────────────────────────────────────────────────────
  Future<void> _sendEmail({
    required File file,
    required String format,
    required String agentName,
    required String dateStr,
    required int totalRecette,
    required int totalTickets,
    required int voyageCount,
  }) async {
    final smtpServer = SmtpServer(_kSmtpHost,
        port: _kSmtpPort, username: _kSmtpUser, password: _kSmtpPassword);
    final message = Message()
      ..from = Address(_kSmtpUser, 'SRTB Billetterie')
      ..recipients.add(_kReportRecipient)
      ..subject = 'Rapport journée $dateStr — Agent $agentName — $totalRecette ms'
      ..text = '''
Rapport de journée du $_todayLabel
Agent     : $agentName
Matricule : $_matricule

Récapitulatif :
  • Recette totale            : $totalRecette ms (≈ ${(totalRecette / 1000).toStringAsFixed(3)} DT)
  • Total tickets             : $totalTickets
  • Voyages programmés        : ${voyagesProgrammes.length}
  • Voyages non programmés    : ${voyagesNonProgrammes.length}
  • Total voyages clôturés    : $voyageCount

Fichier joint : ${file.path.split('/').last}
'''.trim()
      ..attachments = [FileAttachment(file)..location = Location.attachment];
    // ignore: deprecated_member_use
    await send(message, smtpServer);
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  String _getTime(String? dh) =>
      (dh != null && dh.split(' ').length > 1) ? dh.split(' ')[1].substring(0, 5) : '';

  void _openVoyage(Map<String, dynamic> voyage) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VenteTicketsPage(voyage: voyage)),
    ).then((_) { _fetchProgrammes(); _fetchNonProgrammes(); });
  }

  void _showLockedSnack() {
    final t = AppLocalizations.of(context)!;
    _showToast(t.terminerVoyageEnCoursToast, isWarning: true);
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: Column(
          children: [
            _buildSharedActionBar(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProgrammesTab(),
                  _buildNonProgrammesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Shared Action Bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildSharedActionBar() {
    if (isLoadingProgrammes || isLoadingNonProgrammes) return const SizedBox.shrink();
    if (voyagesProgrammes.isEmpty && voyagesNonProgrammes.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: _clotureConfirming
            ? _buildClotureConfirmCard()
            : _allClotures
                ? _buildPostClotureActions()
                : _buildClotureJourneeBtn(),
      ),
    );
  }

  Widget _buildClotureConfirmCard() {
    final t = AppLocalizations.of(context)!;
    final allToClose = [
      ...voyagesProgrammes.where((v) => v['statut'] != 'cloture'),
      ...voyagesNonProgrammes.where((v) => v['statut'] != 'cloture'),
    ];
    return Container(
      key: const ValueKey('cj_confirm'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyMid.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade300, size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(t.cloturerJourneeQuestion,
                    overflow: TextOverflow.ellipsis, maxLines: 2,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade300)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(t.voyagesConfirmBody(allToClose.length, _todayLabel),
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _clotureLoading
                        ? null
                        : () => setState(() => _clotureConfirming = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(t.annuler,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _clotureLoading ? null : _clotureJourneeAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.red.shade900,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _clotureLoading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(t.confirmer,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClotureJourneeBtn() {
    final t = AppLocalizations.of(context)!;
    return SizedBox(
      key: const ValueKey('cj_btn'),
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _clotureLoading ? null : () => setState(() => _clotureConfirming = true),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1212), Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: const Color(0xFF9B1C1C).withOpacity(0.45),
                    blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_clotureLoading)
                  const SizedBox(width: 17, height: 17,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                else
                  const Icon(Icons.event_busy_rounded, color: Colors.white, size: 19),
                const SizedBox(width: 9),
                Text(
                  _clotureLoading ? t.cloturureEnCours : t.cloturerJournee,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      letterSpacing: 0.3, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostClotureActions() {
    final t = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('post_cloture'),
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _exportLoading ? null : _showExportDialog,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB45309), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFD97706).withOpacity(0.4),
                        blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_exportLoading)
                      const SizedBox(width: 17, height: 17,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                    const SizedBox(width: 9),
                    Text(
                      _exportLoading ? t.envoiEnCours : t.exporterRapport,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          letterSpacing: 0.3, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _reopenLoading ? null : _reopenJourneeAll,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_reopenLoading)
                      const SizedBox(width: 15, height: 15,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.lock_open_outlined, color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      _reopenLoading ? t.reouvertureEnCours : t.reouvrirJournee,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final t     = AppLocalizations.of(context)!;
    final agent = widget.agent;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navyDark, AppTheme.navyMid, AppTheme.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        children: [
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
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 17),
                ),
              ),
              const Spacer(),
              const LanguageSwitcher(),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 72, height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Image.asset('assets/images/logo_srtb.png', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.directions_bus, size: 44, color: AppTheme.navyMid)),
          ),
          const SizedBox(height: 10),
          const Text('S R T B',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold, letterSpacing: 7)),
          const SizedBox(height: 3),
          Text(t.mesVoyages,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 6,
            children: [
              _headerPill(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppTheme.goldLight, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('${agent['prenom']} ${agent['nom']}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              )),
              _headerPill(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppTheme.goldLight, size: 12),
                  const SizedBox(width: 6),
                  Text(_todayLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerPill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: AppTheme.navyDark,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.goldLight,
        indicatorWeight: 3,
        labelColor: AppTheme.goldLight,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: [
          Tab(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 14),
              const SizedBox(width: 5),
              Flexible(child: Text(t.programmes, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              _tabBadge(voyagesProgrammes.length, isLoadingProgrammes),
            ],
          )),
          Tab(child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus_outlined, size: 14),
              const SizedBox(width: 5),
              Flexible(child: Text(t.nonProgrammes, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              _tabBadge(voyagesNonProgrammes.length, isLoadingNonProgrammes),
            ],
          )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 1 — Programmés
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgrammesTab() {
    final t = AppLocalizations.of(context)!;
    if (isLoadingProgrammes)
      return const Center(child: CircularProgressIndicator(color: AppTheme.navyMid));
    if (errorProgrammes != null)
      return _buildError(errorProgrammes!, _fetchProgrammes);

    final activeIdx = _activeIndex;
    return Column(
      children: [
        if (voyagesProgrammes.isNotEmpty)
          _buildStatsBar([
            _statTile(Icons.directions_bus_outlined, t.total,    '${voyagesProgrammes.length}', AppTheme.navyMid),
            _statTile(Icons.check_circle_outline,    t.clotures, '${voyagesProgrammes.where((v) => v['statut'] == 'cloture').length}', Colors.grey),
            _statTile(Icons.play_circle_outline,     t.enCours,  activeIdx >= 0 ? '1' : '0', const Color(0xFF16A34A)),
          ]),
        Expanded(
          child: voyagesProgrammes.isEmpty
              ? _buildEmpty(t.aucunVoyageProgramme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: voyagesProgrammes.length,
                  itemBuilder: (_, i) {
                    final v        = voyagesProgrammes[i] as Map<String, dynamic>;
                    final isCloture = v['statut'] == 'cloture';
                    final isActive  = i == activeIdx;
                    final isLocked  = !isCloture && !isActive;

                    final Color accent, bgColor, borderColor;
                    if (isCloture) {
                      accent = Colors.grey; bgColor = Colors.grey.shade50; borderColor = Colors.grey.shade200;
                    } else if (isActive) {
                      accent = AppTheme.navyMid; bgColor = const Color(0xFFEBF0FF); borderColor = AppTheme.navyLight;
                    } else {
                      accent = Colors.orange.shade700; bgColor = Colors.orange.shade50; borderColor = Colors.orange.shade200;
                    }

                    return _buildVoyageCard(
                      voyage: v, accent: accent, bgColor: bgColor, borderColor: borderColor,
                      isActive: isActive, isCloture: isCloture, isLocked: isLocked,
                      onTap: isCloture ? () => _reopenVoyage(v) : isLocked ? _showLockedSnack : () => _openVoyage(v),
                      extraLabel: isCloture ? t.appuyerReouvrirLabel : isLocked ? t.enAttenteVoyagePrecedent : null,
                      extraLabelColor: isCloture ? Colors.grey.shade400 : Colors.orange.shade600,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 2 — Non programmés
  // ─────────────────────────────────────────────────────────────
  Widget _buildNonProgrammesTab() {
    final t = AppLocalizations.of(context)!;
    if (isLoadingNonProgrammes)
      return const Center(child: CircularProgressIndicator(color: AppTheme.navyMid));
    if (errorNonProgrammes != null)
      return _buildError(errorNonProgrammes!, _fetchNonProgrammes);

    return Column(
      children: [
        if (voyagesNonProgrammes.isNotEmpty)
          _buildStatsBar([
            _statTile(Icons.directions_bus_outlined, t.total,    '${voyagesNonProgrammes.length}', AppTheme.navyMid),
            _statTile(Icons.check_circle_outline,    t.clotures, '${voyagesNonProgrammes.where((v) => v['statut'] == 'cloture').length}', Colors.grey),
            _statTile(Icons.play_circle_outline,     t.actifs,   '${voyagesNonProgrammes.where((v) => v['statut'] != 'cloture').length}', const Color(0xFF16A34A)),
          ]),
        Expanded(
          child: voyagesNonProgrammes.isEmpty
              ? _buildEmpty(t.aucunVoyageNonProgramme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: voyagesNonProgrammes.length,
                  itemBuilder: (_, i) {
                    final v        = voyagesNonProgrammes[i] as Map<String, dynamic>;
                    final isCloture = v['statut'] == 'cloture';

                    final Color accent, bgColor, borderColor;
                    if (isCloture) {
                      accent = Colors.grey; bgColor = Colors.grey.shade50; borderColor = Colors.grey.shade200;
                    } else {
                      accent = const Color(0xFF0E7C5B); bgColor = const Color(0xFFE8F5F0); borderColor = const Color(0xFF6ECBAD);
                    }

                    final typeLabel = ((v['type'] as String?) ?? '').isNotEmpty
                        ? v['type'] as String : 'Spontané';

                    return _buildVoyageCard(
                      voyage: v, accent: accent, bgColor: bgColor, borderColor: borderColor,
                      isActive: !isCloture, isCloture: isCloture, isLocked: false,
                      onTap: isCloture ? () => _reopenVoyage(v) : () => _openVoyage(v),
                      extraLabel: isCloture ? t.appuyerReouvrirLabel : typeLabel,
                      extraLabelColor: isCloture ? Colors.grey.shade400 : accent,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Voyage card
  // ─────────────────────────────────────────────────────────────
  Widget _buildVoyageCard({
    required Map<String, dynamic> voyage,
    required Color accent,
    required Color bgColor,
    required Color borderColor,
    required bool isActive,
    required bool isCloture,
    required bool isLocked,
    required VoidCallback onTap,
    String? extraLabel,
    Color? extraLabelColor,
  }) {
    final t         = AppLocalizations.of(context)!;
    final timeLabel = _getTime(voyage['date_heure'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(isCloture ? 0.04 : 0.08),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.directions_bus, color: accent, size: 24),
                  ),
                  if (isCloture)
                    Positioned(right: -4, bottom: -4, child: _statusDot(Colors.grey, Icons.history, 10))
                  else if (isLocked)
                    Positioned(right: -4, bottom: -4, child: _statusDot(Colors.orange.shade700, Icons.lock, 10))
                  else if (isActive)
                    Positioned(right: -4, bottom: -4, child: _statusDot(const Color(0xFF16A34A), Icons.play_arrow, 11)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: (isActive && !isLocked && !isCloture)
                                  ? AppTheme.goldLight : accent.withOpacity(0.6),
                              shape: BoxShape.circle,
                            )),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${voyage['depart']} → ${voyage['arrivee']}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14,
                                  color: isCloture ? Colors.grey.shade400 : AppTheme.navyDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            timeLabel.isNotEmpty ? '$timeLabel  ·  $_todayLabel' : _todayLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (extraLabel != null && extraLabel.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(extraLabel, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: extraLabelColor ?? accent,
                              fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      isCloture ? t.statutCloture : isLocked ? t.statutEnAttente : t.statutActif,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    isCloture ? Icons.lock_open_outlined : isLocked ? Icons.lock_outline : Icons.chevron_right,
                    color: accent.withOpacity(0.5), size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Micro-widgets
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsBar(List<Widget> tiles) {
    final separated = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      separated.add(tiles[i]);
      if (i < tiles.length - 1)
        separated.add(Container(width: 1, height: 36, color: Colors.grey.shade100));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.navyMid.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: separated),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, IconData icon, double iconSize) {
    return Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: AppTheme.cardWhite, width: 1.5)),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _tabBadge(int count, bool loading) {
    if (loading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildError(String message, VoidCallback retry) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.orange.shade200),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, height: 1.6)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(t.reessayer),
              style: TextButton.styleFrom(foregroundColor: AppTheme.navyMid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Export format chooser — bottom sheet
// ─────────────────────────────────────────────────────────────
class _ExportFormatSheet extends StatelessWidget {
  final String todayLabel;
  const _ExportFormatSheet({required this.todayLabel});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppTheme.navyMid.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.send_rounded, color: AppTheme.navyMid, size: 28)),
          const SizedBox(height: 14),
          Text(t.envoyerRapport,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text(t.envoyerRapportBody(todayLabel), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 6),
          const Text(_kReportRecipient,
              style: TextStyle(fontSize: 12, color: AppTheme.navyMid, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'excel'),
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text('Excel\n.xlsx', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyMid, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'pdf'),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text('PDF\n.pdf', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.annuler,
                style: TextStyle(color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Réouvrir Journée — confirmation bottom sheet
// ─────────────────────────────────────────────────────────────
class _ReopenJourneeConfirmSheet extends StatelessWidget {
  final int count;
  final String todayLabel;
  const _ReopenJourneeConfirmSheet({required this.count, required this.todayLabel});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppTheme.navyMid.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.lock_open_outlined, color: AppTheme.navyMid, size: 28)),
          const SizedBox(height: 14),
          Text(t.reouvrirJourneeQuestion,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text(t.reouvrirJourneeBody(count, todayLabel), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 8),
          Text(t.actionReversible, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SizedBox(height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(t.annuler,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyMid,
                        foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(t.reouvrirTout,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reopen single voyage — confirmation bottom sheet
// ─────────────────────────────────────────────────────────────
class _ReopenConfirmSheet extends StatelessWidget {
  final Map<String, dynamic> voyage;
  const _ReopenConfirmSheet({required this.voyage});

  @override
  Widget build(BuildContext context) {
    final t      = AppLocalizations.of(context)!;
    final depart  = voyage['depart']  ?? '';
    final arrivee = voyage['arrivee'] ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppTheme.navyMid.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.lock_open_outlined, color: AppTheme.navyMid, size: 28)),
          const SizedBox(height: 14),
          Text(t.reouvrirCeVoyage,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text('$depart → $arrivee', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(t.reouvrirVoyageBody, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SizedBox(height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(t.annuler,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyMid,
                        foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(t.rouvrir,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Toast widget
// ─────────────────────────────────────────────────────────────
class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color  color;
  final IconData icon;
  const _ToastWidget({required this.msg, required this.color, required this.icon});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2400), () { if (mounted) _ctrl.reverse(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.25),
                      blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Flexible(child: Text(widget.msg,
                      style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600, height: 1.3))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}