import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../core/constants/api_constants.dart';
import '../data/database/daos/ticket_dao.dart';
import '../data/database/daos/voyage_dao.dart';
import '../data/database/daos/log_dao.dart';
import '../data/database/local_database.dart';
import 'connectivity_service.dart';

class SyncService {
  SyncService._();

  static bool _isSyncing = false;
  static Timer? _heartbeatTimer;
  static int? _cachedMatricule;

  // ── Initialisation ─────────────────────────────────────────────────────────

  static void startListening() {
    ConnectivityService.startListening(
      onReconnect: () async {
        await Future.delayed(const Duration(seconds: 2));
        await flushHeartbeatQueue();
        await syncPending();
      },
      onDisconnect: () async {
        final pending = await TicketDao.getUnsyncedTickets();
        final failed  = await _countFailed();
        await _pushHeartbeat(pending: pending.length, failed: failed);
      },
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final pending = await TicketDao.getUnsyncedTickets();
      final failed  = await _countFailed();
      await _pushHeartbeat(pending: pending.length, failed: failed);
    });
  }

  static void setMatricule(int matricule) {
    _cachedMatricule = matricule;
  }

  // ── Main sync entry point ──────────────────────────────────────────────────

  static Future<SyncResult> syncPending() async {
    if (_isSyncing) return const SyncResult(synced: 0, failed: 0);
    _isSyncing = true;

    int synced = 0, failed = 0;

    try {
      // ── 1. Sync pending tickets ──────────────────────────────────────────
      final toSync = await TicketDao.getUnsyncedTickets();
      print('🔄 Syncing ${toSync.length} unsynced tickets...');

      for (final ticket in toSync) {
        final localId = ticket['id'] as int;

        if (_cachedMatricule == null && ticket['matricule_agent'] != null) {
          _cachedMatricule = (ticket['matricule_agent'] as num).toInt();
        }

        try {
          final response = await http
              .post(
                Uri.parse(ApiConstants.vendreTicket),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id_voyage':       ticket['id_voyage'],
                  'id_segment':      0,            // server resolves from point_depart
                  'point_depart':    ticket['point_depart'],
                  'point_arrivee':   ticket['point_arrivee'],
                  'type_tarif':      ticket['type_tarif'],
                  'quantite':        (ticket['quantite'] as num).toInt(),
                  'prix_unitaire':   (ticket['prix_unitaire'] as num).toInt(),
                  'montant_total':   (ticket['montant_total'] as num).toInt(),
                  'matricule_agent': ticket['matricule_agent'],
                  'numero_titre':    ticket['numero_titre'],
                  'nom_titulaire':   ticket['nom_titulaire'],
                  'organisme':       ticket['organisme'],
                  'ligne_titre':     ticket['ligne_titre'],
                  'sync_status':     'synced',
                }),
              )
              .timeout(ApiConstants.defaultTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              await TicketDao.markSynced(localId, data['id_ticket'] as int);
              await LogDao.insertLog(
                idTicketLocal: localId,
                statut: 'synced',
                message: 'Synchronisé avec succès (restauration réseau)',
              );
              print('✅ Ticket $localId synced → server id: ${data['id_ticket']}');
              synced++;
            } else {
              throw Exception(data['error'] ?? 'Réponse serveur invalide');
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print('❌ Ticket $localId failed: $e');
          await TicketDao.markFailed(localId, e.toString());
          await LogDao.insertLog(
            idTicketLocal: localId,
            statut: 'failed',
            message: e.toString(),
          );
          failed++;
        }
      }

      // ── 2. Sync pending voyage clôtures ───────────────────────────────────
      if (failed > 0) {
        print('⚠️ Skipping voyage clôtures — $failed ticket(s) still unsynced');
      } else {
        final pendingClotures = await VoyageDao.getPendingClotures();
        print('🔄 Syncing ${pendingClotures.length} pending voyage clôtures...');

        for (final cloture in pendingClotures) {
          final idVente = cloture['id_voyage'] as int;
          try {
            final response = await http
                .put(
                  Uri.parse(ApiConstants.cloturerVoyage(idVente)),
                  headers: {'Content-Type': 'application/json'},
                )
                .timeout(ApiConstants.defaultTimeout);

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['success'] == true) {
                await VoyageDao.markClotureSynced(idVente);
                await VoyageDao.saveVoyageStatut(
                  idVente,
                  'cloture',
                  serverStatut: 'cloture',
                );
                print('✅ Voyage clôture synced for vente $idVente');
              } else {
                print('⚠️ Voyage clôture rejected by server for vente '
                    '$idVente: ${data['message']}');
              }
            } else {
              print('⚠️ Voyage clôture HTTP error for vente $idVente: '
                  '${response.statusCode}');
            }
          } catch (e) {
            print('❌ Voyage clôture sync failed for vente $idVente: $e');
          }
        }
      }

      // ── 3. Sync pending reopens ───────────────────────────────────────────
      final pendingReopens = await VoyageDao.getPendingReopens();
      print('🔄 Syncing ${pendingReopens.length} pending reopens...');

      for (final reopen in pendingReopens) {
        final idVente = reopen['id_voyage'] as int;
        final scope   = reopen['scope'] as String? ?? 'single';

        try {
          final response = await http
              .put(
                Uri.parse(ApiConstants.reopenVoyage(idVente)),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(ApiConstants.defaultTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              await VoyageDao.markReopenSynced(idVente);
              await VoyageDao.clearVoyageStatut(idVente);
              print('✅ Reopen synced for vente $idVente (scope=$scope)');
            } else {
              await VoyageDao.markReopenFailed(idVente);
              print('⚠️ Reopen rejected by server for vente $idVente: '
                  '${data['message']}');
            }
          } else {
            print('⚠️ Reopen HTTP error for vente $idVente: '
                '${response.statusCode}');
          }
        } catch (e) {
          print('❌ Reopen sync failed for vente $idVente: $e');
        }
      }

      // ── 4. Sync pending scan validation logs ──────────────────────────────
      final pendingScans = await TicketDao.getUnsyncedScanLogs();
      print('🔄 Syncing ${pendingScans.length} pending scan logs...');

      for (final scan in pendingScans) {
        final localId = scan['id'] as int;

        if (_cachedMatricule == null && scan['matricule_agent'] != null) {
          _cachedMatricule = (scan['matricule_agent'] as num).toInt();
        }

        try {
          final response = await http
              .post(
                Uri.parse(ApiConstants.logScan),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id_voyage':       scan['id_voyage'],
                  'id_segment':      0,            // server resolves from point_depart
                  'scan_mode':       scan['scan_mode'],
                  'numero_titre':    scan['numero_titre'],
                  'nom_titulaire':   scan['nom_titulaire'],
                  'type_abonnement': scan['type_abonnement'],
                  'organisme':       scan['organisme'],
                  'ligne_titre':     scan['ligne_titre'],
                  'expire':          scan['expire'],
                  'date_scan':       scan['date_scan'],
                  'matricule_agent': scan['matricule_agent'],
                }),
              )
              .timeout(ApiConstants.defaultTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true) {
              await TicketDao.markScanLogSynced(localId);
              print('✅ Scan log $localId synced');
            } else {
              throw Exception(data['error'] ?? 'Réponse serveur invalide');
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print('❌ Scan log $localId failed: $e');
          await TicketDao.markScanLogFailed(localId, e.toString());
        }
      }

      print('✅ Sync done: $synced synced, $failed failed');

    } finally {
      _isSyncing = false;
    }

    // ── 5. Push heartbeat after every sync attempt ─────────────────────────
    await _pushHeartbeat(pending: failed, failed: failed);

    return SyncResult(synced: synced, failed: failed);
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────

