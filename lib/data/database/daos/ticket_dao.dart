import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class TicketDao {
  /// Insert a ticket row.
  /// [conflictReplace] = true overwrites an existing row;
  /// the default (IGNORE) safely skips duplicate server-id conflicts.
  static Future<int> insertTicket(
    Map<String, dynamic> ticket, {
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
    } catch (e) {
      print('❌ TicketDao.insertTicket: $e');
      rethrow;
    }
  }

  /// Update only the id_segment of a cached ticket (called after server sync
  /// reveals the correct segment order for a row cached with id_segment = 0).
  static Future<void> updateTicketSegment(int localId, int idSegment) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {'id_segment': idSegment},
        where: 'id = ?',
        whereArgs: [localId],
      );
      print('✓ TicketDao.updateTicketSegment: id=$localId → id_segment=$idSegment');
    } catch (e) {
      print('❌ TicketDao.updateTicketSegment: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: 'statut_sync = ?',
        whereArgs: ['pending'],
      );
    } catch (e) {
      print('❌ TicketDao.getPendingTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getUnsyncedTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ TicketDao.getAllTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTicketsByVoyage(
      int idVente) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: 'id_vente = ?',
        whereArgs: [idVente],
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ TicketDao.getTicketsByVoyage: $e');
      return [];
    }
  }

  static Future<void> deleteTicketsByVoyage(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'ticket_vendu_local',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ TicketDao.deleteTicketsByVoyage: vente=$idVente');
    } catch (e) {
      print('❌ TicketDao.deleteTicketsByVoyage: $e');
    }
  }

  static Future<void> markSynced(int id, int idServeur) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {'statut_sync': 'synced', 'id_serveur': idServeur},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ TicketDao.markSynced: $e');
    }
  }

  static Future<void> markFailed(int id, String erreur) async {
    try {
      await (await LocalDatabase.db).rawUpdate('''
        UPDATE ticket_vendu_local
        SET statut_sync = 'failed', tentatives = tentatives + 1, erreur = ?
        WHERE id = ?
      ''', [erreur, id]);
    } catch (e) {
      print('❌ TicketDao.markFailed: $e');
    }
  }
}