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

  static bool   _isSyncing       = false;
  static Timer? _heartbeatTimer;
  static int?   _cachedMatricule;

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
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final pending = await TicketDao.getUnsyncedTickets();
        final failed  = await _countFailed();
        await _pushHeartbeat(pending: pending.length, failed: failed);
      },
    );
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
      // ── Step 0: Sync offline voyages from voyages_cache ──────────────────
      //
      // Offline voyages are stored in voyages_cache with:
      //   • a negative local id  (-(timestamp % 999999 + 1))
      //   • _is_pending = true
      //
      // After the server confirms a voyage we:
      //   1. Replace the negative id with the real server id in cache.
      //   2. Patch every ticket that was sold against the local id so it
      //      now references the real id — critical for correct reporting.
      // ─────────────────────────────────────────────────────────────────────
      if (_cachedMatricule != null) {
        final matriculeNonProg = -_cachedMatricule!;
        final cached = await VoyageDao.getVoyages(matriculeNonProg) ?? [];

        final pendingList = cached
            .where((v) => v['_is_pending'] == true)
            .toList();

        print('🔄 SyncService: ${pendingList.length} offline voyage(s) to sync…');

        for (final v in pendingList) {
          final localId =
              ((v['id_voyage'] ?? v['id']) as num).toInt();

          final body = <String, dynamic>{
            'id_ligne':        v['id_ligne'],
            'depart':          v['depart']          ?? '',
            'arrivee':         v['arrivee']         ?? '',
            'nom_ligne':       v['nom_ligne']       ?? '',
            'type':            'spontané',
            'statut':          'actif',
            'matricule_agent': v['matricule_agent'],
            'id_appareil':     v['id_appareil']     ?? 0,
            'code_agence':     v['code_agence'],
            'date_heure':      v['date_heure'],
          };

          if (v['id_billet'] != null) body['id_billet'] = v['id_billet'];

          try {
            final response = await http
                .post(
                  Uri.parse(ApiConstants.createVoyage),
                  headers: {'Content-Type': 'application/json'},
                  body:    jsonEncode(body),
                )
                .timeout(ApiConstants.defaultTimeout);

            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;

              if (data['success'] == true || data['id_voyage'] != null) {
                final realId = data['id_voyage'] as int?;

                // 1. Update the voyage cache entry
                await VoyageDao.replacePendingVoyageInCache(
                  matriculeNonProg: matriculeNonProg,
                  localId:          localId,
                  realId:           realId ?? localId,
                );

                if (realId != null) {
                  await VoyageDao.saveVoyageStatut(
                    realId,
                    'actif',
                    serverStatut: 'actif',
                  );

                  // 2. Patch every ticket sold against the local negative id
                  //    so they reference the real server id instead.
                  await _patchTicketVoyageId(
                    localId: localId,
                    realId:  realId,
                  );
                }

                print('✅ Offline voyage $localId → server id: $realId');
                synced++;
              } else {
                print('⚠️ Offline voyage $localId rejected: '
                    '${data['message']}');
              }
            } else {
              print('⚠️ Offline voyage $localId HTTP ${response.statusCode}');
            }
          } catch (e) {
            // Network unavailable — leave in cache, retry on next reconnect.
            print('❌ Offline voyage $localId sync failed: $e');
          }
        }

        // ── Also drain the legacy pending_voyages table (if any old rows) ──
        final legacyPending = await VoyageDao.getPendingVoyages();
        if (legacyPending.isNotEmpty) {
          print('🔄 Draining ${legacyPending.length} '
              'legacy pending_voyage row(s)…');

          for (final row in legacyPending) {
            final legacyId   = row['id'] as int;
            final legacyBody = jsonDecode(row['data'] as String)
                as Map<String, dynamic>;

            try {
              final response = await http
                  .post(
                    Uri.parse(ApiConstants.createVoyage),
                    headers: {'Content-Type': 'application/json'},
                    body:    jsonEncode(legacyBody),
                  )
                  .timeout(ApiConstants.defaultTimeout);

              if (response.statusCode == 200 || response.statusCode == 201) {
                final data =
                    jsonDecode(response.body) as Map<String, dynamic>;

                if (data['success'] == true || data['id_voyage'] != null) {
                  final voyageId = data['id_voyage'] as int?;
                  if (voyageId != null) {
                    await VoyageDao.saveVoyageStatut(
                      voyageId,
                      'actif',
                      serverStatut: 'actif',
                    );
                  }
                  await VoyageDao.markPendingVoyageSynced(legacyId);
                  print('✅ Legacy voyage $legacyId → server id: $voyageId');
                  synced++;
                }
              }
            } catch (e) {
              print('❌ Legacy voyage $legacyId sync failed: $e');
            }
          }
        }
      }

      // ── Step 1: Sync pending tickets ──────────────────────────────────────
      //
      // NOTE: tickets sold against a pending voyage have a negative id_voyage.
      // We skip those here — they will be retried after the voyage is synced
      // and _patchTicketVoyageId gives them the real id.
      // ─────────────────────────────────────────────────────────────────────
      final toSync = await TicketDao.getUnsyncedTickets();
      final readyToSync =
          toSync.where((t) => ((t['id_voyage'] as num?) ?? 0) > 0).toList();
      final waitingForVoyage = toSync.length - readyToSync.length;

      if (waitingForVoyage > 0) {
        print('⏳ $waitingForVoyage ticket(s) waiting for voyage sync first');
      }
      print('🔄 Syncing ${readyToSync.length} ready ticket(s)…');

      for (final ticket in readyToSync) {
        final localId = ticket['id'] as int;

        if (_cachedMatricule == null &&
            ticket['matricule_agent'] != null) {
          _cachedMatricule =
              (ticket['matricule_agent'] as num).toInt();
        }

        try {
          final response = await http
              .post(
                Uri.parse(ApiConstants.vendreTicket),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id_voyage':       ticket['id_voyage'],
                  'id_segment':      ticket['id_segment'] ?? 0,
                  'point_depart':    ticket['point_depart'],
                  'point_arrivee':   ticket['point_arrivee'],
                  'type_tarif':      ticket['type_tarif'],
                  'quantite':
                      (ticket['quantite']      as num).toInt(),
                  'prix_unitaire':
                      (ticket['prix_unitaire'] as num).toInt(),
                  'montant_total':
                      (ticket['montant_total'] as num).toInt(),
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
            final data =
                jsonDecode(response.body) as Map<String, dynamic>;

            if (data['success'] == true) {
              await TicketDao.markSynced(
                  localId, data['id_ticket'] as int);
              await LogDao.insertLog(
                idTicketLocal: localId,
                statut:        'synced',
                message:
                    'Synchronisé avec succès (restauration réseau)',
              );
              print('✅ Ticket $localId → server id: '
                  '${data['id_ticket']}');
              synced++;
            } else {
              throw Exception(
                  data['error'] ?? 'Réponse serveur invalide');
            }
          } else {
            throw Exception(
                'HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print('❌ Ticket $localId failed: $e');
          await TicketDao.markFailed(localId, e.toString());
          await LogDao.insertLog(
            idTicketLocal: localId,
            statut:        'failed',
            message:       e.toString(),
          );
          failed++;
        }
      }

      // ── Step 2: Sync pending voyage clôtures ──────────────────────────────
      if (failed > 0) {
        print('⚠️ Skipping clôtures — $failed ticket(s) still unsynced');
      } else {
        final pendingClotures = await VoyageDao.getPendingClotures();
        print(
            '🔄 Syncing ${pendingClotures.length} pending clôture(s)…');

        for (final cloture in pendingClotures) {
          final idVente = cloture['id_voyage'] as int;
          // Skip if this is a local negative id — voyage not on server yet
          if (idVente < 0) continue;

          try {
            final response = await http
                .put(
                  Uri.parse(ApiConstants.cloturerVoyage(idVente)),
                  headers: {'Content-Type': 'application/json'},
                )
                .timeout(ApiConstants.defaultTimeout);

            if (response.statusCode == 200) {
              final data =
                  jsonDecode(response.body) as Map<String, dynamic>;

              if (data['success'] == true) {
                await VoyageDao.markClotureSynced(idVente);
                await VoyageDao.saveVoyageStatut(
                  idVente,
                  'cloture',
                  serverStatut: 'cloture',
                );
                print('✅ Clôture synced for vente $idVente');
              } else {
                print('⚠️ Clôture rejected for vente $idVente: '
                    '${data['message']}');
              }
            } else {
              print('⚠️ Clôture HTTP ${response.statusCode} '
                  'for vente $idVente');
            }
          } catch (e) {
            print('❌ Clôture sync failed for vente $idVente: $e');
          }
        }
      }

      // ── Step 3: Sync pending reopens ──────────────────────────────────────
      final pendingReopens = await VoyageDao.getPendingReopens();
      print('🔄 Syncing ${pendingReopens.length} pending reopen(s)…');

      for (final reopen in pendingReopens) {
        final idVente = reopen['id_voyage'] as int;
        final scope   = reopen['scope'] as String? ?? 'single';
        // Skip local negative ids
        if (idVente < 0) continue;

        try {
          final response = await http
              .put(
                Uri.parse(ApiConstants.reopenVoyage(idVente)),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(ApiConstants.reopenTimeout);

          if (response.statusCode == 200 ||
              response.statusCode == 409) {
            await VoyageDao.markReopenSynced(idVente);
            await VoyageDao.clearVoyageStatut(idVente);
            final reason = response.statusCode == 409
                ? 'already active'
                : 'reopened';
            print('✅ Reopen synced for vente $idVente '
                '(scope=$scope, $reason)');
            synced++;
          } else {
            print('⚠️ Reopen HTTP ${response.statusCode} '
                'for vente $idVente');
          }
        } catch (e) {
          print('❌ Reopen sync failed for vente $idVente: $e');
        }
      }

      // ── Step 4: Sync pending scan logs ────────────────────────────────────
      final pendingScans = await TicketDao.getUnsyncedScanLogs();
      print('🔄 Syncing ${pendingScans.length} pending scan log(s)…');

      for (final scan in pendingScans) {
        final localId = scan['id'] as int;

        if (_cachedMatricule == null &&
            scan['matricule_agent'] != null) {
          _cachedMatricule =
              (scan['matricule_agent'] as num).toInt();
        }

        try {
          final response = await http
              .post(
                Uri.parse(ApiConstants.logScan),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id_voyage':       scan['id_voyage'],
                  'id_segment':      scan['id_segment'] ?? 0,
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
            final data =
                jsonDecode(response.body) as Map<String, dynamic>;

            if (data['success'] == true) {
              await TicketDao.markScanLogSynced(localId);
              print('✅ Scan log $localId synced');
            } else {
              throw Exception(
                  data['error'] ?? 'Réponse serveur invalide');
            }
          } else {
            throw Exception(
                'HTTP ${response.statusCode}: ${response.body}');
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

    await _pushHeartbeat(pending: failed, failed: failed);
    return SyncResult(synced: synced, failed: failed);
  }

  // ── Private: patch tickets after offline voyage is confirmed ──────────────

  /// After an offline voyage is confirmed by the server, all tickets sold
  /// against the local negative id must reference the real server id so that:
  ///   • the next sync attempt POSTs them to the right voyage;
  ///   • historical exports show the correct voyage id.
  static Future<void> _patchTicketVoyageId({
    required int localId,
    required int realId,
  }) async {
    if (localId == realId) return;
    try {
      final db = await LocalDatabase.db;
      final count = await db.update(
        'ticket_vendu_local',
        {'id_voyage': realId},
        where:     'id_voyage = ?',
        whereArgs: [localId],
      );
      if (count > 0) {
        print('🔁 Patched $count ticket(s): '
            'id_voyage $localId → $realId');
      }
    } catch (e) {
      print('❌ _patchTicketVoyageId($localId → $realId): $e');
    }
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────

  static Future<void> _pushHeartbeat({
    required int pending,
    required int failed,
  }) async {
    final matricule = _cachedMatricule;
    if (matricule == null) return;

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
            body:    payload,
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
          'heartbeat_queue', orderBy: 'created_at ASC');
      if (queued.isEmpty) return;

      print('📤 Flushing ${queued.length} queued heartbeat(s)…');
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
        "SELECT COUNT(*) AS cnt FROM ticket_vendu_local "
        "WHERE statut_sync = 'failed'",
      );
      return (result.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});
}