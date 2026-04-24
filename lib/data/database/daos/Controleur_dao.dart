import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../local_database.dart';
import '../../../../core/constants/api_constants.dart';

class ControleurDao {

  // ── Normalise all values to String? to avoid type cast crashes ────────
  static Map<String, dynamic> _normalise(Map raw) =>
      raw.map((k, v) => MapEntry(k.toString(), v == null ? null : v.toString()));

  // ── Find printed ticket: server first, local SQLite fallback ──────────
  static Future<Map<String, dynamic>?> findPrintedTicket(String ticketId) async {
    // 1. Try server (online path)
    try {
      final r = await http
          .get(Uri.parse('${ApiConstants.billetterie}/tickets/by-numero/${ticketId.trim()}'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        if (data['success'] == true && data['ticket'] != null) {
          return _normalise(data['ticket'] as Map);
        }
      }
    } catch (_) {}

    // 2. Fallback: local SQLite (offline / synced tickets)
    try {
      final db   = await LocalDatabase.db;
      final rows = await db.query(
        'ticket_vendu_local',
        where:     'numero_titre = ?',
        whereArgs: [ticketId.trim()],
        limit:     1,
      );
      if (rows.isNotEmpty) return _normalise(rows.first);
    } catch (e) {
      print('❌ ControleurDao.findPrintedTicket local: $e');
    }

    return null;
  }

  // ── Find abonnement by NFC UID or QR card_id ─────────────────────────
  static Future<Map<String, dynamic>?> findAbonnement(String cardId) async {
    try {
      final db   = await LocalDatabase.db;
      final rows = await db.query(
        'tickets',
        columns:   ['card_id', 'nom', 'type', 'expire', 'ligne', 'organisme'],
        where:     'card_id = ?',
        whereArgs: [cardId.toUpperCase().trim()],
        limit:     1,
      );
      if (rows.isNotEmpty) return _normalise(rows.first);
      return null;
    } catch (e) {
      print('❌ ControleurDao.findAbonnement: $e');
      return null;
    }
  }

  // ── Insert control log ────────────────────────────────────────────────
  static Future<int> insertControlLog({
    required String ticketId,
    required String ticketType,
    required String resultat,
    required int    matriculeAgent,
    required String infoJson,
  }) async {
    try {
      final db = await LocalDatabase.db;
      final id = await db.insert('control_log', {
        'ticket_id':       ticketId,
        'ticket_type':     ticketType,
        'resultat':        resultat,
        'matricule_agent': matriculeAgent,
        'date_controle':   DateTime.now().toIso8601String(),
        'info_json':       infoJson,
        'statut_sync':     'pending',
      });
      print('✓ ControleurDao.insertControlLog: id=$id');
      return id;
    } catch (e) {
      print('❌ ControleurDao.insertControlLog: $e');
      return -1;
    }
  }

  // ── Unsynced logs ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getUnsyncedLogs() async {
    try {
      return await (await LocalDatabase.db).query(
        'control_log',
        where:   "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_controle ASC',
      );
    } catch (e) {
      print('❌ ControleurDao.getUnsyncedLogs: $e');
      return [];
    }
  }

  // ── Mark synced ───────────────────────────────────────────────────────
  static Future<void> markControlSynced(int id) async {
    try {
      await (await LocalDatabase.db).update(
        'control_log',
        {'statut_sync': 'synced'},
        where:     'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ ControleurDao.markControlSynced: $e');
    }
  }

  // ── Mark failed ───────────────────────────────────────────────────────
  static Future<void> markControlFailed(int id, String erreur) async {
    try {
      await (await LocalDatabase.db).update(
        'control_log',
        {'statut_sync': 'failed'},
        where:     'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ ControleurDao.markControlFailed: $e');
    }
  }

  // ── Recent logs ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 20}) async {
    try {
      return await (await LocalDatabase.db).query(
        'control_log',
        orderBy: 'date_controle DESC',
        limit:   limit,
      );
    } catch (e) {
      print('❌ ControleurDao.getRecentLogs: $e');
      return [];
    }
  }
}