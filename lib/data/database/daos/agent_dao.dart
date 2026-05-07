import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class AgentDao {

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static Future<void> saveAgent({
    required int    matricule,
    required String motDePasse,
    required Map<String, dynamic> employeData,
  }) async {
    final db         = await LocalDatabase.db;
    final codeAgence = employeData['code_agence'] as int?;
    final hashedPass = _hashPassword(motDePasse);

    print('💾 saveAgent: matricule=$matricule plain_len=${motDePasse.length} hash=${hashedPass.substring(0, 12)}…');

    await db.insert(
      'agent_cache',
      {
        'matricule':    matricule,
        'mot_de_passe': hashedPass,
        'employe_data': jsonEncode(employeData),
        'code_agence':  codeAgence,
        'cached_at':    DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final verify = await db.query('agent_cache', where: 'matricule = ?', whereArgs: [matricule]);
    if (verify.isNotEmpty) {
      final stored = verify.first['mot_de_passe'] as String;
      print('✅ saveAgent verified: stored=${stored.substring(0, 12)}… len=${stored.length} match=${stored == hashedPass}');
    }
  }

  static Future<Map<String, dynamic>?> getAgent(int matricule, String motDePasse) async {
    try {
      final db         = await LocalDatabase.db;
      final hashedPass = _hashPassword(motDePasse);

      print('🔍 getAgent START matricule=$matricule plain="${motDePasse}" plain_len=${motDePasse.length} input_hash=${hashedPass.substring(0, 12)}…');

      final allRows = await db.query('agent_cache');
      print('📦 agent_cache total rows: ${allRows.length}');
      for (final r in allRows) {
        final stored = r['mot_de_passe'] as String? ?? '';
        final isMatch = stored == hashedPass;
        print('  ROW matricule=${r['matricule']} stored_len=${stored.length} stored_prefix=${stored.length >= 12 ? stored.substring(0,12) : stored} input_prefix=${hashedPass.substring(0,12)} MATCH=$isMatch');
      }

      final byMatricule = await db.query('agent_cache', where: 'matricule = ?', whereArgs: [matricule]);

      if (byMatricule.isEmpty) {
        print('❌ getAgent: NO ROW for matricule=$matricule');
        return null;
      }

      final storedHash = byMatricule.first['mot_de_passe'] as String? ?? '';
      print('🔑 getAgent COMPARE stored_len=${storedHash.length} input_len=${hashedPass.length} MATCH=${storedHash == hashedPass}');

      if (storedHash != hashedPass) {
        print('❌ getAgent: MISMATCH stored=${storedHash.length >= 12 ? storedHash.substring(0,12) : storedHash}… input=${hashedPass.substring(0,12)}…');
        return null;
      }

      final row   = byMatricule.first;
      final agent = Map<String, dynamic>.from(jsonDecode(row['employe_data'] as String) as Map);
      final storedCodeAgence = row['code_agence'] as int?;
      if (storedCodeAgence != null) agent['code_agence'] = storedCodeAgence;

      print('✅ getAgent SUCCESS matricule=$matricule');
      return agent;

    } catch (e, stack) {
      print('❌ getAgent ERROR: $e');
      print(stack);
      return null;
    }
  }

  static Future<void> debugDump() async {
    try {
      final db   = await LocalDatabase.db;
      final rows = await db.query('agent_cache');
      print('📦 ===== agent_cache debugDump: ${rows.length} row(s) =====');
      for (final r in rows) {
        final hash = r['mot_de_passe'] as String? ?? '';
        print('  matricule   : ${r['matricule']}');
        print('  hash_preview: ${hash.length >= 12 ? hash.substring(0, 12) : hash}…');
        print('  hash_length : ${hash.length}  ← must be 64');
        print('  code_agence : ${r['code_agence']}');
        print('  cached_at   : ${r['cached_at']}');
      }
      if (rows.isEmpty) print('  (empty — login online first)');
      print('📦 ===== end debugDump =====');
    } catch (e) {
      print('❌ debugDump error: $e');
    }
  }

  static Future<void> updateCodeAgence(int matricule, int codeAgence) async {
    try {
      final db = await LocalDatabase.db;
      final rows = await db.query('agent_cache', where: 'matricule = ?', whereArgs: [matricule]);
      if (rows.isEmpty) return;
      final agent = Map<String, dynamic>.from(jsonDecode(rows.first['employe_data'] as String) as Map);
      agent['code_agence'] = codeAgence;
      await db.update('agent_cache',
        {'code_agence': codeAgence, 'employe_data': jsonEncode(agent), 'cached_at': DateTime.now().toIso8601String()},
        where: 'matricule = ?', whereArgs: [matricule]);
      print('✓ updateCodeAgence: matricule=$matricule code_agence=$codeAgence');
    } catch (e) {
      print('❌ updateCodeAgence: $e');
    }
  }

  static Future<void> deleteAgent(int matricule) async {
    try {
      final db = await LocalDatabase.db;
      await db.delete('agent_cache', where: 'matricule = ?', whereArgs: [matricule]);
      print('✓ deleteAgent: matricule=$matricule');
    } catch (e) {
      print('❌ deleteAgent: $e');
    }
  }
}