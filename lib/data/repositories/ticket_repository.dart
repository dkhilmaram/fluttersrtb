import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/daos/ticket_dao.dart';
import '../database/daos/log_dao.dart';
import '../../core/constants/api_constants.dart';

class TicketRepository {
  TicketRepository._();

  /// Result returned to the caller.
  ///
  /// [success]    – the operation completed (ticket saved or queued).
  /// [wasOffline] – true when the ticket was saved locally as 'pending'
  ///                because no internet was available.
  /// [printFailed]– true when printing failed; the ticket was NOT saved.
  /// [error]      – human-readable error string when something went wrong.
  static Future<
      ({
        bool success,
        bool wasOffline,
        bool printFailed,
        String? error,
      })> saveTicket(
    Map<String, dynamic> ticketData,
  ) async {
    // ── Normalise the payload ─────────────────────────────────────────────
    // id_segment is always 0; the server resolves the correct segment from
    // point_depart, preventing the stale-id bug.
    final payload = {
      'id_voyage':       ticketData['id_voyage'],
      'id_segment':      0,
      'point_depart':    ticketData['point_depart'],
      'point_arrivee':   ticketData['point_arrivee'],
      'type_tarif':      ticketData['type_tarif'],
      'quantite':        (ticketData['quantite'] as num).toInt(),
      'prix_unitaire':   (ticketData['prix_unitaire'] as num).toInt(),
      'montant_total':   (ticketData['montant_total'] as num).toInt(),
      'matricule_agent': ticketData['matricule_agent'],
      'sync_status':     'online',
      if (ticketData['numero_titre'] != null)
        'numero_titre': ticketData['numero_titre'],
    };

    // ── Check connectivity first ──────────────────────────────────────────
    // We do a lightweight probe by attempting the actual request inside a
    // try/catch.  If it throws (SocketException, TimeoutException, etc.)
    // we treat the device as offline.
    bool isOffline = false;

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.vendreTicket),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.defaultTimeout);

      // ── Online path ───────────────────────────────────────────────────

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          // Server accepted — ticket is persisted server-side.
          return (
            success:     true,
            wasOffline:  false,
            printFailed: false,
            error:       null,
          );
        }

        // Server rejected the payload.
        final serverMsg =
            data['error'] as String? ?? 'Erreur serveur inconnue';
        final localId = await TicketDao.insertTicket({
          ...ticketData,
          'id_segment':  0,
          'statut_sync': 'failed',
          'date_heure':  DateTime.now().toIso8601String(),
        });
        await LogDao.insertLog(
          idTicketLocal: localId,
          statut:        'failed',
          message:       'Erreur serveur: $serverMsg',
        );
        return (
          success:     true,
          wasOffline:  false,
          printFailed: false,
          error:       serverMsg,
        );
      }

      // Bad HTTP status code.
      final statusMsg = 'Erreur HTTP ${response.statusCode}';
      final localId = await TicketDao.insertTicket({
        ...ticketData,
        'id_segment':  0,
        'statut_sync': 'failed',
        'date_heure':  DateTime.now().toIso8601String(),
      });
      await LogDao.insertLog(
        idTicketLocal: localId,
        statut:        'failed',
        message:       statusMsg,
      );
      return (
        success:     true,
        wasOffline:  false,
        printFailed: false,
        error:       statusMsg,
      );

    } catch (_) {
      // Network unreachable — fall through to offline path below.
      isOffline = true;
    }

    // ── Offline path ──────────────────────────────────────────────────────
    // When there is no connectivity we still save locally as 'pending'.
    // Printing is skipped entirely (can't print without confirming the sale),
    // and the caller is informed via [wasOffline] so it can show the right
    // toast and bypass the print step.
    if (isOffline) {
      final localId = await TicketDao.insertTicket({
        ...ticketData,
        'id_segment':  0,
        'statut_sync': 'pending',
        'date_heure':  DateTime.now().toIso8601String(),
      });
      await LogDao.insertLog(
        idTicketLocal: localId,
        statut:        'pending',
        message:       'Hors-ligne — en attente de synchronisation',
      );
      return (
        success:     true,
        wasOffline:  true,
        printFailed: false,
        error:       null,
      );
    }

    // Should never reach here, but satisfies the Dart type checker.
    return (
      success:     false,
      wasOffline:  false,
      printFailed: false,
      error:       'Erreur inattendue',
    );
  }
}