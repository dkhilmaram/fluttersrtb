import 'package:flutter/material.dart';
import 'local_database.dart';
import 'sync_service.dart';

const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

class SyncLogPage extends StatefulWidget {
  const SyncLogPage({super.key});
  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

class _SyncLogPageState extends State<SyncLogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _logs    = [];
  bool _loading = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tickets = await LocalDatabase.getAllTickets();
    _logs    = await LocalDatabase.getLogs();
    setState(() => _loading = false);
  }

  Future<void> _manualSync() async {
    setState(() { _loading = true; _syncMessage = null; });
    final result = await SyncService.syncPending();
    await _load();
    setState(() {
      _syncMessage =
          '✓ ${result.synced} synchronisés   ✗ ${result.failed} échoués';
    });
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'synced':  return const Color(0xFF16A34A);
      case 'failed':  return Colors.red.shade600;
      default:        return Colors.orange.shade700;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'synced':  return Icons.cloud_done_outlined;
      case 'failed':  return Icons.cloud_off_outlined;
      default:        return Icons.cloud_upload_outlined;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'synced':  return 'Synchronisé';
      case 'failed':  return 'Échoué';
      default:        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tickets.where((t) => t['statut_sync'] == 'pending').length;
    final failed  = _tickets.where((t) => t['statut_sync'] == 'failed').length;
    final synced  = _tickets.where((t) => t['statut_sync'] == 'synced').length;

    return Scaffold(
      backgroundColor: surface,
      body: Column(children: [

        // ── Header ──
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [navyDark, navyMid, navyLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
          child: Column(children: [
            Row(children: [
              GestureDetector(
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
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Journaux de Synchronisation',
                    style: TextStyle(color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.white),
                tooltip: 'Synchroniser maintenant',
                onPressed: _manualSync,
              ),
            ]),
            const SizedBox(height: 16),

            // ── Stats row ──
            Row(children: [
              _headerStat('En attente', '$pending', Colors.orange.shade300),
              _headerStat('Échoués',    '$failed',  Colors.red.shade300),
              _headerStat('Synchronisés','$synced', const Color(0xFF86EFAC)),
            ]),
            const SizedBox(height: 12),

            if (_syncMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_syncMessage!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),

            TabBar(
              controller: _tabs,
              indicatorColor: const Color(0xFFF5C842),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Tickets locaux'),
                Tab(text: 'Journal'),
              ],
            ),
          ]),
        ),

        // ── Tab content ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: navyMid))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _ticketsList(),
                    _logsList(),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _ticketsList() {
    if (_tickets.isEmpty) {
      return const Center(
          child: Text('Aucun ticket local',
              style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _tickets.length,
        itemBuilder: (_, i) {
          final t = _tickets[i];
          final color = _statusColor(t['statut_sync'] as String?);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(t['statut_sync'] as String?),
                    color: color, size: 20),
              ),
              title: Text(
                '${t['point_depart']} → ${t['point_arrivee']}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t['quantite']} ticket(s) · ${t['montant_total']} DT',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (t['erreur'] != null)
                    Text(t['erreur'],
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(t['statut_sync'] as String?),
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _logsList() {
    if (_logs.isEmpty) {
      return const Center(
          child: Text('Aucune entrée de journal',
              style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _logs.length,
        itemBuilder: (_, i) {
          final l = _logs[i];
          final color = _statusColor(l['statut'] as String?);
          final date  = DateTime.tryParse(l['date_tentative'] ?? '');
          final dateStr = date != null
              ? '${date.day}/${date.month}/${date.year} '
                '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}'
              : '—';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(_statusIcon(l['statut'] as String?),
                  color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l['point_depart']} → ${l['point_arrivee']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    Text(l['message'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              Text(dateStr,
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 10)),
            ]),
          );
        },
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10)),
        const SizedBox(height: 4),
      ]),
    );
  }
}