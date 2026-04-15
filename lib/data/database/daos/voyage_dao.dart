import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class VoyageDao {
  // ═══════════════════════════════════════════════════════════
  // ── TARIF CACHE ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveTarifs(int idLigne, Map<String, dynamic> data) async {
    try {
      await (await LocalDatabase.db).insert(
        'tarif_cache',
        {
          'id_ligne':    idLigne,
          'arrets':      jsonEncode(data['arrets']),
          'prix_map':    jsonEncode(data['prix_map']),
          'tarif_types': jsonEncode(data['tarif_types']),
          'cached_at':   DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ VoyageDao.saveTarifs: $e');
    }
  }

  static Future<Map<String, dynamic>?> getTarifs(int idLigne) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'tarif_cache',
        where: 'id_ligne = ?',
        whereArgs: [idLigne],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'arrets':      jsonDecode(row['arrets']      as String),
        'prix_map':    jsonDecode(row['prix_map']    as String),
        'tarif_types': jsonDecode(row['tarif_types'] as String),
        'cached_at':   row['cached_at'],
      };
    } catch (e) {
      print('❌ VoyageDao.getTarifs: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGE STATUT CACHE ──────────────────────────────────────
  // Table schema (version 2+):
  //   id_vente      INTEGER PRIMARY KEY
  //   statut        TEXT
  //   server_statut TEXT    ← added in v2
  //   cached_at     TEXT
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyageStatut(
    int idVente,
    String statut, {
    String? serverStatut,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'voyage_cache',
        {
          'id_vente':      idVente,
          'statut':        statut,
          'server_statut': serverStatut,   // nullable — null when saving offline
          'cached_at':     DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ VoyageDao.saveVoyageStatut: $e');
    }
  }

  /// Returns the locally-cached statut for [idVente], or null if none.
  ///
  /// Pass [currentServerStatut] (the value just received from the server) to
  /// enable stale-cache detection: if the server has moved on since the cache
  /// was written, the local row is discarded and null is returned.
  ///
  /// Offline clôture paths intentionally omit [currentServerStatut] so that
  /// pending-cloture rows are never silently wiped.
  static Future<String?> getVoyageStatut(
    int idVente, {
    String? currentServerStatut,
  }) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyage_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      if (rows.isEmpty) return null;

      final row         = rows.first;
      final cached      = row['statut']        as String?;
      final serverSaved = row['server_statut'] as String?;

      // Stale-cache check: only fires when BOTH saved and current values are
      // known AND they differ — meaning the server changed state since we last
      // wrote the cache.
      if (currentServerStatut != null &&
          serverSaved           != null &&
          currentServerStatut   != serverSaved) {
        print(
          '🔄 VoyageDao: server statut changed '
          '($serverSaved → $currentServerStatut) '
          'for vente $idVente — discarding local cache',
        );
        await clearVoyageStatut(idVente);
        await _clearCloturePendingForVente(idVente);
        return null;
      }

      return cached;
    } catch (e) {
      print('❌ VoyageDao.getVoyageStatut: $e');
      return null;
    }
  }

  static Future<void> clearVoyageStatut(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'voyage_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ VoyageDao.clearVoyageStatut: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGES LIST CACHE ────────────────────────────────────────
  // Positive matricule  → voyages programmés
  // Negative matricule  → voyages non programmés
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyages(int matricule, List<dynamic> voyages) async {
    try {
      await (await LocalDatabase.db).insert(
        'voyages_cache',
        {
          'matricule': matricule,
          'data':      jsonEncode(voyages),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveVoyages: matricule=$matricule (${voyages.length} items)');
    } catch (e) {
      print('❌ VoyageDao.saveVoyages: $e');
    }
  }

  static Future<List<dynamic>?> getVoyages(int matricule) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyages_cache',
        where: 'matricule = ?',
        whereArgs: [matricule],
      );
      if (rows.isEmpty) {
        print('ℹ️ VoyageDao: No voyages cached for matricule=$matricule');
        return null;
      }
      final list = jsonDecode(rows.first['data'] as String) as List<dynamic>;
      print('✓ VoyageDao.getVoyages: matricule=$matricule (${list.length} items)');
      return list;
    } catch (e) {
      print('❌ VoyageDao.getVoyages: $e');
      return null;
    }
  }

  /// Cross-checks every voyage in [serverVoyages] against the local cache.
  /// Any row whose saved server_statut no longer matches the live value is
  /// automatically evicted (via [getVoyageStatut] with stale-check enabled).
  static Future<void> clearStaleVoyageStatuts(
      List<dynamic> serverVoyages) async {
    try {
      for (final v in serverVoyages) {
        final voyage  = v as Map<String, dynamic>;
        final idVente = voyage['id_vente'] as int?;
        final statut  = voyage['statut']   as String?;
        if (idVente != null && statut != null) {
          await getVoyageStatut(idVente, currentServerStatut: statut);
        }
      }
    } catch (e) {
      print('❌ VoyageDao.clearStaleVoyageStatuts: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SEGMENT CACHE ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveSegments({
    required int idVente,
    required Map<String, dynamic>? actifSegment,
    required Map<String, dynamic>? prochainSegment,
    required List<dynamic> tousSecteurs,
    required bool tousClotures,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'segment_cache',
        {
          'id_vente':         idVente,
          'actif_segment':    actifSegment    != null ? jsonEncode(actifSegment)    : null,
          'prochain_segment': prochainSegment != null ? jsonEncode(prochainSegment) : null,
          'tous_segments':    jsonEncode(tousSecteurs),
          'tous_clotures':    tousClotures ? 1 : 0,
          'cached_at':        DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveSegments: vente=$idVente tousClotures=$tousClotures');
    } catch (e) {
      print('❌ VoyageDao.saveSegments: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSegments(int idVente) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'segment_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'segment': row['actif_segment'] != null
            ? jsonDecode(row['actif_segment'] as String)
            : null,
        'prochain': row['prochain_segment'] != null
            ? jsonDecode(row['prochain_segment'] as String)
            : null,
        'segments':      jsonDecode(row['tous_segments'] as String) as List<dynamic>,
        'tous_clotures': (row['tous_clotures'] as int?) == 1,
        'cached_at':     row['cached_at'],
      };
    } catch (e) {
      print('❌ VoyageDao.getSegments: $e');
      return null;
    }
  }

  static Future<void> clearSegments(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'segment_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.clearSegments: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.clearSegments: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SEGMENT CLOTURE PENDING ──────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveSegmentCloturePending({
    required int idVente,
    required int idSegment,
    bool openNext = true,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'segment_cloture_pending',
        {
          'id_vente':    idVente,
          'id_segment':  idSegment,
          'open_next':   openNext ? 1 : 0,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveSegmentCloturePending: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ VoyageDao.saveSegmentCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSegmentClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'segment_cloture_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ VoyageDao.getPendingSegmentClotures: $e');
      return [];
    }
  }

  static Future<void> markSegmentClotureSynced(
      int idVente, int idSegment) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
      print('✓ VoyageDao.markSegmentClotureSynced: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ VoyageDao.markSegmentClotureSynced: $e');
    }
  }

  static Future<void> markSegmentClotureFailed(
      int idVente, int idSegment) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {'statut_sync': 'failed'},
        where: 'id_vente = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
      print('✓ VoyageDao.markSegmentClotureFailed: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ VoyageDao.markSegmentClotureFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── CLOTURE PENDING (full voyage) ───────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveCloturePending(int idVente) async {
    try {
      await (await LocalDatabase.db).insert(
        'cloture_pending',
        {
          'id_vente':    idVente,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveCloturePending: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.saveCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'cloture_pending',
        where: "statut_sync = 'pending'",
      );
    } catch (e) {
      print('❌ VoyageDao.getPendingClotures: $e');
      return [];
    }
  }

  static Future<void> markClotureSynced(int idVente) async {
    try {
      await (await LocalDatabase.db).update(
        'cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.markClotureSynced: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.markClotureSynced: $e');
    }
  }

  static Future<void> markClotureFailed(int idVente) async {
    try {
      await (await LocalDatabase.db).update(
        'cloture_pending',
        {'statut_sync': 'failed'},
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.markClotureFailed: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.markClotureFailed: $e');
    }
  }

  // ── Private helpers ─────────────────────────────────────────

  static Future<void> _clearCloturePendingForVente(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'cloture_pending',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ VoyageDao._clearCloturePendingForVente: $e');
    }
  }
}