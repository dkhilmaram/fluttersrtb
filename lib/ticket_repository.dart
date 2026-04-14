import 'package:http/http.dart' as http;
import 'dart:convert';
import 'local_database.dart';

class TicketRepository {
  static const String _baseUrl = 'http://192.168.1.16:8000/billetterie';

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
    // ── 1. Try pushing to server FIRST (no local save yet) ──
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

      // ── Check response status ──
      if (response.statusCode ==
          200) {
        final data = jsonDecode(
          response.body,
        );

        // ✓ SERVER SUCCESS — DON'T save to local DB
        if (data['success'] ==
            true) {
          return (
            success: true,
            wasOffline: false,
            error: null,
          );
        }

        // ✗ SERVER REJECTED — Save locally as 'failed' with error message
        final serverMsg =
            data['error']
                as String? ??
            'Erreur serveur inconnue';
        final localId = await LocalDatabase.insertTicket(
          {
            ...ticketData,
            'statut_sync': 'failed',
            'date_heure': DateTime.now().toIso8601String(),
          },
        );

        await LocalDatabase.insertLog(
          idTicketLocal: localId,
          statut: 'failed',
          message: 'Erreur serveur: $serverMsg',
        );

        return (
          success: true,
          wasOffline: false, // ← Has internet, but server rejected
          error: serverMsg,
        );
      }

      // ✗ BAD HTTP STATUS — Save locally as 'failed'
      final statusMsg = 'Erreur HTTP ${response.statusCode}';
      final localId = await LocalDatabase.insertTicket(
        {
          ...ticketData,
          'statut_sync': 'failed',
          'date_heure': DateTime.now().toIso8601String(),
        },
      );

      await LocalDatabase.insertLog(
        idTicketLocal: localId,
        statut: 'failed',
        message: statusMsg,
      );

      return (
        success: true,
        wasOffline: false, // ← Has internet, but bad response
        error: statusMsg,
      );
    } catch (
      e
    ) {
      // ✗ NO INTERNET (timeout or connection error) — Save as 'pending'
      final localId = await LocalDatabase.insertTicket(
        {
          ...ticketData,
          'statut_sync': 'pending',
          'date_heure': DateTime.now().toIso8601String(),
        },
      );

      await LocalDatabase.insertLog(
        idTicketLocal: localId,
        statut: 'pending',
        message: 'Hors-ligne — en attente de synchronisation',
      );

      return (
        success: true,
        wasOffline: true, // ← Really offline (no internet)
        error: null,
      );
    }
  }
}
