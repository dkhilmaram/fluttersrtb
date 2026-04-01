import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_database.dart';

class TicketRepository {
  static const String _baseUrl = 'http://127.0.0.1:8000/billetterie';

  static Future<
    ({
      bool success,
      bool wasOffline,
      String? error,
    })
  >
  saveTicket(
    Map<
      String,
      dynamic
    >
    ticketData,
  ) async {
    // ── 1. Always save locally first as 'pending' ──
    final localId = await LocalDatabase.insertTicket(
      {
        ...ticketData,
        'statut_sync': 'pending',
        'date_heure': DateTime.now().toIso8601String(),
      },
    );

    // ── 2. Try pushing to server immediately ──
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
                'id_vente': ticketData['id_vente'],
                'id_segment': ticketData['id_segment'],
                'point_depart': ticketData['point_depart'],
                'point_arrivee': ticketData['point_arrivee'],
                'type_tarif': ticketData['type_tarif'],
                // ── Cast to int to avoid double serialization issues ──
                'quantite':
                    (ticketData['quantite']
                            as num)
                        .toInt(),
                'prix_unitaire':
                    (ticketData['prix_unitaire']
                            as num)
                        .toInt(),
                'montant_total':
                    (ticketData['montant_total']
                            as num)
                        .toInt(),
                'matricule_agent': ticketData['matricule_agent'],
              },
            ),
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );

      if (response.statusCode ==
          200) {
        final data = jsonDecode(
          response.body,
        );
        if (data['success'] ==
            true) {
          // ── Mark local copy as synced immediately ──
          await LocalDatabase.markSynced(
            localId,
            data['id_ticket']
                as int,
          );
          await LocalDatabase.insertLog(
            idTicketLocal: localId,
            statut: 'synced',
            message: 'Synchronisé immédiatement (online)',
          );
          return (
            success: true,
            wasOffline: false,
            error: null,
          );
        } else {
          final msg = 'Erreur serveur: ${data['error'] ?? 'inconnue'}';
          await LocalDatabase.markFailed(
            localId,
            msg,
          );
          await LocalDatabase.insertLog(
            idTicketLocal: localId,
            statut: 'failed',
            message: msg,
          );
          return (
            success: true,
            wasOffline: true,
            error: msg,
          );
        }
      }

      final msg = 'Erreur HTTP: ${response.statusCode}';
      await LocalDatabase.markFailed(
        localId,
        msg,
      );
      await LocalDatabase.insertLog(
        idTicketLocal: localId,
        statut: 'failed',
        message: msg,
      );
      return (
        success: true,
        wasOffline: true,
        error: msg,
      );
    } catch (
      _
    ) {
      // ── No internet — stays pending, SyncService will handle it ──
      await LocalDatabase.insertLog(
        idTicketLocal: localId,
        statut: 'pending',
        message: 'Hors-ligne — en attente de synchronisation',
      );
      return (
        success: true,
        wasOffline: true,
        error: null,
      );
    }
  }
}
