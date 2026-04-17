import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../../../data/database/daos/log_dao.dart';
import '../../../services/sync_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/language_switcher.dart';

// ── Palette ───────────────────────────────────────────────────
const Color _dark0   = Color(0xFF0B1120);
const Color _dark1   = Color(0xFF111827);
const Color _dark2   = Color(0xFF1C2A3A);
const Color _dark3   = Color(0xFF243347);

const Color _clrOk      = Color(0xFF22C55E);
const Color _clrErr     = Color(0xFFEF4444);
const Color _clrPending = Color(0xFFD97706);
const Color _clrInfo    = Color(0xFF60A5FA);

class SyncLogPage extends StatefulWidget {
  final Map<String, dynamic> agent;
  const SyncLogPage({super.key, required this.agent});

  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

class _SyncLogPageState extends State<SyncLogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _logs    = [];
  bool    _loading     = false;
  String? _syncMessage;

  int get _matricule =>
      widget.agent['matricule_agent'] as int? ??
      widget.agent['matricule']       as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final allTickets = await TicketDao.getAllTickets();
    final allLogs    = await LogDao.getLogs();
    _tickets = allTickets
        .where((t) => t['matricule_agent'] == _matricule)
        .take(50)
        .toList();
    _logs = allLogs
        .where((l) => l['matricule_agent'] == _matricule)
        .take(50)
        .toList();
    setState(() => _loading = false);
  }

  Future<void> _manualSync() async {
    final t = AppLocalizations.of(context)!;
    setState(() { _loading = true; _syncMessage = null; });
    final result = await SyncService.syncPending();
    await _load();
    setState(() {
      _syncMessage = t.syncResultat(result.synced, result.failed);
    });
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'synced': return _clrOk;
      case 'failed': return _clrErr;
      default:       return _clrPending;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'synced': return Icons.cloud_done_outlined;
      case 'failed': return Icons.cloud_off_outlined;
      default:       return Icons.cloud_upload_outlined;
    }
  }

  String _statusLabel(String? s, AppLocalizations t) {
    switch (s) {
      case 'synced': return t.statusSynced;
      case 'failed': return t.statusFailed;
      default:       return t.statusPending;
    }
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}:'
             '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) { return raw; }
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final pending = _tickets.where((t) => t['statut_sync'] == 'pending').length;
    final failed  = _tickets.where((t) => t['statut_sync'] == 'failed').length;
    final synced  = _tickets.where((t) => t['statut_sync'] == 'synced').length;
    final total   = _tickets.length;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(children: [
        _buildHeader(t, pending, failed, synced, total),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _clrInfo))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildQueueTab(t, pending, failed),
                    _buildRequestsTab(t),
                    _buildConsoleTab(t),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _buildHeader(AppLocalizations t, int pending, int failed, int synced, int total) {
    final successRate = total == 0 ? 0 : (synced / total * 100).round();

    return Container(
      width: double.infinity,
      color: _dark1,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.journauxSyncTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  )),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: pending > 0 ? _clrPending : _clrOk,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  pending > 0
                      ? t.requetesEnAttente(pending)
                      : t.reseauOperationnel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ]),
            ]),
          ),
          GestureDetector(
            onTap: _loading ? null : _manualSync,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _clrInfo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _clrInfo.withOpacity(0.3)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: _clrInfo, strokeWidth: 2))
                  : const Icon(Icons.sync, color: _clrInfo, size: 18),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        Row(children: [
          _kpi(t.kpiOk,           '$synced',        _clrOk),
          _kpiDivider(),
          _kpi(t.kpiErreur,       '$failed',        _clrErr),
          _kpiDivider(),
          _kpi(t.kpiEnFile,       '$pending',       _clrPending),
          _kpiDivider(),
          _kpi(t.kpiTauxReussite, '$successRate%',  _clrInfo),
        ]),

        const SizedBox(height: 14),

        if (_syncMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _dark2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _dark3),
            ),
            child: Row(children: [
              const Icon(Icons.terminal, color: _clrInfo, size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_syncMessage!,
                    style: const TextStyle(
                        color: _clrInfo,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ),
            ]),
          ),

        TabBar(
          controller: _tabs,
          indicatorColor: _clrInfo,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            Tab(text: t.tabFileAttente),
            Tab(text: t.tabRequetesHttp),
            Tab(text: t.tabConsole),
          ],
        ),
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
              color: color, fontSize: 20,
              fontWeight: FontWeight.bold, fontFamily: 'monospace',
            )),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 9, letterSpacing: 0.3,
            )),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _kpiDivider() => Container(
      width: 0.5, height: 32, color: Colors.white.withOpacity(0.1));

  Widget _buildQueueTab(AppLocalizations t, int pending, int failed) {
    final queue = _tickets
        .where((t) => t['statut_sync'] == 'pending' || t['statut_sync'] == 'failed')
        .toList();

    if (queue.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: _clrOk.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: _clrOk, size: 30)),
          const SizedBox(height: 12),
          Text(t.fileAttenteVide,
              style: const TextStyle(
                color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(t.tousTicketsSynchronises,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 13)),
        ]),
      );
    }

    return Container(
      color: _dark0,
      child: RefreshIndicator(
        color: _clrInfo,
        backgroundColor: _dark2,
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: queue.length,
          itemBuilder: (_, i) => _buildQueueCard(t, queue[i]),
        ),
      ),
    );
  }

  Widget _buildQueueCard(AppLocalizations t, Map<String, dynamic> ticket) {
    final status    = ticket['statut_sync'] as String? ?? 'pending';
    final color     = _statusColor(status);
    final erreur    = ticket['erreur'] as String?;
    final isPending = status == 'pending';
    final retries   = ticket['tentatives'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _dark2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_statusIcon(status), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ticket['point_depart']} → ${ticket['point_arrivee']}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      _monoChip(
                        isPending ? t.statusPending.toUpperCase() : t.statusFailed.toUpperCase(),
                        color,
                      ),
                      Text(
                        '${ticket['quantite']} ticket(s) · ${ticket['montant_total']} DT',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (retries > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _clrErr.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _clrErr.withOpacity(0.3)),
                ),
                child: Text(
                  t.retryLabel(retries),
                  style: const TextStyle(
                    color: _clrErr, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ]),
        ),
        if (erreur != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _clrErr.withOpacity(0.07),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _clrErr.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: _clrErr, size: 12),
              const SizedBox(width: 6),
              Flexible(
                child: Text(erreur,
                    style: const TextStyle(
                      color: _clrErr, fontSize: 11,
                      fontFamily: 'monospace', fontStyle: FontStyle.italic,
                    )),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _buildRequestsTab(AppLocalizations t) {
    if (_logs.isEmpty) {
      return Container(
        color: _dark0,
        child: Center(
          child: Text(t.aucuneRequete,
              style: const TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      color: _dark0,
      child: RefreshIndicator(
        color: _clrInfo,
        backgroundColor: _dark2,
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: _logs.length,
          itemBuilder: (_, i) => _buildRequestCard(_logs[i]),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> l) {
    final status   = l['statut'] as String? ?? 'pending';
    final color    = _statusColor(status);
    final date     = DateTime.tryParse(l['date_tentative'] ?? '');
    final timeStr  = date != null ? _fmtTime(l['date_tentative']) : '—';
    final dateStr  = date != null ? _fmtDate(l['date_tentative']) : '—';
    final message  = l['message'] as String? ?? '';
    final httpCode = status == 'synced' ? '200' : status == 'failed' ? '503' : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: _dark2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _dark3),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text('POST',
                  style: TextStyle(
                    color: color, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold,
                  )),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '/billetterie/tickets/vendre',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11, fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(httpCode,
                  style: TextStyle(
                    color: color, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold,
                  )),
            ),
          ]),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _dark0.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12, runSpacing: 4,
                children: [
                  _metaItem(Icons.route,
                      '${l['point_depart']} → ${l['point_arrivee']}'),
                  _metaItem(Icons.access_time_rounded, timeStr),
                  _metaItem(Icons.calendar_today, dateStr),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10, fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: Colors.white38),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(
        color: Colors.white38, fontSize: 10, fontFamily: 'monospace',
      )),
    ]);
  }

  Widget _buildConsoleTab(AppLocalizations t) {
    return Container(
      color: _dark0,
      child: RefreshIndicator(
        color: _clrInfo,
        backgroundColor: _dark2,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF080F1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dark3),
              ),
              child: Column(children: [
                // Title bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: const BoxDecoration(
                    color: _dark2,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: _dark3)),
                  ),
                  child: Row(children: [
                    _dot(const Color(0xFFFF5F56)),
                    const SizedBox(width: 6),
                    _dot(const Color(0xFFFFBD2E)),
                    const SizedBox(width: 6),
                    _dot(const Color(0xFF27C93F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.syncConsoleTitle(_logs.length),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _load,
                      child: Icon(Icons.refresh,
                          size: 15, color: Colors.white.withOpacity(0.35)),
                    ),
                  ]),
                ),
                // Log lines
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _logs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(t.aucunLogDisponible,
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 12, fontFamily: 'monospace',
                              )),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _logs.map((l) {
                            final status = l['statut'] as String? ?? '';
                            final date   = DateTime.tryParse(l['date_tentative'] ?? '');
                            final ts = date != null
                                ? '${date.hour.toString().padLeft(2, '0')}:'
                                  '${date.minute.toString().padLeft(2, '0')}:'
                                  '${date.second.toString().padLeft(2, '0')}'
                                : '??:??:??';
                            final msg   = l['message'] ?? '';
                            final route = '${l['point_depart']} → ${l['point_arrivee']}';

                            Color lineColor;
                            String prefix;
                            switch (status) {
                              case 'synced': lineColor = _clrOk;      prefix = '✓'; break;
                              case 'failed': lineColor = _clrErr;     prefix = '✗'; break;
                              default:       lineColor = _clrPending;  prefix = '·';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ts, style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 10, fontFamily: 'monospace',
                                  )),
                                  const SizedBox(width: 10),
                                  Text(prefix, style: TextStyle(
                                    color: lineColor, fontSize: 11,
                                    fontFamily: 'monospace', fontWeight: FontWeight.bold,
                                  )),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                          text: route,
                                          style: TextStyle(
                                            color: lineColor.withOpacity(0.9),
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (msg.isNotEmpty)
                                          TextSpan(
                                            text: '  $msg',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.35),
                                              fontSize: 10, fontFamily: 'monospace',
                                            ),
                                          ),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Tickets summary
            Container(
              decoration: BoxDecoration(
                color: _dark2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dark3),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _dark3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.storage_rounded, color: _clrInfo, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      t.ticketsLocaux(_tickets.length),
                      style: const TextStyle(
                        color: _clrInfo, fontSize: 12,
                        fontFamily: 'monospace', fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
                if (_tickets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(t.aucunTicketLocal,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12, fontFamily: 'monospace',
                        )),
                  )
                else
                  ..._tickets.map((ticket) => _buildConsoleTicketRow(t, ticket)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleTicketRow(AppLocalizations t, Map<String, dynamic> ticket) {
    final status = ticket['statut_sync'] as String? ?? 'pending';
    final color  = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _dark3, width: 0.5)),
      ),
      child: Row(children: [
        Icon(_statusIcon(status), color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${ticket['point_depart']} → ${ticket['point_arrivee']}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70, fontSize: 11, fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${ticket['quantite']}× · ${ticket['montant_total']} DT',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 10, fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 10),
        _monoChip(_statusLabel(status, t), color),
      ]),
    );
  }

  Widget _monoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color, fontSize: 9,
            fontFamily: 'monospace', fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          )),
    );
  }

  Widget _dot(Color color) => Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}