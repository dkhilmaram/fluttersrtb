import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class LigneDao {
  LigneDao._();

  // ═══════════════════════════════════════════════════════════
  // ── WRITE ───────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  /// Persist the full lignes list for [codeAgence].
  /// Each map must contain at least `id_ligne`.
  /// Uses REPLACE so every online sync refreshes the cache.
  static Future<void> cacheLignes(
    int codeAgence,
    List<Map<String, dynamic>> lignes,
  ) async {
    if (lignes.isEmpty) return;
    try {
      final db    = await LocalDatabase.db;
      final now   = DateTime.now().toIso8601String();
      final batch = db.batch();

      for (final ligne in lignes) {
        final idLigne = ligne['id_ligne'];
        if (idLigne == null) continue;
        batch.insert(
          'ligne_cache',
          {
            'code_agence': codeAgence,
            'id_ligne':    idLigne,
            'data':        jsonEncode(ligne),
            'cached_at':   now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      print('✓ LigneDao.cacheLignes: ${lignes.length} lignes '
          'for agence $codeAgence');
    } catch (e) {
      print('❌ LigneDao.cacheLignes: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── READ ────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  /// All cached lignes for [codeAgence]. Empty list when nothing cached.
  static Future<List<Map<String, dynamic>>> getCachedLignes(
    int codeAgence,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'ligne_cache',
        where:     'code_agence = ?',
        whereArgs: [codeAgence],
        orderBy:   'id_ligne ASC',
      );
      return rows
          .map((r) => Map<String, dynamic>.from(
                jsonDecode(r['data'] as String) as Map,
              ))
          .toList();
    } catch (e) {
      print('❌ LigneDao.getCachedLignes: $e');
      return [];
    }
  }

  /// ISO-8601 timestamp of the most recent cache write for [codeAgence].
  /// Returns null when nothing is cached yet.
  static Future<String?> getCacheTimestamp(int codeAgence) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'ligne_cache',
        columns:   ['cached_at'],
        where:     'code_agence = ?',
        whereArgs: [codeAgence],
        orderBy:   'cached_at DESC',
        limit:     1,
      );
      if (rows.isEmpty) return null;
      return rows.first['cached_at'] as String?;
    } catch (e) {
      print('❌ LigneDao.getCacheTimestamp: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── DELETE ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  /// Clear all cached lignes for [codeAgence].
  static Future<void> clearCache(int codeAgence) async {
    try {
      await (await LocalDatabase.db).delete(
        'ligne_cache',
        where:     'code_agence = ?',
        whereArgs: [codeAgence],
      );
      print('✓ LigneDao.clearCache: agence $codeAgence');
    } catch (e) {
      print('❌ LigneDao.clearCache: $e');
    }
  }
}