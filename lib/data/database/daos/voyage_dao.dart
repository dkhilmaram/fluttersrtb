import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class VoyageDao {
  // ═══════════════════════════════════════════════════════════
  // ── TARIF CACHE ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveTarifs(
    int idLigne,
    Map<String, dynamic> data,
  ) async {
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
        where:     'id_ligne = ?',
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
  // ── OFFLINE VOYAGE CACHE HELPERS ────────────────────────────
  //
  // Offline-created voyages live directly in voyages_cache
  // (same table as online voyages) with:
  //   • a temporary NEGATIVE id  (-(timestamp % 999999 + 1))
  //   • _is_pending = true
  //
  // On reconnect SyncService POSTs them to the server and
  // swaps the negative id for the real server id.
  //
  // No separate pending_voyages table is needed.
  // ═══════════════════════════════════════════════════════════

  /// Saves an offline-created voyage directly into voyages_cache
  /// with a negative local ID so it appears in the list immediately.
  static Future<int> saveOfflineVoyageToCache({
    required int matriculeNonProg,
    required Map<String, dynamic> voyageData,
  }) async {
    try {
      final localId = -(DateTime.now().millisecondsSinceEpoch % 999999 + 1);

      final existing = await getVoyages(matriculeNonProg) ?? [];

      final newVoyage = {
        ...voyageData,
        'id':          localId,
        'id_voyage':   localId,
        'statut':      'actif',
        'type':        'spontané',
        '_is_pending': true,
      };

      await saveVoyages(matriculeNonProg, [...existing, newVoyage]);
      print('💾 Offline voyage saved to cache localId=$localId');
      return localId;
    } catch (e) {
      print('❌ saveOfflineVoyageToCache: $e');
      return 0;
    }
  }

  /// After sync succeeds, replace the temp negative-ID entry with the real one.
  static Future<void> replacePendingVoyageInCache({
    required int matriculeNonProg,
    required int localId,
    required int realId,
  }) async {
    try {
      final existing = await getVoyages(matriculeNonProg) ?? [];
      final updated = existing.map((v) {
        final vid = (v['id_voyage'] ?? v['id']) as int?;
        if (vid == localId) {
          return {
            ...Map<String, dynamic>.from(v as Map),
            'id':          realId,
            'id_voyage':   realId,
            '_is_pending': false,
          };
        }
        return v;
      }).toList();
      await saveVoyages(matriculeNonProg, updated);
      print('✓ Replaced localId=$localId with realId=$realId in cache');
    } catch (e) {
      print('❌ replacePendingVoyageInCache: $e');
    }
  }

  /// Removes a pending voyage from cache (called if sync fails permanently).
  static Future<void> removePendingVoyageFromCache({
    required int matriculeNonProg,
    required int localId,
  }) async {
    try {
      final existing = await getVoyages(matriculeNonProg) ?? [];
      final updated = existing
          .where((v) => ((v['id_voyage'] ?? v['id']) as int?) != localId)
          .toList();
      await saveVoyages(matriculeNonProg, updated);
      print('✓ Removed localId=$localId from cache');
    } catch (e) {
      print('❌ removePendingVoyageFromCache: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── PENDING VOYAGE CREATION (legacy – kept for migration) ───
  // ═══════════════════════════════════════════════════════════

  /// @deprecated  Use saveOfflineVoyageToCache instead.
  static Future<void> savePendingVoyage(Map<String, dynamic> voyage) async {
    try {
      await (await LocalDatabase.db).insert(
        'pending_voyages',
        {
          'data':        jsonEncode(voyage),
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.savePendingVoyage (legacy): '
          '${voyage['depart']} → ${voyage['arrivee']}');
    } catch (e) {
      print('❌ VoyageDao.savePendingVoyage: $e');
    }
  }

  /// Read all pending (unsynced) voyage-creation rows (legacy table).
  static Future<List<Map<String, dynamic>>> getPendingVoyages() async {
    try {
      return await (await LocalDatabase.db).query(
        'pending_voyages',
        where:   "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ VoyageDao.getPendingVoyages: $e');
      return [];
    }
  }

  /// Delete a pending voyage row once the server has confirmed creation.
  static Future<void> markPendingVoyageSynced(int id) async {
    try {
      await (await LocalDatabase.db).delete(
        'pending_voyages',
        where:     'id = ?',
        whereArgs: [id],
      );
      print('✓ VoyageDao.markPendingVoyageSynced: id=$id');
    } catch (e) {
      print('❌ VoyageDao.markPendingVoyageSynced: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGE STATUT CACHE ──────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyageStatut(
    int idVente,
    String statut, {
    required String serverStatut,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'voyage_cache',
        {
          'id_voyage':     idVente,
          'statut':        statut,
          'server_statut': serverStatut,
          'cached_at':     DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveVoyageStatut: vente=$idVente '
          'statut=$statut serverStatut=$serverStatut');
    } catch (e) {
      print('❌ VoyageDao.saveVoyageStatut: $e');
    }
  }

  static Future<String?> getVoyageStatut(
    int idVente, {
    String? currentServerStatut,
  }) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyage_cache',
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      if (rows.isEmpty) return null;

      final row         = rows.first;
      final cached      = row['statut']        as String?;
      final serverSaved = row['server_statut'] as String?;

      if (currentServerStatut != null &&
          serverSaved != null &&
          currentServerStatut != serverSaved) {
        print('🔄 VoyageDao: server statut changed '
            '($serverSaved → $currentServerStatut) '
            'for vente $idVente — discarding local cache');
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
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.clearVoyageStatut: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.clearVoyageStatut: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGES LIST CACHE ────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyages(
    int matricule,
    List<dynamic> voyages,
  ) async {
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
      print('✓ VoyageDao.saveVoyages: matricule=$matricule '
          '(${voyages.length} items)');
    } catch (e) {
      print('❌ VoyageDao.saveVoyages: $e');
    }
  }

  static Future<List<dynamic>?> getVoyages(int matricule) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyages_cache',
        where:     'matricule = ?',
        whereArgs: [matricule],
      );
      if (rows.isEmpty) {
        print('ℹ️ VoyageDao: No voyages cached for matricule=$matricule');
        return null;
      }
      final list = jsonDecode(rows.first['data'] as String) as List<dynamic>;
      print('✓ VoyageDao.getVoyages: matricule=$matricule '
          '(${list.length} items)');
      return list;
    } catch (e) {
      print('❌ VoyageDao.getVoyages: $e');
      return null;
    }
  }

  /// Called after a successful server fetch.
  /// Merges server voyages with any locally-pending ones so they are not lost.
  static Future<List<dynamic>> mergeServerWithPending({
    required int matriculeNonProg,
    required List<dynamic> serverVoyages,
  }) async {
    try {
      final cached = await getVoyages(matriculeNonProg) ?? [];
      final pendingLocal = cached
          .where((v) => v['_is_pending'] == true)
          .toList();

      if (pendingLocal.isEmpty) return serverVoyages;

      // Remove any pending entries whose local id already appears on the server
      // (i.e. sync succeeded between fetches).
      final serverIds = serverVoyages
          .map((v) => (v['id_voyage'] ?? v['id']) as int?)
          .whereType<int>()
          .toSet();

      final stillPending = pendingLocal.where((v) {
        final vid = (v['id_voyage'] ?? v['id']) as int?;
        return vid == null || !serverIds.contains(vid);
      }).toList();

      print('🔀 Merging ${stillPending.length} pending offline voyage(s) '
          'with ${serverVoyages.length} server voyage(s)');

      return [...serverVoyages, ...stillPending];
    } catch (e) {
      print('❌ mergeServerWithPending: $e');
      return serverVoyages;
    }
  }

  static Future<void> clearStaleVoyageStatuts(
    List<dynamic> serverVoyages,
  ) async {
    try {
      for (final v in serverVoyages) {
        final voyage  = v as Map<String, dynamic>;
        final idVente = voyage['id_voyage'] as int?;
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
  // ── CLOTURE PENDING ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveCloturePending(int idVente) async {
    try {
      await _clearReopenPendingForVente(idVente);
      await (await LocalDatabase.db).insert(
        'cloture_pending',
        {
          'id_voyage':   idVente,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await saveVoyageStatut(idVente, 'cloture', serverStatut: 'actif');
      print('✓ VoyageDao.saveCloturePending: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.saveCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'cloture_pending',
        where:   "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
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
        where:     'id_voyage = ?',
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
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.markClotureFailed: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.markClotureFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── REOPEN PENDING ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveReopenPending(
    int idVente, {
    String scope = 'single',
  }) async {
    try {
      await _clearCloturePendingForVente(idVente);
      await (await LocalDatabase.db).insert(
        'reopen_pending',
        {
          'id_voyage':   idVente,
          'scope':       scope,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await saveVoyageStatut(idVente, 'actif', serverStatut: 'cloture');
      print('✓ VoyageDao.saveReopenPending: vente=$idVente scope=$scope');
    } catch (e) {
      print('❌ VoyageDao.saveReopenPending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingReopens() async {
    try {
      return await (await LocalDatabase.db).query(
        'reopen_pending',
        where:   "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ VoyageDao.getPendingReopens: $e');
      return [];
    }
  }

  static Future<bool> isReopenPending(int idVente) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'reopen_pending',
        where:     "id_voyage = ? AND statut_sync = 'pending'",
        whereArgs: [idVente],
      );
      return rows.isNotEmpty;
    } catch (e) {
      print('❌ VoyageDao.isReopenPending: $e');
      return false;
    }
  }

  static Future<void> markReopenSynced(int idVente) async {
    try {
      await (await LocalDatabase.db).update(
        'reopen_pending',
        {'statut_sync': 'synced'},
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.markReopenSynced: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.markReopenSynced: $e');
    }
  }

  static Future<void> markReopenFailed(int idVente) async {
    try {
      await (await LocalDatabase.db).update(
        'reopen_pending',
        {'statut_sync': 'failed'},
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      print('✓ VoyageDao.markReopenFailed: vente=$idVente');
    } catch (e) {
      print('❌ VoyageDao.markReopenFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── TICKET QUERY ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getUnsyncedTicketsForVente(
    int idVente,
  ) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where:     "id_voyage = ? AND statut_sync = 'pending'",
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ VoyageDao.getUnsyncedTicketsForVente: $e');
      return [];
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
          'id_voyage':        idVente,
          'actif_segment':    actifSegment    != null ? jsonEncode(actifSegment)    : null,
          'prochain_segment': prochainSegment != null ? jsonEncode(prochainSegment) : null,
          'tous_segments':    jsonEncode(tousSecteurs),
          'tous_clotures':    tousClotures ? 1 : 0,
          'cached_at':        DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveSegments: vente=$idVente '
          'tousClotures=$tousClotures');
    } catch (e) {
      print('❌ VoyageDao.saveSegments: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSegments(int idVente) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'segment_cache',
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'segment':       row['actif_segment']    != null
            ? jsonDecode(row['actif_segment']    as String)
            : null,
        'prochain':      row['prochain_segment'] != null
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
        where:     'id_voyage = ?',
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
          'id_voyage':   idVente,
          'id_segment':  idSegment,
          'open_next':   openNext ? 1 : 0,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ VoyageDao.saveSegmentCloturePending: '
          'vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ VoyageDao.saveSegmentCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSegmentClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'segment_cloture_pending',
        where:   "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ VoyageDao.getPendingSegmentClotures: $e');
      return [];
    }
  }

  static Future<void> markSegmentClotureSynced(
    int idVente,
    int idSegment,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {'statut_sync': 'synced'},
        where:     'id_voyage = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
    } catch (e) {
      print('❌ VoyageDao.markSegmentClotureSynced: $e');
    }
  }

  static Future<void> markSegmentClotureFailed(
    int idVente,
    int idSegment,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {'statut_sync': 'failed'},
        where:     'id_voyage = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
    } catch (e) {
      print('❌ VoyageDao.markSegmentClotureFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── PRIVATE HELPERS ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> _clearCloturePendingForVente(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'cloture_pending',
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ VoyageDao._clearCloturePendingForVente: $e');
    }
  }

  static Future<void> _clearReopenPendingForVente(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'reopen_pending',
        where:     'id_voyage = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ VoyageDao._clearReopenPendingForVente: $e');
    }
  }
}