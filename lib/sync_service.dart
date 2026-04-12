import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_database.dart';

class SyncService {
  static const String _baseUrl = 'http://192.168.1.22:8000/billetterie';
  static bool _isSyncing = false;

  static void startListening() {
    Connectivity().onConnectivityChanged.listen(
      (
        results,
      ) {
        final isOnline = results.any(
          (
            r,
          ) =>
              r !=
              ConnectivityResult.none,
        );
        if (isOnline) {
          Future.delayed(
            const Duration(
              seconds: 2,
            ),
            () => syncPending(),
          );
        }
      },
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
      final toSync = await LocalDatabase.getUnsyncedTickets();
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
                  '$_baseUrl/tickets/vendre',
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(
                  {
                    'id_vente': ticket['id_vente'],
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
                const Duration(
                  seconds: 10,
                ),
              );

          if (response.statusCode ==
              200) {
            final data = jsonDecode(
              response.body,
            );
            if (data['success'] ==
                true) {
              await LocalDatabase.markSynced(
                localId,
                data['id_ticket']
                    as int,
              );
              await LocalDatabase.insertLog(
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
          await LocalDatabase.markFailed(
            localId,
            e.toString(),
          );
          await LocalDatabase.insertLog(
            idTicketLocal: localId,
            statut: 'failed',
            message: e.toString(),
          );
          failed++;
        }
      }

      // ── 2. Sync pending segment clotures ─────────────────────
      // Runs BEFORE voyage clotures so all segments are closed on the server
      // before the voyage itself is clôturé.
      final pendingSegments = await LocalDatabase.getPendingSegmentClotures();
      print(
        '🔄 Syncing ${pendingSegments.length} pending segment clotures...',
      );

      for (final row in pendingSegments) {
        final idVente =
            row['id_vente']
                as int;
        final idSegment =
            row['id_segment']
                as int;
        final openNext =
            (row['open_next']
                as int?) ==
            1;

        try {
          // 2a. If the segment is still en_attente on the server, open it first
          //     so the server will accept the cloture.
          final checkResp = await http
              .get(
                Uri.parse(
                  '$_baseUrl/voyages/$idVente/segments',
                ),
              )
              .timeout(
                const Duration(
                  seconds: 10,
                ),
              );

          if (checkResp.statusCode ==
              200) {
            final checkData = jsonDecode(
              checkResp.body,
            );
            final segs =
                checkData['segments']
                    as List<
                      dynamic
                    >? ??
                [];
            final match = segs
                .cast<
                  Map<
                    String,
                    dynamic
                  >
                >()
                .where(
                  (
                    s,
                  ) =>
                      s['id_segment'] ==
                      idSegment,
                )
                .firstOrNull;

            if (match !=
                    null &&
                match['statut'] ==
                    'en_attente') {
              // Open it first
              await http
                  .put(
                    Uri.parse(
                      '$_baseUrl/voyages/$idVente/segment/ouvrir',
                    ),
                    headers: {
                      'Content-Type': 'application/json',
                    },
                  )
                  .timeout(
                    const Duration(
                      seconds: 10,
                    ),
                  );
            }
          }

          // 2b. Clôture the segment on the server
          final clotureResp = await http
              .put(
                Uri.parse(
                  '$_baseUrl/voyages/$idVente/segments/$idSegment/cloturer',
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                const Duration(
                  seconds: 10,
                ),
              );

          final clotureData = jsonDecode(
            clotureResp.body,
          );

          if (clotureResp.statusCode ==
                  200 &&
              clotureData['success'] ==
                  true) {
            await LocalDatabase.markSegmentClotureSynced(
              idVente,
              idSegment,
            );
            print(
              '✅ Segment $idSegment clôturé on server (vente $idVente)',
            );

            // 2c. Open next segment only when explicitly requested
            //     (normal segment flow, not voyage-cloture cascade)
            if (openNext) {
              try {
                final ouvrirResp = await http
                    .put(
                      Uri.parse(
                        '$_baseUrl/voyages/$idVente/segment/ouvrir',
                      ),
                      headers: {
                        'Content-Type': 'application/json',
                      },
                    )
                    .timeout(
                      const Duration(
                        seconds: 10,
                      ),
                    );

                final ouvrirData = jsonDecode(
                  ouvrirResp.body,
                );
                if (ouvrirData['success'] ==
                    true) {
                  print(
                    '✅ Next segment opened for vente $idVente',
                  );
                } else {
                  print(
                    '⚠️ Could not open next segment for vente $idVente: '
                    '${ouvrirData['message']}',
                  );
                }
              } catch (
                e
              ) {
                print(
                  '❌ Open next segment failed for vente $idVente: $e',
                );
              }
            }
          } else {
            // Server rejected (e.g. already clôturé) — mark synced anyway
            final msg =
                clotureData['message'] ??
                'Rejeté par le serveur';
            print(
              '⚠️ Segment $idSegment cloture rejected for vente $idVente: $msg',
            );
            await LocalDatabase.markSegmentClotureSynced(
              idVente,
              idSegment,
            );
          }
        } catch (
          e
        ) {
          print(
            '❌ Segment cloture sync failed vente=$idVente seg=$idSegment: $e',
          );
          // Leave as pending — will retry next connectivity event
        }
      }

      // ── 3. Sync pending voyage clotures ──────────────────────
      // By now all segments for each voyage should already be clôturé
      // on the server (step 2 above). We just need to clôture the voyage.
      final pendingClotures = await LocalDatabase.getPendingClotures();
      print(
        '🔄 Syncing ${pendingClotures.length} pending voyage clôtures...',
      );

      for (final cloture in pendingClotures) {
        final idVente =
            cloture['id_vente']
                as int;
        try {
          // Extra safety: ensure all segments are clôturé on the server
          // before clôturing the voyage, in case step 2 missed any.
          await _ensureAllSegmentsCloturedOnServer(
            idVente,
          );

          final response = await http
              .put(
                Uri.parse(
                  '$_baseUrl/vente/$idVente/cloturer',
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                const Duration(
                  seconds: 10,
                ),
              );

          if (response.statusCode ==
              200) {
            final data = jsonDecode(
              response.body,
            );
            if (data['success'] ==
                true) {
              await LocalDatabase.markClotureSynced(
                idVente,
              );
              await LocalDatabase.saveVoyageStatut(
                idVente,
                'cloture',
              );
              print(
                '✅ Voyage clôture synced for vente $idVente',
              );
            } else {
              print(
                '⚠️ Voyage clôture rejected by server for vente $idVente: '
                '${data['message']}',
              );
            }
          } else {
            print(
              '⚠️ Voyage clôture HTTP error for vente $idVente: '
              '${response.statusCode}',
            );
          }
        } catch (
          e
        ) {
          print(
            '❌ Voyage clôture sync failed for vente $idVente: $e',
          );
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
  // Helper: ensure every segment of a voyage is clôturé on the
  // server. Called just before syncing a voyage cloture.
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
              '$_baseUrl/voyages/$idVente/segments',
            ),
          )
          .timeout(
            const Duration(
              seconds: 10,
            ),
          );

      if (segResp.statusCode !=
          200)
        return;

      final segData = jsonDecode(
        segResp.body,
      );
      final segments =
          segData['segments']
              as List<
                dynamic
              >? ??
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

        // If still en_attente, open it first
        if (statut ==
            'en_attente') {
          await http
              .put(
                Uri.parse(
                  '$_baseUrl/voyages/$idVente/segment/ouvrir',
                ),
                headers: {
                  'Content-Type': 'application/json',
                },
              )
              .timeout(
                const Duration(
                  seconds: 10,
                ),
              );
        }

        // Now clôture it
        await http
            .put(
              Uri.parse(
                '$_baseUrl/voyages/$idVente/segments/$idSeg/cloturer',
              ),
              headers: {
                'Content-Type': 'application/json',
              },
            )
            .timeout(
              const Duration(
                seconds: 10,
              ),
            );

        print(
          '✅ Cascade: segment $idSeg clôturé on server for vente $idVente',
        );
      }
    } catch (
      e
    ) {
      print(
        '⚠️ _ensureAllSegmentsCloturedOnServer failed for vente $idVente: $e',
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
