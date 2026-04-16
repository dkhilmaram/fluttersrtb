import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class TicketDao {
  // ═══════════════════════════════════════════════════════════
  // ── INSERT / UPDATE
  // ═══════════════════════════════════════════════════════════

  /// Insert a ticket row.
  /// [conflictReplace] = true overwrites an existing row;
  /// the default (IGNORE) safely skips duplicate server-id conflicts.
  static Future<
    int
  >
  insertTicket(
    Map<
      String,
      dynamic
    >
    ticket, {
    bool conflictReplace = false,
  }) async {
    try {
      return await (await LocalDatabase.db).insert(
        'ticket_vendu_local',
        ticket,
        conflictAlgorithm: conflictReplace
            ? ConflictAlgorithm.replace
            : ConflictAlgorithm.ignore,
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.insertTicket: $e',
      );
      rethrow;
    }
  }

  /// Update only the id_segment of a cached ticket.
  /// Called after server sync reveals the correct segment for a row
  /// that was cached with id_segment = 0 while offline.
  static Future<
    void
  >
  updateTicketSegment(
    int localId,
    int idSegment,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {
          'id_segment': idSegment,
        },
        where: 'id = ?',
        whereArgs: [
          localId,
        ],
      );
      print(
        '✓ TicketDao.updateTicketSegment: '
        'id=$localId → id_segment=$idSegment',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.updateTicketSegment: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── QUERIES
  // ═══════════════════════════════════════════════════════════

  /// All tickets with statut_sync = 'pending'.
  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getPendingTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending'",
        orderBy: 'date_heure ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.getPendingTickets: $e',
      );
      return [];
    }
  }

  /// All tickets that still need to be pushed to the server
  /// (pending OR previously failed).
  /// Used by SyncService on reconnect.
  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getUnsyncedTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_heure ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.getUnsyncedTickets: $e',
      );
      return [];
    }
  }

  /// Pending tickets scoped to ONE voyage.
  /// Used by SyncService to decide whether a voyage clôture can be
  /// pushed — we only block clôture for THIS voyage's unsynced rows,
  /// not for unrelated voyages (fixes the global-block bug).
  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getUnsyncedTicketsForVente(
    int idVente,
  ) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "id_voyage = ? AND (statut_sync = 'pending' OR statut_sync = 'failed')",
        whereArgs: [
          idVente,
        ],
        orderBy: 'date_heure ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.getUnsyncedTicketsForVente: $e',
      );
      return [];
    }
  }

  /// Every ticket row, newest first.
  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getAllTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        orderBy: 'date_heure DESC',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.getAllTickets: $e',
      );
      return [];
    }
  }

  /// All tickets for a given voyage, newest first.
  /// Used by the export / rapport feature.
  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getTicketsByVoyage(
    int idVente,
  ) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
        orderBy: 'date_heure DESC',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.getTicketsByVoyage: $e',
      );
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── DELETE
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  deleteTicketsByVoyage(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).delete(
        'ticket_vendu_local',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ TicketDao.deleteTicketsByVoyage: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.deleteTicketsByVoyage: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SYNC STATUS UPDATES
  // ═══════════════════════════════════════════════════════════

  /// Mark a ticket as successfully synced and store the server-assigned id.
  static Future<
    void
  >
  markSynced(
    int id,
    int idServeur,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {
          'statut_sync': 'synced',
          'id_serveur': idServeur,
        },
        where: 'id = ?',
        whereArgs: [
          id,
        ],
      );
      print(
        '✓ TicketDao.markSynced: id=$id → serveur=$idServeur',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.markSynced: $e',
      );
    }
  }

  /// Mark a ticket as failed and increment the attempt counter.
  static Future<
    void
  >
  markFailed(
    int id,
    String erreur,
  ) async {
    try {
      await (await LocalDatabase.db).rawUpdate(
        '''
        UPDATE ticket_vendu_local
        SET statut_sync  = 'failed',
            tentatives   = tentatives + 1,
            erreur       = ?
        WHERE id = ?
      ''',
        [
          erreur,
          id,
        ],
      );
      print(
        '✓ TicketDao.markFailed: id=$id',
      );
    } catch (
      e
    ) {
      print(
        '❌ TicketDao.markFailed: $e',
      );
    }
  }
}
