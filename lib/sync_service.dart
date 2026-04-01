import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_database.dart';

class SyncService {
  static const String _baseUrl = 'http://127.0.0.1:8000/billetterie';
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
          // Small delay to let connection stabilize before syncing
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

  /// Syncs ALL unsynced tickets: both 'pending' AND 'failed' ones.
  /// This is called automatically when internet is restored,
  /// and can also be triggered manually.
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
      // ── Fetch BOTH pending AND failed tickets ──
      final toSync = await LocalDatabase.getUnsyncedTickets();
      print(
        '🔄 Syncing ${toSync.length} unsynced tickets (pending + failed)...',
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
              continue;
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
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({
    required this.synced,
    required this.failed,
  });
}
