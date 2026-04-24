import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class AgentDao {
  AgentDao._();

  static Future<void> saveAgent({
    required int matricule,
    required String motDePasse,
    required Map<String, dynamic> employeData,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'agent_cache',
        {
          'matricule':    matricule,
          'mot_de_passe': motDePasse,
          'employe_data': jsonEncode(employeData),
          'cached_at':    DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ AgentDao.saveAgent: matricule=$matricule');
    } catch (e) {
      print('❌ AgentDao.saveAgent: $e');
    }
  }

  static Future<Map<String, dynamic>?> getAgent(
    int matricule,
    String motDePasse,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'agent_cache',
        where:     'matricule = ? AND mot_de_passe = ?',
        whereArgs: [matricule, motDePasse],
        limit:     1,
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['employe_data'] as String)
          as Map<String, dynamic>;
    } catch (e) {
      print('❌ AgentDao.getAgent: $e');
      return null;
    }
  }
}