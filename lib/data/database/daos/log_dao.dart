import '../local_database.dart';

class LogDao {
  static Future<void> insertLog({
    required int idTicketLocal,
    required String statut,
    String? message,
  }) async {
    try {
      await (await LocalDatabase.db).insert('sync_log', {
        'id_ticket_local': idTicketLocal,
        'date_tentative':  DateTime.now().toIso8601String(),
        'statut':          statut,
        'message':         message,
      });
    } catch (e) {
      print('❌ LogDao.insertLog: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      return await (await LocalDatabase.db).rawQuery('''
        SELECT l.*, t.point_depart, t.point_arrivee,
               t.montant_total, t.statut_sync, t.matricule_agent
        FROM sync_log l
        JOIN ticket_vendu_local t ON l.id_ticket_local = t.id
        ORDER BY l.date_tentative DESC
      ''');
    } catch (e) {
      print('❌ LogDao.getLogs: $e');
      return [];
    }
  }
}