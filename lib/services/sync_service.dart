import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants/api_constants.dart';
import '../data/database/daos/ticket_dao.dart';
import '../data/database/daos/voyage_dao.dart';
import '../data/database/daos/log_dao.dart';
import 'connectivity_service.dart';

class SyncService {
  static bool _isSyncing = false;

  static void startListening() {
    ConnectivityService.startListening(
      onReconnect: () => Future.delayed(
        const Duration(
          seconds: 2,
        ),
        () => syncPending(),
      ),
    );
  }

  static Future<
    SyncResult
  >
  syncPending() async {
    if (_isSyncing)
      return SyncResult(
        synced: 0,
        failed: 0,
      );
    _isSyncing = true;

    int synced = 0, failed = 0;

    try {
      // ── 1. Sync pending tickets ──────────────────────────────
      final toSync = await TicketDao.getUnsyncedTickets();
      print(
        '🔄 Syncing ${toSync.length} unsynced tickets...',
      );

      for (final ticket in toSync) {
        final localId =
            ticket['id']
                as int;
        try {
          final response = await http
              .post(
                Uri.parse(
                  ApiConstants.vendreTicket,
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(
                  {
                    'id_voyage': ticket['id_voyage'],
                    'id_segment': ticket['id_segment'],
                    'point_depart': ticket['point_depart'],
                    'point_arrivee': ticket['point_arrivee'],
                    'type_tarif': ticket['type_tarif'],
                    'quantite':
                        (ticket['quantite']
                                as num)
                            .toInt(),
                    'prix_unitaire':
                        (ticket['prix_unitaire']
                                as num)
                            .toInt(),
                    'montant_total':
                        (ticket['montant_total']
                                as num)
                            .toInt(),
                    'matricule_agent': ticket['matricule_agent'],
                  },
                ),
              )
              .timeout(
                ApiConstants.defaultTimeout,
              );

          if (response.statusCode ==
              200) {
            final data = jsonDecode(
              response.body,
            );
            if (data['success'] ==
                true) {
              await TicketDao.markSynced(
                localId,
                data['id_ticket']
                    as int,
              );
              await LogDao.insertLog(
                idTicketLocal: localId,
                statut: 'synced',
                message: 'Synchronisé avec succès (restauration réseau)',
              );
              print(
                '✅ Ticket $localId synced → server id: ${data['id_ticket']}',
              );
              synced++;
            } else {
              throw Exception(
                data['error'] ??
                    'Réponse serveur invalide',
              );
            }
          } else {
            throw Exception(
              'HTTP ${response.statusCode}: ${response.body}',
            );
          }
        } catch (
          e
        ) {
          print(
            '❌ Ticket $localId failed: $e',
          );
          await TicketDao.markFailed(
            localId,
            e.toString(),
          );
          await LogDao.insertLog(
            idTicketLocal: localId,
            statut: 'failed',
            message: e.toString(),
          );
          failed++;
        }
      }

      // ── 2. Sync pending voyage clôtures ──────────────────────
      // Only attempt after all tickets are synced — the server may reject
      // a clôture if it detects unsynced ticket rows for that voyage.
      // ── 2. Sync pending voyage clôtures ──────────────────────
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
      // ── 3. Sync pending reopens ───────────────────────────────
      // Reopens are independent of ticket failures — no ticket data is
      // involved, so we always attempt them regardless of [failed] count.
      // Journée reopens are synced one-by-one here (idempotent).
      final pendingReopens = await VoyageDao.getPendingReopens();
      print(
        '🔄 Syncing ${pendingReopens.length} pending reopens...',
      );

      for (final reopen in pendingReopens) {
        final idVente =
            reopen['id_voyage']
                as int;
        final scope =
            reopen['scope']
                as String? ??
            'single';

        try {
          final response = await http
              .put(
                // ✅ Uses ApiConstants — no hardcoded IP
                Uri.parse(
                  ApiConstants.reopenVoyage(
                    idVente,
                  ),
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                ApiConstants.defaultTimeout,
              );

          if (response.statusCode ==
              200) {
            final data = jsonDecode(
              response.body,
            );
            if (data['success'] ==
                true) {
              await VoyageDao.markReopenSynced(
                idVente,
              );
              // Wipe the local cache row — server is now authoritative again.
              await VoyageDao.clearVoyageStatut(
                idVente,
              );
              print(
                '✅ Reopen synced for vente $idVente (scope=$scope)',
              );
            } else {
              await VoyageDao.markReopenFailed(
                idVente,
              );
              print(
                '⚠️ Reopen rejected by server for vente $idVente: '
                '${data['message']}',
              );
            }
          } else {
            print(
              '⚠️ Reopen HTTP error for vente $idVente: '
              '${response.statusCode}',
            );
          }
        } catch (
          e
        ) {
          print(
            '❌ Reopen sync failed for vente $idVente: $e',
          );
          // Leave row as pending — will retry on next reconnect.
        }
      }

      print(
        '✅ Sync done: $synced synced, $failed failed',
      );
    } finally {
      _isSyncing = false;
    }

    return SyncResult(
      synced: synced,
      failed: failed,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cascade: ensure every segment of [idVente] is clôturé on the
  // server before we send the voyage-level clôture request.
  // ─────────────────────────────────────────────────────────────

  static Future<
    void
  >
  _ensureAllSegmentsCloturedOnServer(
    int idVente,
  ) async {
    try {
      final segResp = await http
          .get(
            Uri.parse(
              ApiConstants.voyageSegments(
                idVente,
              ),
            ),
          )
          .timeout(
            ApiConstants.defaultTimeout,
          );

      if (segResp.statusCode !=
          200)
        return;

      final segments =
          (jsonDecode(
                segResp.body,
              )['segments']
              as List<
                dynamic
              >?) ??
          [];

      for (final s in segments) {
        final seg =
            s
                as Map<
                  String,
                  dynamic
                >;
        final statut =
            seg['statut']
                as String? ??
            '';
        if (statut ==
            'cloture')
          continue;

        final idSeg =
            seg['id_segment']
                as int;

        if (statut ==
            'en_attente') {
          await http
              .put(
                Uri.parse(
                  ApiConstants.ouvrirSegment(
                    idVente,
                  ),
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                ApiConstants.defaultTimeout,
              );
        }

        await http
            .put(
              Uri.parse(
                ApiConstants.cloturerSegment(
                  idVente,
                  idSeg,
                ),
              ),
              headers: {
                'Content-Type': 'application/json',
              },
            )
            .timeout(
              ApiConstants.defaultTimeout,
            );

        print(
          '✅ Cascade: segment $idSeg clôturé on server '
          'for vente $idVente',
        );
      }
    } catch (
      e
    ) {
      print(
        '⚠️ _ensureAllSegmentsCloturedOnServer failed '
        'for vente $idVente: $e',
      );
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({
    required this.synced,
    required this.failed,
  });
}
