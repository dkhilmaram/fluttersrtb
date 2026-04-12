import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';        // ← add this
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../local_database.dart';
import 'login_page.dart';
import '../route_observer.dart';

// ── Palette ──
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

// ── Admin email — change this ──
const String kAdminEmail = 'dkhilmaram0@gmail.com';

String? _resolveSegment(Map<String, dynamic> map) {
  const keys = [
    'segment_ordre', 'id_segment', 'segment_id', 'ordre',
    'numero_segment', 'seg', 'segment', 'ordre_segment',
    'secteur', 'secteur_id', 'id_secteur',
  ];
  for (final k in keys) {
    final v = map[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}

class HistoriquePage extends StatefulWidget {
  final Map<String, dynamic> voyage;
  const HistoriquePage({super.key, required this.voyage});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage>
    with SingleTickerProviderStateMixin
    implements RouteAware {
  late TabController _tabs;

  List<dynamic> _tickets = [];
  bool isLoading = true;
  String? errorMessage;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  // ─── Toast ─────────────────────────────────────────────────
  void _showToast(String msg, {bool isError = false, bool isInfo = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isInfo
            ? Colors.lightBlue.shade700
            : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline
        : isInfo
            ? Icons.info_outline_rounded
            : Icons.check_circle_outline;

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

  // ─── Lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _tabs.dispose();
    super.dispose();
  }

  @override void didPopNext() => _fetchAll();
  @override void didPush() {}
  @override void didPop() {}
  @override void didPushNext() {}

  // ─── Fetch ─────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    setState(() { isLoading = true; errorMessage = null; });

    final id = widget.voyage['id'] as int?;
    if (id == null) {
      setState(() { errorMessage = 'ID du voyage manquant'; isLoading = false; });
      _showToast('ID du voyage manquant', isError: true);
      return;
    }

    final localRows = await LocalDatabase.getTicketsByVoyage(id);
    final allLocal  = localRows.map(_mapLocalTicket).toList();

    if (allLocal.isNotEmpty) {
      _sortByDate(allLocal);
      setState(() { _tickets = allLocal; isLoading = false; });
    }

    try {
      final response = await http
          .get(Uri.parse('http://192.168.1.22:8000/billetterie/voyages/$id/tickets'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final serverList = (data['tickets'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

          if (serverList.isNotEmpty) {
            debugPrint('🔍 Server ticket keys  : ${serverList.first.keys.toList()}');
          }

          final localByServerId = {
            for (final t in localRows)
              if (t['id_serveur'] != null) t['id_serveur'] as int: t,
          };

          for (final st in serverList) {
            final sid = st['id_ticket'] as int?;
            if (sid == null) continue;

            final segValue = _resolveSegment(st) ?? '0';
            final segInt   = int.tryParse(segValue) ?? 0;

            if (localByServerId.containsKey(sid)) {
              final localRow  = localByServerId[sid]!;
              final storedSeg = localRow['id_segment'];
              if (storedSeg == null || storedSeg == 0) {
                try {
                  await LocalDatabase.updateTicketSegment(localRow['id'] as int, segInt);
                } catch (_) {}
              }
            } else {
              try {
                await LocalDatabase.insertTicket({
                  'id_vente':        id,
                  'id_segment':      segInt,
                  'point_depart':    st['point_depart']   ?? '',
                  'point_arrivee':   st['point_arrivee']  ?? '',
                  'type_tarif':      st['type_tarif']     ?? '',
                  'quantite':        (st['quantite']      as num? ?? 1).toInt(),
                  'prix_unitaire':   (st['prix_unitaire'] as num? ?? 0).toInt(),
                  'montant_total':   (st['montant_total'] as num? ?? 0).toInt(),
                  'date_heure':      st['date_heure']     ?? '',
                  'matricule_agent': st['matricule_agent'] ?? st['agent'] ?? 0,
                  'statut_sync':     'synced',
                  'id_serveur':      sid,
                });
              } catch (_) {}
            }
          }

          final freshRows = await LocalDatabase.getTicketsByVoyage(id);
          final merged    = freshRows.map(_mapLocalTicket).toList();
          _sortByDate(merged);

          final pendingCount = merged.where((t) => t['_statut_sync'] == 'pending').length;
          final failedCount  = merged.where((t) => t['_statut_sync'] == 'failed').length;

          setState(() { _tickets = merged; isLoading = false; });

          if (pendingCount > 0 || failedCount > 0) {
            _showToast(
              '${merged.length} ticket(s) · $pendingCount en attente · $failedCount échoué(s)',
              isInfo: true,
            );
          } else {
            _showToast('${merged.length} ticket(s) chargés');
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️  Server fetch error: $e');
    }

    if (allLocal.isEmpty) setState(() { isLoading = false; });

    final pendingCount = allLocal.where((t) => t['_statut_sync'] == 'pending').length;
    final msg = allLocal.isEmpty
        ? 'Hors-ligne — aucun ticket local'
        : pendingCount > 0
            ? 'Hors-ligne — $pendingCount ticket(s) en attente de sync'
            : 'Hors-ligne — ${allLocal.length} ticket(s) en cache';
    _showToast(msg, isInfo: true);
  }

  void _sortByDate(List list) {
    list.sort((a, b) {
      final da = DateTime.tryParse(a['date_heure'] ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b['date_heure'] ?? '') ?? DateTime(0);
      return db.compareTo(da);
    });
  }

  Map<String, dynamic> _mapLocalTicket(Map<String, dynamic> t) {
    final segValue = _resolveSegment(t);
    return {
      'id_ticket':     t['id'],
      'point_depart':  t['point_depart'],
      'point_arrivee': t['point_arrivee'],
      'type_tarif':    t['type_tarif'],
      'quantite':      (t['quantite']      as num? ?? 0).toInt(),
      'prix_unitaire': (t['prix_unitaire'] as num? ?? 0).toInt(),
      'montant_total': (t['montant_total'] as num? ?? 0).toInt(),
      'date_heure':    t['date_heure'],
      'segment_ordre': segValue,
      'nom_ligne':     t['nom_ligne'],
      'agent':         t['agent'],
      'id_serveur':    t['id_serveur'],
      '_statut_sync':  t['statut_sync'] ?? 'synced',
      '_is_local':     true,
    };
  }

  // ─── Financial helpers ─────────────────────────────────────
  int get _totalRecette => _tickets.fold(
      0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));

  int get _totalTickets => _tickets.fold(
      0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));

  int get _totalGratuits => _tickets
      .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
      .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));

  int get _prixMoyen {
    final payants =
        _tickets.where((t) => ((t['montant_total'] as num? ?? 0).toInt()) > 0).toList();
    if (payants.isEmpty) return 0;
    final total = payants.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
    final qty   = payants.fold(0, (s, t) => s + ((t['quantite']     as num? ?? 1).toInt()));
    return qty == 0 ? 0 : (total / qty).round();
  }

  Map<String, Map<String, int>> get _tarifBreakdown {
    final map = <String, Map<String, int>>{};
    for (final t in _tickets) {
      final rawType = (t['type_tarif'] ?? '').toString().trim();
      final type    = rawType.isEmpty ? 'Inconnu' : rawType;
      final qty     = (t['quantite']      as num? ?? 1).toInt();
      final total   = (t['montant_total'] as num? ?? 0).toInt();
      final unit    = (t['prix_unitaire'] as num? ?? 0).toInt();
      map[type] ??= {'count': 0, 'total': 0, 'unitaire': 0};
      map[type]!['count']    = map[type]!['count']! + qty;
      map[type]!['total']    = map[type]!['total']! + total;
      if (unit > 0) map[type]!['unitaire'] = unit;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));
    return Map.fromEntries(entries);
  }

  Map<String, List<dynamic>> get _segmentBreakdown {
    final map = <String, List<dynamic>>{};
    for (final t in _tickets) {
      final raw = t['segment_ordre'];
      final seg = raw == null ? null : raw.toString().trim();
      final key = (seg == null || seg.isEmpty || seg == 'null') ? '—' : seg;
      map[key] ??= [];
      map[key]!.add(t);
    }
    final entries = map.entries.toList()
      ..sort((a, b) {
        if (a.key == '—') return 1;
        if (b.key == '—') return -1;
        final an = int.tryParse(a.key);
        final bn = int.tryParse(b.key);
        if (an != null && bn != null) return an.compareTo(bn);
        return a.key.compareTo(b.key);
      });
    return Map.fromEntries(entries);
  }

  // ─── Email report builder ───────────────────────────────────
  String _buildEmailHtml() {
    final id      = widget.voyage['id'];
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';
    final now     = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    final bd      = _tarifBreakdown;
    final segs    = _segmentBreakdown;
    final payants = _totalTickets - _totalGratuits;
    final tauxGratuite = _totalTickets > 0
        ? ((_totalGratuits / _totalTickets) * 100).toStringAsFixed(1)
        : '0.0';

    // ── tarif rows ──
    final tarifRows = bd.entries.map((e) {
      final isFree = e.value['total']! == 0;
      final bg     = isFree ? '#F0FDF4' : '#FFFFFF';
      final totalCell = isFree
          ? '<span style="color:#16A34A;font-weight:700">GRATUIT</span>'
          : '<strong>${e.value['total']} ms</strong>';
      return '''
        <tr style="background:$bg">
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB">${e.key}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:center">${e.value['count']}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:center">${isFree ? '—' : '${e.value['unitaire']} ms'}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:right">$totalCell</td>
        </tr>''';
    }).join();

    // ── segment rows ──
    final realSegs = Map.fromEntries(segs.entries.where((e) => e.key != '—'));
    final segRows = realSegs.entries.map((e) {
      final tickets  = e.value;
      final recette  = tickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      final count    = tickets.fold(0, (s, t) => s + ((t['quantite']     as num? ?? 1).toInt()));
      final gratuits = tickets
          .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
          .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
      final dep = tickets.isNotEmpty ? tickets.first['point_depart']  ?? '' : '';
      final arr = tickets.isNotEmpty ? tickets.first['point_arrivee'] ?? '' : '';
      return '''
        <tr>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB"><strong>Seg. ${e.key}</strong></td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;color:#6B7280;font-size:12px">$dep → $arr</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:center">$count</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:center;color:#16A34A">$gratuits</td>
          <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;text-align:right"><strong>$recette ms</strong></td>
        </tr>''';
    }).join();

    // ── ticket detail rows (last 50 to keep email manageable) ──
    final displayTickets = _tickets.take(50).toList();
    final ticketRows = displayTickets.map((t) {
      final isFree  = ((t['montant_total'] as num? ?? 0).toInt()) == 0;
      final seg     = t['segment_ordre'];
      final segCell = (seg == null || seg.toString().trim().isEmpty || seg.toString() == 'null')
          ? '—' : seg.toString();
      final totalCell = isFree
          ? '<span style="color:#16A34A;font-weight:700">GRATUIT</span>'
          : '${(t['montant_total'] as num? ?? 0).toInt()} ms';
      return '''
        <tr>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px">${_formatTime(t['date_heure'])}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px">${t['point_depart'] ?? ''}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px">${t['point_arrivee'] ?? ''}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px;text-align:center">$segCell</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px">${t['type_tarif'] ?? ''}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px;text-align:center">${(t['quantite'] as num? ?? 1).toInt()}</td>
          <td style="padding:6px 10px;border-bottom:1px solid #F3F4F6;font-size:12px;text-align:right">$totalCell</td>
        </tr>''';
    }).join();

    final moreNote = _tickets.length > 50
        ? '<p style="color:#6B7280;font-size:12px;margin:8px 0 0">… et ${_tickets.length - 50} ticket(s) supplémentaires non affichés.</p>'
        : '';

    return '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#F2F5FB;color:#111827">

<!-- ── HEADER ── -->
<table width="100%" cellpadding="0" cellspacing="0">
<tr><td style="background:#0D1B3E;padding:28px 32px">
  <table width="100%" cellpadding="0" cellspacing="0">
  <tr>
    <td>
      <div style="color:#F5C842;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:4px">Rapport de Voyage</div>
      <div style="color:#FFFFFF;font-size:22px;font-weight:700">$depart → $arrivee</div>
      <div style="color:rgba(255,255,255,0.55);font-size:12px;margin-top:4px">Voyage #$id &nbsp;·&nbsp; Généré le $dateStr à $timeStr</div>
    </td>
    <td style="text-align:right;vertical-align:top">
      <div style="background:#F5C842;color:#0D1B3E;padding:8px 18px;border-radius:8px;font-size:22px;font-weight:700;display:inline-block">$_totalRecette ms</div>
      <div style="color:rgba(255,255,255,0.45);font-size:11px;margin-top:4px;text-align:right">Recette totale</div>
    </td>
  </tr>
  </table>
</td></tr>
</table>

<div style="padding:24px 32px">

<!-- ── KPI GRID ── -->
<table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px">
<tr>
  <td width="25%" style="padding-right:12px">
    <div style="background:#FFFFFF;border-radius:10px;padding:16px;border:1px solid #E5E7EB">
      <div style="font-size:11px;color:#6B7280;margin-bottom:4px">TICKETS VENDUS</div>
      <div style="font-size:24px;font-weight:700;color:#0D1B3E">$_totalTickets</div>
    </div>
  </td>
  <td width="25%" style="padding-right:12px">
    <div style="background:#FFFFFF;border-radius:10px;padding:16px;border:1px solid #E5E7EB">
      <div style="font-size:11px;color:#6B7280;margin-bottom:4px">PAYANTS</div>
      <div style="font-size:24px;font-weight:700;color:#1A3260">$payants</div>
    </div>
  </td>
  <td width="25%" style="padding-right:12px">
    <div style="background:#FFFFFF;border-radius:10px;padding:16px;border:1px solid #E5E7EB">
      <div style="font-size:11px;color:#6B7280;margin-bottom:4px">GRATUITS</div>
      <div style="font-size:24px;font-weight:700;color:#16A34A">$_totalGratuits</div>
      <div style="font-size:11px;color:#6B7280;margin-top:2px">$tauxGratuite% du total</div>
    </div>
  </td>
  <td width="25%">
    <div style="background:#FFFFFF;border-radius:10px;padding:16px;border:1px solid #E5E7EB">
      <div style="font-size:11px;color:#6B7280;margin-bottom:4px">PRIX MOYEN</div>
      <div style="font-size:24px;font-weight:700;color:#0D1B3E">$_prixMoyen ms</div>
      <div style="font-size:11px;color:#6B7280;margin-top:2px">ticket payant</div>
    </div>
  </td>
</tr>
</table>

<!-- ── TARIF BREAKDOWN ── -->
<div style="background:#FFFFFF;border-radius:10px;border:1px solid #E5E7EB;margin-bottom:24px;overflow:hidden">
  <div style="background:#1A3260;padding:12px 16px">
    <span style="color:#FFFFFF;font-weight:700;font-size:13px">Recette par tarif</span>
  </div>
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr style="background:#F9FAFB">
      <th style="padding:8px 12px;text-align:left;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TARIF</th>
      <th style="padding:8px 12px;text-align:center;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">QTÉ</th>
      <th style="padding:8px 12px;text-align:center;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">PRIX UNIT.</th>
      <th style="padding:8px 12px;text-align:right;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TOTAL</th>
    </tr>
    $tarifRows
    <tr style="background:#F2F5FB">
      <td colspan="3" style="padding:10px 12px;font-weight:700;color:#0D1B3E">TOTAL</td>
      <td style="padding:10px 12px;text-align:right;font-weight:700;color:#0D1B3E;font-size:15px">$_totalRecette ms</td>
    </tr>
  </table>
</div>

${realSegs.isNotEmpty ? '''
<!-- ── SEGMENTS ── -->
<div style="background:#FFFFFF;border-radius:10px;border:1px solid #E5E7EB;margin-bottom:24px;overflow:hidden">
  <div style="background:#1A3260;padding:12px 16px">
    <span style="color:#FFFFFF;font-weight:700;font-size:13px">Recette par segment</span>
  </div>
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr style="background:#F9FAFB">
      <th style="padding:8px 12px;text-align:left;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">SEGMENT</th>
      <th style="padding:8px 12px;text-align:left;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TRAJET</th>
      <th style="padding:8px 12px;text-align:center;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TICKETS</th>
      <th style="padding:8px 12px;text-align:center;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">GRATUITS</th>
      <th style="padding:8px 12px;text-align:right;font-size:11px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">RECETTE</th>
    </tr>
    $segRows
  </table>
</div>
''' : ''}

<!-- ── TICKET DETAIL ── -->
<div style="background:#FFFFFF;border-radius:10px;border:1px solid #E5E7EB;margin-bottom:24px;overflow:hidden">
  <div style="background:#1A3260;padding:12px 16px">
    <span style="color:#FFFFFF;font-weight:700;font-size:13px">Détail des tickets${_tickets.length > 50 ? ' (50 / ${_tickets.length})' : ''}</span>
  </div>
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr style="background:#F9FAFB">
      <th style="padding:7px 10px;text-align:left;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">HEURE</th>
      <th style="padding:7px 10px;text-align:left;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">DÉPART</th>
      <th style="padding:7px 10px;text-align:left;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">ARRIVÉE</th>
      <th style="padding:7px 10px;text-align:center;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">SEG.</th>
      <th style="padding:7px 10px;text-align:left;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TARIF</th>
      <th style="padding:7px 10px;text-align:center;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">QTÉ</th>
      <th style="padding:7px 10px;text-align:right;font-size:10px;color:#6B7280;font-weight:600;border-bottom:1px solid #E5E7EB">TOTAL</th>
    </tr>
    $ticketRows
  </table>
  $moreNote
</div>

<!-- ── FOOTER ── -->
<div style="text-align:center;padding:16px 0;color:#9CA3AF;font-size:11px;border-top:1px solid #E5E7EB">
  Rapport généré automatiquement — Voyage #$id &nbsp;·&nbsp; $dateStr $timeStr
</div>

</div>
</body>
</html>''';
  }

  // ─── Send email & reset ─────────────────────────────────────
  Future<void> _sendEmailAndReset() async {
    final id = widget.voyage['id'] as int?;
    if (id == null || _tickets.isEmpty) {
      _showToast('Aucun ticket à envoyer', isInfo: true);
      return;
    }

    final now     = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year}';
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';

    try {
      _showToast('Ouverture de la messagerie…', isInfo: true);

      final email = Email(
        recipients: [kAdminEmail],
        subject:
            '[Rapport Voyage #$id] $depart → $arrivee — $dateStr — $_totalRecette ms',
        body: _buildEmailHtml(),
        isHTML: true,
      );

      await FlutterEmailSender.send(email);

      // ── Reset local data after email app opens ──
      await LocalDatabase.deleteTicketsByVoyage(id);
      _showToast('Email envoyé — voyage réinitialisé ✓');
      setState(() { _tickets = []; });
    } on PlatformException catch (e) {
      if (e.code == 'not_available') {
        _showToast('Aucune application email installée', isError: true);
      } else {
        _showToast('Erreur: ${e.message}', isError: true);
      }
    } catch (e) {
      _showToast('Erreur inattendue: $e', isError: true);
    }
  }

  // ─── Tarif helpers ─────────────────────────────────────────
  Color _tarifColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('gratuit'))                                                return const Color(0xFF16A34A);
    if (t.contains('armee') || t.contains('garde') || t.contains('police'))  return const Color(0xFF1E40AF);
    if (t.contains('douane') || t.contains('ministere'))                      return const Color(0xFF374151);
    if (t.contains('municipalite') || t.contains('scolaire') ||
        t.contains('institution') || t.contains('autre'))                     return const Color(0xFF065F46);
    if (t.contains('abonnement'))                                             return const Color(0xFF0369A1);
    if (t.contains('agent'))                                                  return const Color(0xFF7C3AED);
    if (t.contains('nfc'))                                                    return const Color(0xFF1E40AF);
    if (t.contains('barcode') || t.contains('scan'))                          return const Color(0xFF6B21A8);
    if (t.contains('50') || t.contains('reduit'))                             return const Color(0xFF7C3AED);
    if (t.contains('75'))                                                     return const Color(0xFF7C3AED);
    return navyLight;
  }

  IconData _tarifIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('gratuit'))                           return Icons.card_giftcard_rounded;
    if (t.contains('armee') || t.contains('garde'))      return Icons.shield_rounded;
    if (t.contains('police'))                            return Icons.local_police_rounded;
    if (t.contains('douane'))                            return Icons.account_balance_rounded;
    if (t.contains('ministere'))                         return Icons.domain_rounded;
    if (t.contains('municipalite'))                      return Icons.location_city_rounded;
    if (t.contains('scolaire'))                          return Icons.school_rounded;
    if (t.contains('institution') || t.contains('autre')) return Icons.groups_rounded;
    if (t.contains('abonnement'))                        return Icons.confirmation_number_rounded;
    if (t.contains('agent'))                             return Icons.badge_rounded;
    if (t.contains('nfc'))                               return Icons.nfc_rounded;
    if (t.contains('barcode') || t.contains('scan'))     return Icons.qr_code_2_rounded;
    if (t.contains('reduit'))                            return Icons.discount_rounded;
    return Icons.person_rounded;
  }

  String _formatTime(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  String _formatDay(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return raw; }
  }

  // ════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: surface,
      body: isLoading
          ? Column(children: [
              _buildHeader(depart, arrivee),
              const Expanded(child: Center(child: CircularProgressIndicator(color: navyMid))),
            ])
          : errorMessage != null
              ? Column(children: [
                  _buildHeader(depart, arrivee),
                  Expanded(child: _buildError()),
                ])
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [
                    SliverToBoxAdapter(child: _buildHeader(depart, arrivee)),
                  ],
                  body: TabBarView(
                    controller: _tabs,
                    children: [
                      _TicketsMainTab(key: const ValueKey('tickets'), page: this),
                      _FinanceMainTab(key: const ValueKey('finance'), page: this),
                    ],
                  ),
                ),
    );
  }

  // ─── Header ────────────────────────────────────────────────
  Widget _buildHeader(String depart, String arrivee) {
    return Container(
      width: double.infinity,
      color: navyDark,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _iconBtn(Icons.arrow_back_ios_new, 17, () => Navigator.pop(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Historique du voyage',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: goldLight, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(depart, overflow: TextOverflow.ellipsis, maxLines: 1,
                        style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(Icons.arrow_forward, size: 10, color: Colors.white.withOpacity(0.35)),
                    ),
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle,
                            border: Border.all(color: goldLight, width: 1.5))),
                    const SizedBox(width: 5),
                    Flexible(child: Text(arrivee, overflow: TextOverflow.ellipsis, maxLines: 1,
                        style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.voyage['id'] != null)
              Text('#${widget.voyage['id']}',
                  style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
            const SizedBox(width: 8),
            _iconBtn(Icons.refresh, 18, _fetchAll, iconColor: Colors.white70),
            const SizedBox(width: 6),
            // ── Email & Reset button ──
            GestureDetector(
              onTap: () {
                if (_tickets.isEmpty) {
                  _showToast('Aucun ticket à envoyer', isInfo: true);
                  return;
                }
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Row(children: [
                      Icon(Icons.email_rounded, color: navyMid, size: 20),
                      SizedBox(width: 8),
                      Text('Envoyer à l\'admin',
                          style: TextStyle(fontSize: 16)),
                    ]),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Envoyer le rapport de ${_tickets.length} ticket(s) '
                          '(recette: $_totalRecette ms) à :',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: navyMid.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: navyMid.withOpacity(0.2))),
                          child: Row(children: [
                            const Icon(Icons.email_outlined,
                                size: 14, color: navyMid),
                            const SizedBox(width: 6),
                            Text(kAdminEmail,
                                style: const TextStyle(
                                    color: navyMid,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les données locales seront effacées après l\'envoi.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: navyMid),
                        onPressed: () {
                          Navigator.pop(context);
                          _sendEmailAndReset();
                        },
                        child: const Text('Envoyer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: goldLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: goldLight.withOpacity(0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.email_rounded, color: goldLight, size: 15),
                  SizedBox(width: 5),
                  Text('Envoyer',
                      style: TextStyle(
                          color: goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            indicatorColor: goldLight,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.confirmation_number_outlined, size: 16), text: 'Tickets'),
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Finance'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared micro-widgets ──────────────────────────────────
  Widget sectionLabel(String label) => Text(label.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: Colors.grey.shade500, letterSpacing: 0.5));

  Widget emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 68, height: 68,
              decoration: BoxDecoration(color: navyMid.withOpacity(0.07), shape: BoxShape.circle),
              child: Icon(icon, color: navyMid, size: 30)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: navyDark)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData? icon, double size, VoidCallback? onTap,
      {EdgeInsets margin = EdgeInsets.zero, bool loading = false, Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: loading
            ? SizedBox(width: size, height: size,
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: iconColor, size: size),
      ),
    );
  }

  Widget smallTag(IconData icon, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withOpacity(0.22))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget vDivider() => Container(
      width: 0.5, color: const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(vertical: 8));

  Widget tarifStat(String value, String label, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color ?? navyDark)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, color: Colors.red.shade400, size: 44)),
          const SizedBox(height: 16),
          Text(errorMessage!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 24),
          SizedBox(
            height: 46,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _fetchAll,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(color: navyMid, borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Réessayer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Main Tab 1 — TICKETS
// ════════════════════════════════════════════════════

class _TicketsMainTab extends StatefulWidget {
  final _HistoriquePageState page;
  const _TicketsMainTab({super.key, required this.page});

  @override
  State<_TicketsMainTab> createState() => _TicketsMainTabState();
}

class _TicketsMainTabState extends State<_TicketsMainTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() { super.initState(); _sub = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return Column(children: [
      Container(
        color: navyDark,
        child: TabBar(
          controller: _sub,
          indicatorColor: goldLight,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'Liste'), Tab(text: 'Par segment')],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _sub,
          children: [_buildListeTab(p), _buildSegmentTab(p)],
        ),
      ),
    ]);
  }

  Widget _buildListeTab(_HistoriquePageState p) {
    if (p._tickets.isEmpty) {
      return p.emptyState(Icons.confirmation_number_outlined,
          'Aucun ticket', 'Les tickets de ce voyage apparaîtront ici');
    }
    return RefreshIndicator(
      color: navyMid,
      onRefresh: p._fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: _buildTicketsByDay(p),
      ),
    );
  }

  List<Widget> _buildTicketsByDay(_HistoriquePageState p) {
    final widgets = <Widget>[];
    String? lastDay;
    for (int i = 0; i < p._tickets.length; i++) {
      final t   = p._tickets[i] as Map<String, dynamic>;
      final day = p._formatDay(t['date_heure']);
      if (day != lastDay) {
        lastDay = day;
        if (i > 0) widgets.add(const SizedBox(height: 8));
        widgets.add(_dayChip(day));
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(_buildTicketCard(p, t));
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _dayChip(String day) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: navyMid.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: navyMid.withOpacity(0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today, size: 11, color: navyMid),
          const SizedBox(width: 6),
          Text(day, style: const TextStyle(color: navyMid, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: navyMid.withOpacity(0.1))),
    ]);
  }

  Widget _buildTicketCard(_HistoriquePageState p, Map<String, dynamic> t) {
    final type   = (t['type_tarif'] ?? '').toString();
    final color  = p._tarifColor(type);
    final isFree = ((t['montant_total'] as num? ?? 0).toInt()) == 0;
    final qty    = (t['quantite'] as num? ?? 1).toInt();
    final rawSeg = t['segment_ordre'];
    final seg    = rawSeg == null ? null : () {
      final s = rawSeg.toString().trim();
      return (s.isEmpty || s == 'null') ? null : s;
    }();

    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: navyMid.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.12))),
          ),
          child: Row(children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p._tarifIcon(type), color: Colors.white, size: 12),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(type.isEmpty ? 'Inconnu' : type,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            if (t['_statut_sync'] == 'pending')
              _syncBadge(Colors.orange.shade600, Icons.sync, 'En attente')
            else if (t['_statut_sync'] == 'failed')
              _syncBadge(Colors.red.shade600, Icons.sync_problem, 'Échec sync'),
            Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(p._formatTime(t['date_heure']),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (qty > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: navyMid.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: navyMid.withOpacity(0.15))),
                child: Text('×$qty',
                    style: const TextStyle(color: navyMid, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(t['point_depart'] ?? '', overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyDark))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade300),
                  ),
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade400, width: 1.8))),
                  const SizedBox(width: 6),
                  Flexible(child: Text(t['point_arrivee'] ?? '', overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navyDark))),
                ]),
                if (seg != null || t['nom_ligne'] != null) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (seg != null)
                      p.smallTag(Icons.route, 'Seg. $seg', navyMid, navyMid.withOpacity(0.07)),
                    if (t['nom_ligne'] != null)
                      p.smallTag(Icons.directions_bus, t['nom_ligne'],
                          Colors.grey.shade500, Colors.grey.shade50),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (qty > 1)
                Text('${t['prix_unitaire']} ms/ticket',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(height: 2),
              Text(
                isFree ? 'GRATUIT' : '${t['montant_total']}',
                style: TextStyle(
                    fontSize: isFree ? 15 : 22,
                    fontWeight: FontWeight.bold,
                    color: isFree ? const Color(0xFF16A34A) : navyDark),
              ),
              if (!isFree)
                Text('millimes', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _syncBadge(Color bg, IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 10),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSegmentTab(_HistoriquePageState p) {
    final segs     = p._segmentBreakdown;
    final realSegs = Map.fromEntries(segs.entries.where((e) => e.key != '—'));

    if (realSegs.isEmpty) {
      return p.emptyState(Icons.route, 'Aucun segment disponible',
          'Les informations de segment ne sont pas disponibles pour ce voyage');
    }

    String? bestSeg;
    int bestRev = -1;
    for (final e in realSegs.entries) {
      final rev = e.value.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
      if (rev > bestRev) { bestRev = rev; bestSeg = e.key; }
    }

    return RefreshIndicator(
      color: navyMid,
      onRefresh: p._fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: navyDark, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.route, color: goldLight, size: 16),
              const SizedBox(width: 8),
              Text('${realSegs.length} segment(s) actifs',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${p._totalTickets} tickets · ${p._totalRecette} ms',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
            ]),
          ),
          p.sectionLabel('Recette par segment'),
          const SizedBox(height: 10),
          ...realSegs.entries.map((e) => _buildSegmentCard(p, e)).toList(),
          if (segs.containsKey('—')) ...[
            const SizedBox(height: 4),
            _buildSegmentCard(p, segs.entries.firstWhere((e) => e.key == '—')),
          ],
          if (bestSeg != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: navyMid.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: navyMid.withOpacity(0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, color: goldLight, size: 16),
                const SizedBox(width: 8),
                Text('Segment le + rentable : seg. $bestSeg',
                    style: const TextStyle(fontSize: 12, color: navyMid, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$bestRev ms',
                    style: const TextStyle(fontSize: 12, color: navyDark, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentCard(_HistoriquePageState p, MapEntry<String, List<dynamic>> e) {
    final tickets   = e.value;
    final recette   = tickets.fold(0, (s, t) => s + ((t['montant_total'] as num? ?? 0).toInt()));
    final count     = tickets.fold(0, (s, t) => s + ((t['quantite']     as num? ?? 1).toInt()));
    final gratuits  = tickets
        .where((t) => ((t['montant_total'] as num? ?? 0).toInt()) == 0)
        .fold(0, (s, t) => s + ((t['quantite'] as num? ?? 1).toInt()));
    final dep       = tickets.isNotEmpty ? tickets.first['point_depart']  ?? '' : '';
    final arr       = tickets.isNotEmpty ? tickets.first['point_arrivee'] ?? '' : '';
    final isUnknown = e.key == '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: navyMid.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: (isUnknown ? Colors.grey : navyMid).withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: (isUnknown ? Colors.grey : navyMid).withOpacity(0.1))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: (isUnknown ? Colors.grey : navyMid).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (isUnknown ? Colors.grey : navyMid).withOpacity(0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isUnknown ? Icons.help_outline : Icons.route,
                    color: isUnknown ? Colors.grey : navyMid, size: 12),
                const SizedBox(width: 5),
                Text(isUnknown ? 'Non classé' : 'Segment ${e.key}',
                    style: TextStyle(color: isUnknown ? Colors.grey : navyMid,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            if (dep.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(child: Text('$dep → $arr', overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
            ] else
              const Spacer(),
            Text('$recette ms',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyDark)),
          ]),
        ),
        IntrinsicHeight(
          child: Row(children: [
            p.tarifStat('$recette', 'ms recette'),
            p.vDivider(),
            p.tarifStat('$count', 'tickets'),
            p.vDivider(),
            p.tarifStat('$gratuits', 'gratuits',
                color: gratuits > 0 ? const Color(0xFF16A34A) : Colors.grey.shade400),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// Main Tab 2 — FINANCE
// ════════════════════════════════════════════════════

class _FinanceMainTab extends StatefulWidget {
  final _HistoriquePageState page;
  const _FinanceMainTab({super.key, required this.page});

  @override
  State<_FinanceMainTab> createState() => _FinanceMainTabState();
}

class _FinanceMainTabState extends State<_FinanceMainTab>
    with SingleTickerProviderStateMixin {
  late TabController _sub;

  @override
  void initState() { super.initState(); _sub = TabController(length: 3, vsync: this); }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return Column(children: [
      Container(
        color: navyDark,
        child: TabBar(
          controller: _sub,
          indicatorColor: goldLight,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Aperçu'),
            Tab(text: 'Par tarif'),
            Tab(text: 'Bilan'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _sub,
          children: [_buildApercuTab(p), _buildParTarifTab(p), _buildBilanTab(p)],
        ),
      ),
    ]);
  }

  Widget _buildApercuTab(_HistoriquePageState p) {
    final gratuitPct = p._totalTickets > 0
        ? '${((p._totalGratuits / p._totalTickets) * 100).round()}%'
        : '0%';

    return RefreshIndicator(
      color: navyMid,
      onRefresh: p._fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Column(children: [
            Row(children: [
              Expanded(child: _kpiCard('Recette totale', '${p._totalRecette} ms',
                  sub: 'millimes DT', color: goldLight, icon: Icons.payments_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Tickets vendus', '${p._totalTickets}',
                  sub: 'ce voyage', color: const Color(0xFF86EFAC),
                  icon: Icons.confirmation_number_rounded)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _kpiCard('Prix moyen', '${p._prixMoyen} ms',
                  sub: 'ticket payant', color: Colors.lightBlue.shade200,
                  icon: Icons.trending_up_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Gratuits', '${p._totalGratuits}',
                  sub: gratuitPct, color: Colors.green.shade300,
                  icon: Icons.card_giftcard_rounded)),
            ]),
          ]),
          const SizedBox(height: 24),
          if (p._tarifBreakdown.isNotEmpty) ...[
            p.sectionLabel('Répartition des recettes'),
            const SizedBox(height: 10),
            _buildTarifBar(p),
            const SizedBox(height: 24),
            p.sectionLabel('Recette par tarif'),
            const SizedBox(height: 10),
            ..._buildTarifRows(p),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value,
      {String? sub, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: navyDark, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(label, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
                if (sub != null)
                  Text(sub, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
              ]),
        ),
      ]),
    );
  }

  Widget _buildTarifBar(_HistoriquePageState p) {
    final breakdown = p._tarifBreakdown;
    final total     = p._totalRecette.clamp(1, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: breakdown.entries.map((e) {
                final frac = e.value['total']! / total;
                return Flexible(
                  flex: (frac * 1000).round().clamp(1, 1000),
                  child: Container(color: p._tarifColor(e.key).withOpacity(0.85)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12, runSpacing: 5,
          children: breakdown.entries.map((e) {
            final c = p._tarifColor(e.key);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('${e.key} · ${e.value['total']} ms',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildTarifRows(_HistoriquePageState p) {
    final breakdown = p._tarifBreakdown;
    final maxTotal  = breakdown.values.map((v) => v['total']!).fold(1, (a, b) => a > b ? a : b);

    return breakdown.entries.map((e) {
      final color  = p._tarifColor(e.key);
      final isFree = e.value['total']! == 0;
      final frac   = maxTotal == 0 ? 0.0 : e.value['total']! / maxTotal;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
            width: 115,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Icon(p._tarifIcon(e.key), color: Colors.white, size: 12),
                const SizedBox(width: 5),
                Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8, color: navyMid.withOpacity(0.07),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac.clamp(0.02, 1.0),
                  child: Container(decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 30,
              child: Text('×${e.value['count']}', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(isFree ? '0 dt' : '${e.value['total']} dt',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: isFree ? const Color(0xFF16A34A) : navyDark)),
          ),
        ]),
      );
    }).toList();
  }

  Widget _buildParTarifTab(_HistoriquePageState p) {
    final breakdown = p._tarifBreakdown;
    if (breakdown.isEmpty) {
      return p.emptyState(Icons.label_outline, 'Aucun tarif',
          'Les données de tarif apparaîtront ici');
    }
    return RefreshIndicator(
      color: navyMid,
      onRefresh: p._fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          p.sectionLabel('Détail financier par tarif'),
          const SizedBox(height: 10),
          ...breakdown.entries.map((e) => _buildTarifDetailCard(p, e)).toList(),
        ],
      ),
    );
  }

  Widget _buildTarifDetailCard(_HistoriquePageState p, MapEntry<String, Map<String, int>> e) {
    final color    = p._tarifColor(e.key);
    final isFree   = e.value['total']! == 0;
    final unitaire = e.value['unitaire'] ?? 0;
    final pct      = p._totalTickets > 0
        ? '${((e.value['count']! / p._totalTickets) * 100).round()}%'
        : '0%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardWhite, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: navyMid.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.12))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(p._tarifIcon(e.key), color: Colors.white, size: 12),
                const SizedBox(width: 5),
                Text(e.key, style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Spacer(),
            Text(isFree ? '0 ms' : '${e.value['total']} ms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: isFree ? const Color(0xFF16A34A) : color)),
          ]),
        ),
        IntrinsicHeight(
          child: Row(children: [
            p.tarifStat('${e.value['count']}', 'tickets'),
            p.vDivider(),
            p.tarifStat(isFree ? '—' : '$unitaire', 'prix unitaire (ms)',
                color: isFree ? const Color(0xFF16A34A) : null),
            p.vDivider(),
            p.tarifStat(pct, 'du total voyageurs', color: color),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBilanTab(_HistoriquePageState p) {
    final payants   = p._totalTickets - p._totalGratuits;
    final breakdown = p._tarifBreakdown;

    int manqueAGagner = 0;
    for (final e in breakdown.entries) {
      if (e.value['total']! == 0 && p._prixMoyen > 0) {
        manqueAGagner += e.value['count']! * p._prixMoyen;
      }
    }

    return RefreshIndicator(
      color: navyMid,
      onRefresh: p._fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: navyDark, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('Recette totale du voyage',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              Text('${p._totalRecette} ms',
                  style: const TextStyle(color: goldLight, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('≈ ${(p._totalRecette / 1000).toStringAsFixed(3)} DT',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),
          _bilanRow('Tickets payants',      '$payants',           navyDark),
          _bilanRow('Tickets gratuits',     '${p._totalGratuits}', const Color(0xFF16A34A)),
          _bilanRow('Total voyageurs',      '${p._totalTickets}',  navyMid),
          _bilanRow('Prix moyen (payants)', '${p._prixMoyen} ms',  Colors.lightBlue.shade600),
          const SizedBox(height: 16),
          Divider(color: navyMid.withOpacity(0.1)),
          const SizedBox(height: 16),
          p.sectionLabel('Analyse des gratuités'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardWhite, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Manque à gagner estimé',
                    style: TextStyle(fontSize: 13, color: navyDark)),
                Text('$manqueAGagner ms',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626))),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Taux de gratuité',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(
                  p._totalTickets > 0
                      ? '${((p._totalGratuits / p._totalTickets) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600),
                ),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(children: [
                    Flexible(
                      flex: (payants * 100).clamp(1, 10000),
                      child: Container(color: navyMid),
                    ),
                    Flexible(
                      flex: (p._totalGratuits * 100).clamp(1, 10000),
                      child: Container(color: const Color(0xFF16A34A).withOpacity(0.5)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: navyMid, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Payants ($payants)',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 14),
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.5),
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Gratuits (${p._totalGratuits})',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          p.sectionLabel('Types de tarif utilisés'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: breakdown.entries.map((e) {
              final c = p._tarifColor(e.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p._tarifIcon(e.key), color: c, size: 13),
                  const SizedBox(width: 6),
                  Text(e.key, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('${e.value['count']}×',
                      style: TextStyle(fontSize: 11, color: c.withOpacity(0.7))),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _bilanRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ]),
    );
  }
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
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) _ctrl.reverse();
    });
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
                boxShadow: [BoxShadow(
                    color: widget.color.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(widget.msg,
                      style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600, height: 1.3)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}