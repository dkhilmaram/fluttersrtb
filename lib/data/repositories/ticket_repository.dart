import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/daos/ticket_dao.dart';
import '../database/daos/log_dao.dart';
import '../../core/constants/api_constants.dart';

class TicketRepository {
  TicketRepository._();

  static Future<({bool success, bool wasOffline, String? error})> saveTicket(
    Map<String, dynamic> ticketData,
  ) async {
    // ── 1. Try pushing to server first (online path) ─────────────────────────
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.vendreTicket),
            headers: {'Content-Type': 'application/json'},
           body: jsonEncode({
  'id_voyage':       ticketData['id_voyage'],
  'id_segment':      ticketData['id_segment'],
  'point_depart':    ticketData['point_depart'],
  'point_arrivee':   ticketData['point_arrivee'],
  'type_tarif':      ticketData['type_tarif'],
  'quantite':        (ticketData['quantite'] as num).toInt(),
  'prix_unitaire':   (ticketData['prix_unitaire'] as num).toInt(),
  'montant_total':   (ticketData['montant_total'] as num).toInt(),
  'matricule_agent': ticketData['matricule_agent'],
  'numero_titre':    ticketData['numero_titre'],  // ← added
  'sync_status':     'online',
}),
          )
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✓ Server accepted — no local save needed
        if (data['success'] == true) {
          return (success: true, wasOffline: false, error: null);
        }

        // ✗ Server rejected — save locally as 'failed' (no sync_status in SQLite)
        final serverMsg = data['error'] as String? ?? 'Erreur serveur inconnue';
        final localId = await TicketDao.insertTicket({
          ...ticketData,
          'statut_sync': 'failed',
          'date_heure':  DateTime.now().toIso8601String(),
        });
        await LogDao.insertLog(
          idTicketLocal: localId,
          statut: 'failed',
          message: 'Erreur serveur: $serverMsg',
        );
        return (success: true, wasOffline: false, error: serverMsg);
      }

      // ✗ Bad HTTP status — save locally as 'failed' (no sync_status in SQLite)
      final statusMsg = 'Erreur HTTP ${response.statusCode}';
      final localId = await TicketDao.insertTicket({
        ...ticketData,
        'statut_sync': 'failed',
        'date_heure':  DateTime.now().toIso8601String(),
      });
      await LogDao.insertLog(
        idTicketLocal: localId,
        statut: 'failed',
        message: statusMsg,
      );
      return (success: true, wasOffline: false, error: statusMsg);

    } catch (e) {
      // ✗ No internet — save locally as 'pending' (no sync_status in SQLite)
      // SyncService will add sync_status: 'synced' when it pushes to the server
      final localId = await TicketDao.insertTicket({
        ...ticketData,
        'statut_sync': 'pending',
        'date_heure':  DateTime.now().toIso8601String(),
      });
      await LogDao.insertLog(
        idTicketLocal: localId,
        statut: 'pending',
        message: 'Hors-ligne — en attente de synchronisation',
      );
      return (success: true, wasOffline: true, error: null);
    }
  }
}