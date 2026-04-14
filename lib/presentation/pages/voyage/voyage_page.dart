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
import '../../../data/database/daos/voyage_dao.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../ticketing/vente_tickets.dart';

// ─────────────────────────────────────────────────────────────
// ⚠️  CONFIGURE THIS before shipping
// ─────────────────────────────────────────────────────────────
const String _kReportRecipient = 'dkhilmaram12@gmail.com';
const String _kSmtpHost       = 'smtp.gmail.com';
const int    _kSmtpPort       = 587;
const String _kSmtpUser       = 'dkhilmaram0@gmail.com';
const String _kSmtpPassword   = 'ppax xarr sfwc wejn';
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
  bool _clotureConfirming  = false;
  bool _clotureLoading     = false;
  bool _reopenLoading      = false;
  bool _exportLoading      = false;

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

  void _showToast(String msg,
      {bool isError = false, bool isWarning = false, bool isOffline = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final Color color;
    final IconData icon;

    if (isOffline) {
      color = const Color(0xFF8B1A1A);
      icon  = Icons.wifi_off_rounded;
    } else if (isError) {
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

  /// True only when EVERY voyage across both lists is clôturé.
  bool get _allClotures {
    final hasProg    = voyagesProgrammes.isNotEmpty;
    final hasNonProg = voyagesNonProgrammes.isNotEmpty;
    if (!hasProg && !hasNonProg) return false;
    final progDone    = !hasProg    || voyagesProgrammes.every((v) => v['statut'] == 'cloture');
    final nonProgDone = !hasNonProg || voyagesNonProgrammes.every((v) => v['statut'] == 'cloture');
    return progDone && nonProgDone;
  }

  /// True when there is at least one open voyage in either list.
  bool get _hasAnyOpen =>
      voyagesProgrammes.any((v) => v['statut'] != 'cloture') ||
      voyagesNonProgrammes.any((v) => v['statut'] != 'cloture');

  /// True when there is at least one clôturé voyage in either list.
  bool get _hasAnyCloture =>
      voyagesProgrammes.any((v) => v['statut'] == 'cloture') ||
      voyagesNonProgrammes.any((v) => v['statut'] == 'cloture');

  // ─────────────────────────────────────────────────────────────
  // Merge local offline statuts
  // ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> _mergeLocalStatuts(List<dynamic> voyages) async {
    final pendingClotures = await VoyageDao.getPendingClotures();
    final pendingIds =
        pendingClotures.map((r) => r['id_vente'] as int).toSet();

    final merged = <dynamic>[];
    for (final v in voyages) {
      final voyage  = Map<String, dynamic>.from(v as Map);
      final idVente = (voyage['id_vente'] ?? voyage['id']) as int?;

      if (idVente != null) {
        if (pendingIds.contains(idVente)) {
          voyage['statut'] = 'cloture';
        } else {
          final localStatut = await VoyageDao.getVoyageStatut(idVente);
          if (localStatut == 'cloture' || localStatut == 'cloture_pending') {
            voyage['statut'] = 'cloture';
          }
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
    setState(() {
      isLoadingProgrammes = true;
      errorProgrammes     = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
                'http://192.168.1.16:8000/billetterie/ventes/programmees/$_matricule'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body)['voyages'] as List<dynamic>;
        await VoyageDao.saveVoyages(_matricule, list);
        setState(() {
          voyagesProgrammes   = list;
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
      setState(() {
        errorProgrammes =
            'Hors-ligne — aucune donnée en cache.\n'
            'Connectez-vous une première fois pour activer le mode hors-ligne.';
        isLoadingProgrammes = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch — Non programmés
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchNonProgrammes() async {
    setState(() {
      isLoadingNonProgrammes = true;
      errorNonProgrammes     = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
                'http://192.168.1.16:8000/billetterie/ventes/agent/$_matricule'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final all  = jsonDecode(response.body)['voyages'] as List<dynamic>;
        final list = all
            .where((v) => v['type'] != 'programmé')
            .map((v) {
              final voyage = Map<String, dynamic>.from(v as Map);
              voyage['matricule_agent'] ??= _matricule;
              voyage['id_appareil']     ??= widget.agent['id_appareil'];
              voyage['id_billet']       ??= widget.agent['id_billet'];
              voyage['code_agence']     ??= widget.agent['code_agence'];
              voyage['statut']          ??= 'actif';
              return voyage;
            })
            .toList();

        await VoyageDao.saveVoyages(_matriculeNonProg, list);
        setState(() {
          voyagesNonProgrammes   = list;
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
      setState(() {
        errorNonProgrammes =
            'Hors-ligne — aucune donnée en cache.\n'
            'Connectez-vous une première fois pour activer le mode hors-ligne.';
        isLoadingNonProgrammes = false;
      });
    }
  }

  void _maybeShowOfflineToast() {
    if (_toastEntry == null) {
      _showToast('Mode hors-ligne · données en cache', isOffline: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Clôture Journée — BOTH tabs together
  // ─────────────────────────────────────────────────────────────

  Future<void> _clotureJourneeAll() async {
    setState(() {
      _clotureLoading    = true;
      _clotureConfirming = false;
    });

    final toCloseProg = voyagesProgrammes
        .where((v) => v['statut'] != 'cloture')
        .toList();
    final toCloseNonProg = voyagesNonProgrammes
        .where((v) => v['statut'] != 'cloture')
        .toList();
    final allToClose = [...toCloseProg, ...toCloseNonProg];

    if (allToClose.isEmpty) {
      setState(() => _clotureLoading = false);
      _showToast('Tous les voyages sont déjà clôturés');
      return;
    }

    final ids = allToClose
        .map((v) => (v['id_vente'] ?? v['id']) as int?)
        .whereType<int>()
        .toList();

    bool success  = false;
    bool offline  = false;
    int  closedQt = 0;

    try {
      final response = await http
          .put(
            Uri.parse(
                'http://192.168.1.16:8000/billetterie/ventes/cloturer-journee'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        success  = data['success'] == true;
        closedQt = (data['closed'] as int?) ?? ids.length;
      }
    } catch (_) {
      offline = true;
      for (final id in ids) {
        await VoyageDao.saveCloturePending(id);
        await VoyageDao.saveVoyageStatut(id, 'cloture');
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
        offline
            ? 'Journée clôturée (hors-ligne) · $closedQt voyage(s)'
            : 'Journée clôturée · $closedQt voyage(s)',
        isWarning: offline,
      );
      if (!offline) {
        await _fetchProgrammes();
        await _fetchNonProgrammes();
      }
    } else {
      setState(() => _clotureLoading = false);
      _showToast('Échec de la clôture journée', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Réouvrir Journée — BOTH tabs together
  // ─────────────────────────────────────────────────────────────

  Future<void> _reopenJourneeAll() async {
    final allClotures = [
      ...voyagesProgrammes.where((v) => v['statut'] == 'cloture'),
      ...voyagesNonProgrammes.where((v) => v['statut'] == 'cloture'),
    ];

    if (allClotures.isEmpty) {
      _showToast('Aucun voyage clôturé à réouvrir');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReopenJourneeConfirmSheet(
          count: allClotures.length, todayLabel: _todayLabel),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _reopenLoading = true);
    _showToast('Réouverture en cours…');

    final ids = allClotures
        .map((v) => (v['id_vente'] ?? v['id']) as int?)
        .whereType<int>()
        .toList();

    bool success = false;
    bool offline = false;

    try {
      final response = await http
          .put(
            Uri.parse(
                'http://192.168.1.16:8000/billetterie/ventes/reopen-journee'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        success = data['success'] == true;
      }
    } catch (_) {
      offline = true;
      for (final id in ids) await VoyageDao.clearVoyageStatut(id);
      success = true;
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        for (final v in allClotures) v['statut'] = 'actif';
        _reopenLoading = false;
      });
      _showToast(
        offline
            ? 'Journée réouverte (hors-ligne) · ${ids.length} voyage(s)'
            : 'Journée réouverte · ${ids.length} voyage(s)',
        isWarning: offline,
      );
      if (!offline) {
        await _fetchProgrammes();
        await _fetchNonProgrammes();
      }
    } else {
      setState(() => _reopenLoading = false);
      _showToast('Échec de la réouverture', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reopen a single voyage
  // ─────────────────────────────────────────────────────────────

  Future<void> _reopenVoyage(Map<String, dynamic> voyage) async {
    final idVente = (voyage['id_vente'] ?? voyage['id']) as int?;
    if (idVente == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReopenConfirmSheet(voyage: voyage),
    );

    if (confirmed != true || !mounted) return;
    _showToast('Réouverture en cours…');

    try {
      final response = await http
          .put(
            Uri.parse(
                'http://192.168.1.16:8000/billetterie/vente/$idVente/reopen'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await VoyageDao.clearVoyageStatut(idVente);
          setState(() => voyage['statut'] = 'actif');
          _showToast('Voyage réouvert avec succès');
          return;
        }
        _showToast(data['message'] ?? 'Impossible de réouvrir', isError: true);
        return;
      }
      _showToast('Erreur serveur', isError: true);
    } catch (_) {
      _showToast('Hors-ligne — réouverture impossible', isOffline: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Export (uses all voyages from both tabs)
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
      return dt.year == now.year &&
             dt.month == now.month &&
             dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _doExport(String format) async {
    setState(() => _exportLoading = true);
    _showToast(
      format == 'excel'
          ? 'Génération du fichier Excel…'
          : 'Génération du fichier PDF…',
      isWarning: true,
    );

    // Merge both voyage lists for the report
    final allVoyages = [...voyagesProgrammes, ...voyagesNonProgrammes];

    try {
      final List<Map<String, dynamic>> allTickets = [];
      for (final v in allVoyages) {
        final id = (v['id_vente'] ?? v['id']) as int?;
        if (id == null) continue;
        final rows = await TicketDao.getTicketsByVoyage(id);
        for (final r in rows) {
          final ticket = Map<String, dynamic>.from(r);
          if (_isToday(ticket['date_heure'] as String?)) {
            allTickets.add(ticket);
          }
        }
      }

      final agent     = widget.agent;
      final agentName =
          '${agent['prenom'] ?? ''} ${agent['nom'] ?? ''}'.trim();
      final now     = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.year}';

      final int totalRecette = allTickets.fold(
          0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      final int totalTickets = allTickets.fold(
          0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final int totalGratuits = allTickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));

      final dir = await getTemporaryDirectory();
      File file;

      if (format == 'excel') {
        file = await _buildExcel(
          allTickets:    allTickets,
          voyages:       allVoyages,
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
          agentName:     agentName,
          dateStr:       dateStr,
          totalRecette:  totalRecette,
          totalTickets:  totalTickets,
          totalGratuits: totalGratuits,
          dir:           dir,
        );
      }

      await _sendEmail(
        file:         file,
        format:       format,
        agentName:    agentName,
        dateStr:      dateStr,
        totalRecette: totalRecette,
        totalTickets: totalTickets,
        voyageCount:  allVoyages.length,
      );

      _showToast('Rapport (aujourd\'hui) envoyé à $_kReportRecipient ✓');
    } catch (e) {
      debugPrint('❌ Export error: $e');
      _showToast('Erreur export : $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build Excel
  // ─────────────────────────────────────────────────────────────

  Future<File> _buildExcel({
    required List<Map<String, dynamic>> allTickets,
    required List<dynamic> voyages,
    required String agentName,
    required String dateStr,
    required String label,
    required int totalRecette,
    required int totalTickets,
    required int totalGratuits,
    required Directory dir,
  }) async {
    final excel = xl.Excel.createExcel();
    excel.delete('Sheet1');

    final resume = excel['Résumé'];
    _xlsCell(resume, 0, 0, 'RAPPORT JOURNÉE — $_todayLabel',
        bold: true, fgHex: '#0D1B3E');
    _xlsCell(resume, 1, 0, 'Agent : $agentName', fgHex: '#374151');
    _xlsCell(resume, 2, 0, 'Généré le $dateStr', fgHex: '#6B7280');

    _xlsHeader(resume, 4, 0, 'Indicateur');
    _xlsHeader(resume, 4, 1, 'Valeur');

    final payants   = totalTickets - totalGratuits;
    final prixMoyen = payants > 0
        ? (allTickets
                    .where((t) =>
                        (t['montant_total'] as num? ?? 0).toInt() > 0)
                    .fold(0,
                        (s, t) =>
                            s +
                            ((t['montant_total'] as num? ?? 0).toInt())) /
                payants)
            .round()
        : 0;

    final kpis = [
      ['Recette totale (ms)', totalRecette],
      ['Recette totale (DT)', '${(totalRecette / 1000).toStringAsFixed(3)} DT'],
      ['Total tickets vendus', totalTickets],
      ['Tickets payants', payants],
      ['Tickets gratuits', totalGratuits],
      ['Prix moyen/ticket (ms)', prixMoyen],
      [
        'Taux de gratuité',
        totalTickets > 0
            ? '${((totalGratuits / totalTickets) * 100).toStringAsFixed(1)}%'
            : '0%'
      ],
      ['Voyages programmés', voyagesProgrammes.length],
      ['Voyages non programmés', voyagesNonProgrammes.length],
      ['Total voyages', voyages.length],
    ];

    for (int i = 0; i < kpis.length; i++) {
      final bg = i.isEven ? '#F2F5FB' : '#FFFFFF';
      _xlsCell(resume, 5 + i, 0, kpis[i][0], bgHex: bg, bold: true);
      _xlsCell(resume, 5 + i, 1, kpis[i][1],
          bgHex: bg,
          fgHex: kpis[i][0].toString().contains('Recette')
              ? '#0D1B3E'
              : kpis[i][0].toString().contains('gratuit')
                  ? '#16A34A'
                  : '#111827');
    }

    resume.setColumnWidth(0, 32);
    resume.setColumnWidth(1, 22);

    final ticketsSheet = excel['Tickets'];
    final headers = [
      '#', 'Date', 'Heure', 'Départ', 'Arrivée',
      'Segment', 'Tarif', 'Qté', 'Prix unit. (ms)', 'Total (ms)', 'Sync',
    ];
    for (int c = 0; c < headers.length; c++) {
      _xlsHeader(ticketsSheet, 0, c, headers[c]);
    }

    for (int i = 0; i < allTickets.length; i++) {
      final t      = allTickets[i];
      final isFree = ((t['montant_total'] as num? ?? 0).toInt()) == 0;
      final dt     = DateTime.tryParse(t['date_heure'] ?? '');
      final bg     = i.isEven ? '#F9FAFB' : '#FFFFFF';

      _xlsCell(ticketsSheet, i + 1, 0, i + 1, bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 1,
          dt != null
              ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
              : '',
          bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 2,
          dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : '',
          bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 3, t['point_depart'] ?? '', bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 4, t['point_arrivee'] ?? '', bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 5,
          t['id_segment'] != null ? 'Seg. ${t['id_segment']}' : '—',
          bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 6, t['type_tarif'] ?? '', bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 7,
          (t['quantite'] as num? ?? 1).toInt(), bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 8,
          (t['prix_unitaire'] as num? ?? 0).toInt(), bgHex: bg);
      _xlsCell(ticketsSheet, i + 1, 9,
          (t['montant_total'] as num? ?? 0).toInt(),
          bgHex: bg,
          bold: isFree,
          fgHex: isFree ? '#16A34A' : '#0D1B3E');
      _xlsCell(ticketsSheet, i + 1, 10, t['statut_sync'] ?? 'synced',
          bgHex: bg,
          fgHex: t['statut_sync'] == 'pending'
              ? '#D97706'
              : t['statut_sync'] == 'failed'
                  ? '#DC2626'
                  : '#16A34A');
    }

    final totalRow = allTickets.length + 2;
    _xlsCell(ticketsSheet, totalRow, 6, 'TOTAL',
        bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    _xlsCell(ticketsSheet, totalRow, 7, totalTickets,
        bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    _xlsCell(ticketsSheet, totalRow, 9, totalRecette,
        bold: true, bgHex: '#1A3260', fgHex: '#F5C842');

    final widths = [
      5.0, 14.0, 10.0, 22.0, 22.0, 10.0, 28.0, 8.0, 16.0, 14.0, 12.0
    ];
    for (int c = 0; c < widths.length; c++) {
      ticketsSheet.setColumnWidth(c, widths[c]);
    }

    final tarifSheet   = excel['Par tarif'];
    final tarifHeaders = [
      'Type de tarif', 'Quantité', 'Prix unitaire (ms)', 'Total (ms)', '% du total',
    ];
    for (int c = 0; c < tarifHeaders.length; c++) {
      _xlsHeader(tarifSheet, 0, c, tarifHeaders[c]);
    }

    final tarifMap = <String, Map<String, int>>{};
    for (final t in allTickets) {
      final type = ((t['type_tarif'] ?? '') as String).trim().isEmpty
          ? 'Inconnu'
          : (t['type_tarif'] as String).trim();
      final qty    = (t['quantite'] as num? ?? 1).toInt();
      final total  = (t['montant_total'] as num? ?? 0).toInt();
      final unit   = (t['prix_unitaire'] as num? ?? 0).toInt();
      tarifMap[type]               ??= {'count': 0, 'total': 0, 'unitaire': 0};
      tarifMap[type]!['count']      = tarifMap[type]!['count']! + qty;
      tarifMap[type]!['total']      = tarifMap[type]!['total']! + total;
      if (unit > 0) tarifMap[type]!['unitaire'] = unit;
    }
    final tarifEntries = tarifMap.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    int tRow = 1;
    for (final e in tarifEntries) {
      final isFree = e.value['total']! == 0;
      final pct    = totalTickets > 0
          ? '${((e.value['count']! / totalTickets) * 100).toStringAsFixed(1)}%'
          : '0%';
      final bg = tRow.isOdd ? '#F9FAFB' : '#FFFFFF';
      _xlsCell(tarifSheet, tRow, 0, e.key, bgHex: bg, bold: true);
      _xlsCell(tarifSheet, tRow, 1, e.value['count']!, bgHex: bg);
      _xlsCell(tarifSheet, tRow, 2, isFree ? '—' : '${e.value['unitaire']}',
          bgHex: bg);
      _xlsCell(tarifSheet, tRow, 3, e.value['total']!,
          bgHex: bg, bold: true, fgHex: isFree ? '#16A34A' : '#0D1B3E');
      _xlsCell(tarifSheet, tRow, 4, pct, bgHex: bg);
      tRow++;
    }

    _xlsCell(tarifSheet, tRow + 1, 0, 'TOTAL',
        bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');
    _xlsCell(tarifSheet, tRow + 1, 1, totalTickets,
        bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    _xlsCell(tarifSheet, tRow + 1, 3, totalRecette,
        bold: true, bgHex: '#1A3260', fgHex: '#F5C842');
    _xlsCell(tarifSheet, tRow + 1, 4, '100%',
        bold: true, bgHex: '#1A3260', fgHex: '#FFFFFF');

    tarifSheet.setColumnWidth(0, 30);
    tarifSheet.setColumnWidth(1, 12);
    tarifSheet.setColumnWidth(2, 20);
    tarifSheet.setColumnWidth(3, 16);
    tarifSheet.setColumnWidth(4, 14);

    final voyageSheet = excel['Par voyage'];
    final vHeaders    = [
      'Voyage', 'Type', 'Trajet', 'Tickets', 'Gratuits', 'Payants', 'Recette (ms)',
    ];
    for (int c = 0; c < vHeaders.length; c++) {
      _xlsHeader(voyageSheet, 0, c, vHeaders[c]);
    }

    int vRow = 1;
    for (final v in voyages) {
      final id       = (v['id_vente'] ?? v['id']) as int?;
      final depart   = v['depart'] ?? '?';
      final arrivee  = v['arrivee'] ?? '?';
      final typeStr  = (v['type'] as String?) ?? 'programmé';
      final vTickets = id == null
          ? <Map<String, dynamic>>[]
          : allTickets.where((t) => t['id_vente'] == id).toList();
      final vTotal  = vTickets.fold(
          0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      final vCount  = vTickets.fold(
          0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final vGratis = vTickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final bg = vRow.isOdd ? '#F9FAFB' : '#FFFFFF';

      _xlsCell(voyageSheet, vRow, 0, '#${id ?? '?'}', bgHex: bg, bold: true);
      _xlsCell(voyageSheet, vRow, 1, typeStr, bgHex: bg);
      _xlsCell(voyageSheet, vRow, 2, '$depart → $arrivee', bgHex: bg);
      _xlsCell(voyageSheet, vRow, 3, vCount, bgHex: bg);
      _xlsCell(voyageSheet, vRow, 4, vGratis,
          bgHex: bg, fgHex: vGratis > 0 ? '#16A34A' : '#111827');
      _xlsCell(voyageSheet, vRow, 5, vCount - vGratis, bgHex: bg);
      _xlsCell(voyageSheet, vRow, 6, vTotal,
          bgHex: bg, bold: true, fgHex: '#0D1B3E');
      vRow++;
    }

    voyageSheet.setColumnWidth(0, 10);
    voyageSheet.setColumnWidth(1, 16);
    voyageSheet.setColumnWidth(2, 32);
    voyageSheet.setColumnWidth(3, 12);
    voyageSheet.setColumnWidth(4, 12);
    voyageSheet.setColumnWidth(5, 12);
    voyageSheet.setColumnWidth(6, 16);

    final bytes    = excel.encode()!;
    final fileName = 'rapport_${label}_${_matricule}_$dateStr.xlsx';
    final file     = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  void _xlsHeader(xl.Sheet s, int row, int col, String text) {
    final cell = s.cell(xl.CellIndex.indexByColumnRow(
        columnIndex: col, rowIndex: row));
    cell.value      = xl.TextCellValue(text);
    cell.cellStyle  = xl.CellStyle(
      bold: true,
      fontColorHex:       xl.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: xl.ExcelColor.fromHexString('#1A3260'),
      horizontalAlign:    xl.HorizontalAlign.Center,
      verticalAlign:      xl.VerticalAlign.Center,
    );
  }

  void _xlsCell(xl.Sheet s, int row, int col, dynamic value,
      {bool bold = false, String? bgHex, String? fgHex}) {
    final cell = s.cell(xl.CellIndex.indexByColumnRow(
        columnIndex: col, rowIndex: row));
    if (value is int || value is double) {
      cell.value =
          xl.IntCellValue(value is int ? value : (value as double).toInt());
    } else {
      cell.value = xl.TextCellValue(value?.toString() ?? '');
    }
    cell.cellStyle = xl.CellStyle(
      bold: bold,
      fontColorHex: fgHex != null
          ? xl.ExcelColor.fromHexString(fgHex)
          : xl.ExcelColor.fromHexString('#111827'),
      backgroundColorHex: bgHex != null
          ? xl.ExcelColor.fromHexString(bgHex)
          : xl.ExcelColor.fromHexString('#FFFFFF'),
      verticalAlign: xl.VerticalAlign.Center,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build PDF
  // ─────────────────────────────────────────────────────────────

  Future<File> _buildPdf({
    required List<Map<String, dynamic>> allTickets,
    required List<dynamic> voyages,
    required String agentName,
    required String dateStr,
    required int totalRecette,
    required int totalTickets,
    required int totalGratuits,
    required Directory dir,
  }) async {
    final pdf      = pw.Document();
    final payants  = totalTickets - totalGratuits;
    final prixMoyen = payants > 0
        ? (allTickets
                    .where((t) =>
                        (t['montant_total'] as num? ?? 0).toInt() > 0)
                    .fold(0,
                        (s, t) =>
                            s +
                            ((t['montant_total'] as num? ?? 0).toInt())) /
                payants)
            .round()
        : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('0D1B3E'),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RAPPORT DE JOURNÉE — $_todayLabel',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Agent : $agentName   |   Généré le $dateStr',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xB3FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('INDICATEURS CLÉS',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColor.fromHex('E5E7EB'), width: 0.5),
            children: [
              _pdfTableRow(
                  ['Recette totale',
                   '$totalRecette ms',
                   '≈ ${(totalRecette / 1000).toStringAsFixed(3)} DT'],
                  highlight: true),
              _pdfTableRow([
                'Total tickets',
                '$totalTickets',
                '$payants payants + $totalGratuits gratuits'
              ]),
              _pdfTableRow(
                  ['Prix moyen (payants)', '$prixMoyen ms', ''],
                  highlight: true),
              _pdfTableRow([
                'Taux de gratuité',
                totalTickets > 0
                    ? '${((totalGratuits / totalTickets) * 100).toStringAsFixed(1)}%'
                    : '0%',
                ''
              ]),
              _pdfTableRow(
                  ['Voyages programmés', '${voyagesProgrammes.length}', ''],
                  highlight: true),
              _pdfTableRow(
                  ['Voyages non programmés', '${voyagesNonProgrammes.length}', '']),
              _pdfTableRow(
                  ['Total voyages', '${voyages.length}', ''],
                  highlight: true),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('RÉPARTITION PAR TARIF',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfTarifTable(allTickets, totalTickets),
          pw.SizedBox(height: 24),
          pw.Text('DÉTAIL DES TICKETS',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('6B7280'))),
          pw.SizedBox(height: 8),
          _buildPdfTicketsTable(allTickets),
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
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Text(
                  c,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: isHeader ? pw.FontWeight.bold : null,
                    color: isHeader
                        ? PdfColors.white
                        : PdfColor.fromHex('111827'),
                  ),
                ),
              ))
          .toList(),
    );
  }

  pw.Widget _buildPdfTarifTable(
      List<Map<String, dynamic>> tickets, int totalTickets) {
    final tarifMap = <String, Map<String, int>>{};
    for (final t in tickets) {
      final type = ((t['type_tarif'] ?? '') as String).trim().isEmpty
          ? 'Inconnu'
          : (t['type_tarif'] as String).trim();
      final qty   = (t['quantite'] as num? ?? 1).toInt();
      final total = (t['montant_total'] as num? ?? 0).toInt();
      tarifMap[type]             ??= {'count': 0, 'total': 0};
      tarifMap[type]!['count']   = tarifMap[type]!['count']! + qty;
      tarifMap[type]!['total']   = tarifMap[type]!['total']! + total;
    }
    final entries = tarifMap.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      children: [
        _pdfTableRow(
            ['Type de tarif', 'Qté', 'Total (ms)', '% voyageurs'],
            isHeader: true),
        ...entries.map((e) {
          final pct = totalTickets > 0
              ? '${((e.value['count']! / totalTickets) * 100).toStringAsFixed(1)}%'
              : '0%';
          return _pdfTableRow([
            e.key,
            '${e.value['count']}',
            '${e.value['total']}',
            pct,
          ], highlight: entries.indexOf(e).isEven);
        }),
        _pdfTableRow(
            [
              'TOTAL',
              '$totalTickets',
              '${tickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()))}',
              '100%'
            ],
            isHeader: true),
      ],
    );
  }

  pw.Widget _buildPdfTicketsTable(List<Map<String, dynamic>> tickets) {
    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FixedColumnWidth(55),
        5: pw.FixedColumnWidth(55),
      },
      children: [
        _pdfTableRow(
            ['#', 'Départ', 'Arrivée', 'Tarif', 'Qté', 'Total (ms)'],
            isHeader: true),
        ...tickets.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          return _pdfTableRow([
            '${i + 1}',
            t['point_depart'] ?? '',
            t['point_arrivee'] ?? '',
            t['type_tarif'] ?? '',
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
    final smtpServer = SmtpServer(
      _kSmtpHost,
      port: _kSmtpPort,
      username: _kSmtpUser,
      password: _kSmtpPassword,
    );

    final message = Message()
      ..from = Address(_kSmtpUser, 'SRTB Billetterie')
      ..recipients.add(_kReportRecipient)
      ..subject =
          'Rapport journée $dateStr — Agent $agentName — $totalRecette ms'
      ..text = '''
Rapport de journée du $_todayLabel
Agent : $agentName
Matricule : $_matricule

Récapitulatif :
  • Recette totale  : $totalRecette ms (≈ ${(totalRecette / 1000).toStringAsFixed(3)} DT)
  • Total tickets   : $totalTickets
  • Voyages programmés   : ${voyagesProgrammes.length}
  • Voyages non programmés : ${voyagesNonProgrammes.length}
  • Total voyages clôturés : $voyageCount

Fichier joint : ${file.path.split('/').last}
'''.trim()
      ..attachments = [
        FileAttachment(file)..location = Location.attachment,
      ];

    // ignore: deprecated_member_use
    await send(message, smtpServer);
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String _getTime(String? dh) =>
      (dh != null && dh.split(' ').length > 1)
          ? dh.split(' ')[1].substring(0, 5)
          : '';

  void _openVoyage(Map<String, dynamic> voyage) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VenteTicketsPage(voyage: voyage)),
    ).then((_) {
      _fetchProgrammes();
      _fetchNonProgrammes();
    });
  }

  void _showLockedSnack() {
    _showToast(
        "Terminez le voyage en cours avant d'accéder à celui-ci",
        isWarning: true);
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
            // ── Shared action bar (above the tab bar) ──
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
  // Shared Action Bar — sits above tabs, covers both lists
  // ─────────────────────────────────────────────────────────────

  Widget _buildSharedActionBar() {
    final bool loading = isLoadingProgrammes || isLoadingNonProgrammes;
    if (loading) return const SizedBox.shrink();

    final bool nothingToShow =
        voyagesProgrammes.isEmpty && voyagesNonProgrammes.isEmpty;
    if (nothingToShow) return const SizedBox.shrink();

    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _clotureConfirming
            ? _buildClotureConfirmCard()
            : _allClotures
                ? _buildPostClotureActions()
                : _buildClotureJourneeBtn(),
      ),
    );
  }

  /// Inline confirm card.
  Widget _buildClotureConfirmCard() {
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
        border: Border.all(
            color: Colors.red.shade300.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade300, size: 17),
              const SizedBox(width: 7),
              Text('Clôturer toute la journée ?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.red.shade300)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${allToClose.length} voyage(s)  pour le $_todayLabel.',
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, height: 1.4),
          ),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _clotureLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmer',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Red "Clôture Journée" button — all voyages open.
  Widget _buildClotureJourneeBtn() {
    return SizedBox(
      key: const ValueKey('cj_btn'),
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _clotureLoading
              ? null
              : () => setState(() => _clotureConfirming = true),
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
                BoxShadow(
                    color: const Color(0xFF9B1C1C).withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_clotureLoading)
                  const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  const Icon(Icons.event_busy_rounded,
                      color: Colors.white, size: 19),
                const SizedBox(width: 9),
                Text(
                  _clotureLoading
                      ? 'Clôture en cours…'
                      : 'Clôture Journée  ',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Post-clôture: export + réouvrir.
  Widget _buildPostClotureActions() {
    return Column(
      key: const ValueKey('post_cloture'),
      children: [
        // Export button
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
                    BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_exportLoading)
                      const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.send_rounded,
                          color: Colors.white, size: 19),
                    const SizedBox(width: 9),
                    Text(
                      _exportLoading
                          ? 'Envoi en cours…'
                          : 'Exporter & Envoyer le rapport',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Réouvrir journée button
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
                      const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                    else
                      const Icon(Icons.lock_open_outlined,
                          color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      _reopenLoading
                          ? 'Réouverture…'
                          : 'Réouvrir la Journée',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.directions_bus, size: 44, color: AppTheme.navyMid),
            ),
          ),
          const SizedBox(height: 10),

          const Text('S R T B',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 7)),
          const SizedBox(height: 3),
          Text('Mes Voyages',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _headerPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppTheme.goldLight, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${agent['prenom']} ${agent['nom']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _headerPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.goldLight, size: 12),
                    const SizedBox(width: 6),
                    Text(_todayLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
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
    return Container(
      color: AppTheme.navyDark,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.goldLight,
        indicatorWeight: 3,
        labelColor: AppTheme.goldLight,
        unselectedLabelColor: Colors.white54,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 14),
                const SizedBox(width: 5),
                const Flexible(
                    child: Text('Programmés',
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
                _tabBadge(voyagesProgrammes.length, isLoadingProgrammes),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bus_outlined, size: 14),
                const SizedBox(width: 5),
                const Flexible(
                    child: Text('Non programmés',
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
                _tabBadge(
                    voyagesNonProgrammes.length, isLoadingNonProgrammes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 1 — Programmés
  // ─────────────────────────────────────────────────────────────

  Widget _buildProgrammesTab() {
    if (isLoadingProgrammes)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyMid));
    if (errorProgrammes != null)
      return _buildError(errorProgrammes!, _fetchProgrammes);

    final activeIdx = _activeIndex;

    return Column(
      children: [
        if (voyagesProgrammes.isNotEmpty)
          _buildStatsBar([
            _statTile(Icons.directions_bus_outlined, 'Total',
                '${voyagesProgrammes.length}', AppTheme.navyMid),
            _statTile(Icons.check_circle_outline, 'Clôturés',
                '${voyagesProgrammes.where((v) => v['statut'] == 'cloture').length}',
                Colors.grey),
            _statTile(Icons.play_circle_outline, 'En cours',
                activeIdx >= 0 ? '1' : '0', const Color(0xFF16A34A)),
          ]),

        Expanded(
          child: voyagesProgrammes.isEmpty
              ? _buildEmpty('Aucun voyage programmé')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: voyagesProgrammes.length,
                  itemBuilder: (_, i) {
                    final v         = voyagesProgrammes[i]
                        as Map<String, dynamic>;
                    final isCloture = v['statut'] == 'cloture';
                    final isActive  = i == activeIdx;
                    final isLocked  = !isCloture && !isActive;

                    final Color accent, bgColor, borderColor;
                    if (isCloture) {
                      accent      = Colors.grey;
                      bgColor     = Colors.grey.shade50;
                      borderColor = Colors.grey.shade200;
                    } else if (isActive) {
                      accent      = AppTheme.navyMid;
                      bgColor     = const Color(0xFFEBF0FF);
                      borderColor = AppTheme.navyLight;
                    } else {
                      accent      = Colors.orange.shade700;
                      bgColor     = Colors.orange.shade50;
                      borderColor = Colors.orange.shade200;
                    }

                    return _buildVoyageCard(
                      voyage:      v,
                      accent:      accent,
                      bgColor:     bgColor,
                      borderColor: borderColor,
                      isActive:    isActive,
                      isCloture:   isCloture,
                      isLocked:    isLocked,
                      onTap:       isCloture
                          ? () => _reopenVoyage(v)
                          : isLocked
                              ? _showLockedSnack
                              : () => _openVoyage(v),
                      extraLabel: isCloture
                          ? 'Appuyez pour réouvrir'
                          : isLocked
                              ? 'En attente du voyage précédent'
                              : null,
                      extraLabelColor: isCloture
                          ? Colors.grey.shade400
                          : Colors.orange.shade600,
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
    if (isLoadingNonProgrammes)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyMid));
    if (errorNonProgrammes != null)
      return _buildError(errorNonProgrammes!, _fetchNonProgrammes);

    return Column(
      children: [
        if (voyagesNonProgrammes.isNotEmpty)
          _buildStatsBar([
            _statTile(Icons.directions_bus_outlined, 'Total',
                '${voyagesNonProgrammes.length}', AppTheme.navyMid),
            _statTile(Icons.check_circle_outline, 'Clôturés',
                '${voyagesNonProgrammes.where((v) => v['statut'] == 'cloture').length}',
                Colors.grey),
            _statTile(Icons.play_circle_outline, 'Actifs',
                '${voyagesNonProgrammes.where((v) => v['statut'] != 'cloture').length}',
                const Color(0xFF16A34A)),
          ]),

        Expanded(
          child: voyagesNonProgrammes.isEmpty
              ? _buildEmpty('Aucun voyage non programmé')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: voyagesNonProgrammes.length,
                  itemBuilder: (_, i) {
                    final v         = voyagesNonProgrammes[i]
                        as Map<String, dynamic>;
                    final isCloture = v['statut'] == 'cloture';

                    final Color accent, bgColor, borderColor;
                    if (isCloture) {
                      accent      = Colors.grey;
                      bgColor     = Colors.grey.shade50;
                      borderColor = Colors.grey.shade200;
                    } else {
                      accent      = const Color(0xFF0E7C5B);
                      bgColor     = const Color(0xFFE8F5F0);
                      borderColor = const Color(0xFF6ECBAD);
                    }

                    final typeLabel =
                        ((v['type'] as String?) ?? '').isNotEmpty
                            ? v['type'] as String
                            : 'Spontané';

                    return _buildVoyageCard(
                      voyage:      v,
                      accent:      accent,
                      bgColor:     bgColor,
                      borderColor: borderColor,
                      isActive:    !isCloture,
                      isCloture:   isCloture,
                      isLocked:    false,
                      onTap:       isCloture
                          ? () => _reopenVoyage(v)
                          : () => _openVoyage(v),
                      extraLabel: isCloture
                          ? 'Appuyez pour réouvrir'
                          : typeLabel,
                      extraLabelColor:
                          isCloture ? Colors.grey.shade400 : accent,
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
            BoxShadow(
                color: accent.withOpacity(isCloture ? 0.04 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3))
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(Icons.directions_bus, color: accent, size: 24),
                  ),
                  if (isCloture)
                    Positioned(
                        right: -4,
                        bottom: -4,
                        child: _statusDot(Colors.grey, Icons.history, 10))
                  else if (isLocked)
                    Positioned(
                        right: -4,
                        bottom: -4,
                        child: _statusDot(
                            Colors.orange.shade700, Icons.lock, 10))
                  else if (isActive)
                    Positioned(
                        right: -4,
                        bottom: -4,
                        child: _statusDot(
                            const Color(0xFF16A34A), Icons.play_arrow, 11)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: (isActive && !isLocked && !isCloture)
                                    ? AppTheme.goldLight
                                    : accent.withOpacity(0.6),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${voyage['depart']} → ${voyage['arrivee']}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCloture
                                    ? Colors.grey.shade400
                                    : AppTheme.navyDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            timeLabel.isNotEmpty
                                ? '$timeLabel  ·  $_todayLabel'
                                : _todayLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (extraLabel != null && extraLabel.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(extraLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: extraLabelColor ?? accent,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.25)),
                    ),
                    child: Text(
                      isCloture
                          ? 'Clôturé'
                          : isLocked
                              ? 'En attente'
                              : 'Actif',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                      isCloture
                          ? Icons.lock_open_outlined
                          : isLocked
                              ? Icons.lock_outline
                              : Icons.chevron_right,
                      color: accent.withOpacity(0.5),
                      size: 18),
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
        separated.add(
            Container(width: 1, height: 36, color: Colors.grey.shade100));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.navyMid.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: separated),
    );
  }

  Widget _statTile(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, IconData icon, double iconSize) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.cardWhite, width: 1.5)),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _tabBadge(int count, bool loading) {
    if (loading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }

  Widget _buildError(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: Colors.orange.shade200),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, height: 1.6)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
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
          Icon(Icons.directions_bus_outlined,
              size: 52, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
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
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppTheme.navyMid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.send_rounded, color: AppTheme.navyMid, size: 28),
          ),
          const SizedBox(height: 14),

          const Text('Envoyer le rapport',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text(
            'Le rapport complet du $todayLabel sera envoyé\npar email à ',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            _kReportRecipient,
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.navyMid,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'excel'),
                    icon: const Icon(Icons.table_chart_rounded, size: 20),
                    label: const Text('Excel\n.xlsx',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyMid,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                    icon:
                        const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text('PDF\n.pdf',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
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
  const _ReopenJourneeConfirmSheet(
      {required this.count, required this.todayLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppTheme.navyMid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_open_outlined,
                color: AppTheme.navyMid, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Réouvrir toute la journée ?',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text(
            '$count voyage(s) du $todayLabel\n seront remis au statut Actif.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text('Cette action est réversible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyMid,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Réouvrir tout',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
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
    final depart  = voyage['depart'] ?? '';
    final arrivee = voyage['arrivee'] ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 22),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppTheme.navyMid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_open_outlined,
                color: AppTheme.navyMid, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Réouvrir ce voyage ?',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text('$depart → $arrivee',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(
            'Le voyage sera remis au statut Actif\net pourra être utilisé à nouveau.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyMid,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Réouvrir',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
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
    _slide =
        Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2400),
        () { if (mounted) _ctrl.reverse(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
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
}