static Future<void> _pushHeartbeat({
  required int pending,
  required int failed,
}) async {
  final matricule = _cachedMatricule;
  if (matricule == null) return;

  // getUnsyncedTickets() already returns pending + failed — one call is enough
  final allPendingTickets = await TicketDao.getUnsyncedTickets();

  final pendingTickets = allPendingTickets.map((t) => {
    'statut_sync':   t['statut_sync'],
    'point_depart':  t['point_depart'],
    'point_arrivee': t['point_arrivee'],
    'type_tarif':    t['type_tarif'],
    'quantite':      t['quantite'],
    'montant_total': t['montant_total'],
    'erreur':        t['erreur'],
    'tentatives':    t['tentatives'],
    'date_heure':    t['date_heure'],
  }).toList();

  final now     = DateTime.now().toIso8601String();
  final payload = jsonEncode({
    'matricule_agent': matricule,
    'pending_count':   pending,
    'failed_count':    failed,
    'last_sync_at':    now,
    'app_version':     '1.0.0',
    'pending_tickets': pendingTickets,
  });

  await _saveHeartbeatLocally(payload);

  if (ConnectivityService.isConnected) {
    await _sendHeartbeatPayload(payload);
  } else {
    await _queueHeartbeat(payload);
  }
}

  static Future<void> _saveHeartbeatLocally(String payload) async {
    try {
      final db = await LocalDatabase.db;
      await db.insert('heartbeat_log', {
        'payload':    payload,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('💾 Heartbeat saved locally');
    } catch (e) {
      print('⚠️ Failed to save heartbeat locally: $e');
    }
  }

  static Future<void> _sendHeartbeatPayload(String payload) async {
    try {
      await http
          .post(
            Uri.parse(ApiConstants.agentHeartbeat),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 5));
      print('📡 Heartbeat sent to server');
    } catch (e) {
      print('⚠️ Heartbeat send failed (ignored): $e');
    }
  }

  static Future<void> _queueHeartbeat(String payload) async {
    try {
      final db = await LocalDatabase.db;
      await db.insert('heartbeat_queue', {
        'payload':    payload,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('📦 Heartbeat queued for replay on reconnect');
    } catch (e) {
      print('⚠️ Failed to queue heartbeat: $e');
    }
  }

  static Future<void> flushHeartbeatQueue() async {
    try {
      final db     = await LocalDatabase.db;
      final queued = await db.query(
        'heartbeat_queue',
        orderBy: 'created_at ASC',
      );

      if (queued.isEmpty) return;

      print('📤 Flushing ${queued.length} queued heartbeat(s)...');

      for (final row in queued) {
        await _sendHeartbeatPayload(row['payload'] as String);
        await db.delete(
          'heartbeat_queue',
          where:     'id = ?',
          whereArgs: [row['id']],
        );
      }

      print('✅ Heartbeat queue flushed');
    } catch (e) {
      print('⚠️ Failed to flush heartbeat queue: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<int> _countFailed() async {
    try {
      final db     = await LocalDatabase.db;
      final result = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM ticket_vendu_local WHERE statut_sync = 'failed'",
      );
      return (result.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _ensureAllSegmentsCloturedOnServer(int idVente) async {
    try {
      final segResp = await http
          .get(Uri.parse(ApiConstants.voyageSegments(idVente)))
          .timeout(ApiConstants.defaultTimeout);

      if (segResp.statusCode != 200) return;

      final segments =
          (jsonDecode(segResp.body)['segments'] as List<dynamic>?) ?? [];

      for (final s in segments) {
        final seg    = s as Map<String, dynamic>;
        final statut = seg['statut'] as String? ?? '';
        if (statut == 'cloture') continue;

        final idSeg = seg['id_segment'] as int;

        if (statut == 'en_attente') {
          await http
              .put(
                Uri.parse(ApiConstants.ouvrirSegment(idVente)),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(ApiConstants.defaultTimeout);
        }

        await http
            .put(
              Uri.parse(ApiConstants.cloturerSegment(idVente, idSeg)),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(ApiConstants.defaultTimeout);

        print('✅ Cascade: segment $idSeg clôturé on server for vente $idVente');
      }
    } catch (e) {
      print('⚠️ _ensureAllSegmentsCloturedOnServer failed for vente $idVente: $e');
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});
}