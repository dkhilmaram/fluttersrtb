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

    print('💾 saveAgent: matricule=$matricule hash=${hashedPass.substring(0, 12)}…');

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
  }

  static Future<Map<String, dynamic>?> getAgent(int matricule, String motDePasse) async {
    try {
      final db         = await LocalDatabase.db;
      final hashedPass = _hashPassword(motDePasse);

      print('🔍 getAgent: matricule=$matricule');

      final byMatricule = await db.query(
        'agent_cache',
        where:     'matricule = ?',
        whereArgs: [matricule],
      );

      if (byMatricule.isEmpty) {
        print('❌ getAgent: no row for matricule=$matricule');
        return null;
      }

      final storedHash = byMatricule.first['mot_de_passe'] as String? ?? '';
      if (storedHash != hashedPass) {
        print('❌ getAgent: password mismatch for matricule=$matricule');
        return null;
      }

      final row   = byMatricule.first;
      final agent = Map<String, dynamic>.from(
          jsonDecode(row['employe_data'] as String) as Map);
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

  // ── Check if matricule exists in cache (ignores password) ──
  static Future<bool> agentExists(int matricule) async {
    try {
      final db   = await LocalDatabase.db;
      final rows = await db.query(
        'agent_cache',
        where:     'matricule = ?',
        whereArgs: [matricule],
        limit:     1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      print('❌ agentExists: $e');
      return false;
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
      final db   = await LocalDatabase.db;
      final rows = await db.query(
        'agent_cache',
        where:     'matricule = ?',
        whereArgs: [matricule],
      );
      if (rows.isEmpty) return;
      final agent = Map<String, dynamic>.from(
          jsonDecode(rows.first['employe_data'] as String) as Map);
      agent['code_agence'] = codeAgence;
      await db.update(
        'agent_cache',
        {
          'code_agence':  codeAgence,
          'employe_data': jsonEncode(agent),
          'cached_at':    DateTime.now().toIso8601String(),
        },
        where:     'matricule = ?',
        whereArgs: [matricule],
      );
      print('✓ updateCodeAgence: matricule=$matricule code_agence=$codeAgence');
    } catch (e) {
      print('❌ updateCodeAgence: $e');
    }
  }

  static Future<void> deleteAgent(int matricule) async {
    try {
      final db = await LocalDatabase.db;
      await db.delete(
        'agent_cache',
        where:     'matricule = ?',
        whereArgs: [matricule],
      );
      print('✓ deleteAgent: matricule=$matricule');
    } catch (e) {
      print('❌ deleteAgent: $e');
    }
  }
}