import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class VoyageDao {
  // ═══════════════════════════════════════════════════════════
  // ── TARIF CACHE ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  saveTarifs(
    int idLigne,
    Map<
      String,
      dynamic
    >
    data,
  ) async {
    try {
      await (await LocalDatabase.db).insert(
        'tarif_cache',
        {
          'id_ligne': idLigne,
          'arrets': jsonEncode(
            data['arrets'],
          ),
          'prix_map': jsonEncode(
            data['prix_map'],
          ),
          'tarif_types': jsonEncode(
            data['tarif_types'],
          ),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveTarifs: $e',
      );
    }
  }

  static Future<
    Map<
      String,
      dynamic
    >?
  >
  getTarifs(
    int idLigne,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'tarif_cache',
        where: 'id_ligne = ?',
        whereArgs: [
          idLigne,
        ],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'arrets': jsonDecode(
          row['arrets']
              as String,
        ),
        'prix_map': jsonDecode(
          row['prix_map']
              as String,
        ),
        'tarif_types': jsonDecode(
          row['tarif_types']
              as String,
        ),
        'cached_at': row['cached_at'],
      };
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getTarifs: $e',
      );
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGE STATUT CACHE ──────────────────────────────────────
  // Table schema (v2+):
  //   id_voyage      INTEGER PRIMARY KEY
  //   statut        TEXT        ← local override ('cloture' / 'actif')
  //   server_statut TEXT        ← server value at the time of save
  //   cached_at     TEXT
  //
  // RULE: server_statut is ALWAYS stored so that clearStaleVoyageStatuts
  //       can detect genuine server-side changes without falsely wiping
  //       offline-pending rows.
  // ═══════════════════════════════════════════════════════════

  /// Save a local statut override for [idVente].
  ///
  /// [statut]       — the local value to apply  ('cloture' or 'actif')
  /// [serverStatut] — what the server currently reports for this voyage.
  ///                  Pass the server value you received; this anchors the
  ///                  stale-detection logic so a still-pending offline row
  ///                  is never wiped on the next fetch.
  static Future<
    void
  >
  saveVoyageStatut(
    int idVente,
    String statut, {
    required String serverStatut,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'voyage_cache',
        {
          'id_voyage': idVente,
          'statut': statut,
          'server_statut': serverStatut,
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        '✓ VoyageDao.saveVoyageStatut: vente=$idVente '
        'statut=$statut serverStatut=$serverStatut',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveVoyageStatut: $e',
      );
    }
  }

  /// Read the cached local statut for [idVente].
  ///
  /// If [currentServerStatut] is supplied AND it differs from the value that
  /// was stored in server_statut when the row was written, the cache row is
  /// discarded (the server moved on independently of our pending action).
  /// Returns null in that case so the caller falls back to the server value.
  static Future<
    String?
  >
  getVoyageStatut(
    int idVente, {
    String? currentServerStatut,
  }) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyage_cache',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final cached =
          row['statut']
              as String?;
      final serverSaved =
          row['server_statut']
              as String?;

      // Only discard when BOTH sides are known — if serverSaved is null the
      // row was written by an older code path; keep it rather than wiping.
      if (currentServerStatut !=
              null &&
          serverSaved !=
              null &&
          currentServerStatut !=
              serverSaved) {
        print(
          '🔄 VoyageDao: server statut changed '
          '($serverSaved → $currentServerStatut) '
          'for vente $idVente — discarding local cache',
        );
        await clearVoyageStatut(
          idVente,
        );
        await _clearCloturePendingForVente(
          idVente,
        );
        return null;
      }

      return cached;
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getVoyageStatut: $e',
      );
      return null;
    }
  }

  static Future<
    void
  >
  clearVoyageStatut(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).delete(
        'voyage_cache',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.clearVoyageStatut: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.clearVoyageStatut: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGES LIST CACHE ────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  saveVoyages(
    int matricule,
    List<
      dynamic
    >
    voyages,
  ) async {
    try {
      await (await LocalDatabase.db).insert(
        'voyages_cache',
        {
          'matricule': matricule,
          'data': jsonEncode(
            voyages,
          ),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        '✓ VoyageDao.saveVoyages: matricule=$matricule '
        '(${voyages.length} items)',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveVoyages: $e',
      );
    }
  }

  static Future<
    List<
      dynamic
    >?
  >
  getVoyages(
    int matricule,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'voyages_cache',
        where: 'matricule = ?',
        whereArgs: [
          matricule,
        ],
      );
      if (rows.isEmpty) {
        print(
          'ℹ️ VoyageDao: No voyages cached for matricule=$matricule',
        );
        return null;
      }
      final list =
          jsonDecode(
                rows.first['data']
                    as String,
              )
              as List<
                dynamic
              >;
      print(
        '✓ VoyageDao.getVoyages: matricule=$matricule '
        '(${list.length} items)',
      );
      return list;
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getVoyages: $e',
      );
      return null;
    }
  }

  /// Called after a successful server fetch.
  /// For each voyage in [serverVoyages], runs the stale-check so any
  /// voyage_cache row whose server_statut no longer matches the live server
  /// value is automatically discarded.
  static Future<
    void
  >
  clearStaleVoyageStatuts(
    List<
      dynamic
    >
    serverVoyages,
  ) async {
    try {
      for (final v in serverVoyages) {
        final voyage =
            v
                as Map<
                  String,
                  dynamic
                >;
        final idVente =
            voyage['id_voyage']
                as int?;
        final statut =
            voyage['statut']
                as String?;
        if (idVente !=
                null &&
            statut !=
                null) {
          await getVoyageStatut(
            idVente,
            currentServerStatut: statut,
          );
        }
      }
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.clearStaleVoyageStatuts: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── CLOTURE PENDING (full voyage) ───────────────────────────
  // Queued when the agent clôtures a voyage while offline.
  // SyncService drains this table on reconnect.
  // ═══════════════════════════════════════════════════════════

  // ── VoyageDao: fix saveCloturePending ──────────────────────
  static Future<
    void
  >
  saveCloturePending(
    int idVente,
  ) async {
    try {
      await _clearReopenPendingForVente(
        idVente,
      );
      await (await LocalDatabase.db).insert(
        'cloture_pending',
        {
          'id_voyage': idVente,
          'created_at': DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // ✅ FIX: reflect closure immediately in local UI
      await saveVoyageStatut(
        idVente,
        'cloture',
        serverStatut: 'actif',
      );
      print(
        '✓ VoyageDao.saveCloturePending: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveCloturePending: $e',
      );
    }
  }

  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getPendingClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'cloture_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getPendingClotures: $e',
      );
      return [];
    }
  }

  static Future<
    void
  >
  markClotureSynced(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'cloture_pending',
        {
          'statut_sync': 'synced',
        },
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.markClotureSynced: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markClotureSynced: $e',
      );
    }
  }

  static Future<
    void
  >
  markClotureFailed(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'cloture_pending',
        {
          'statut_sync': 'failed',
        },
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.markClotureFailed: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markClotureFailed: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── REOPEN PENDING ───────────────────────────────────────────
  // Queued when the agent reopens a voyage while offline.
  // scope = 'single'  → individual voyage
  // scope = 'journee' → full journée batch (synced one-by-one)
  // ═══════════════════════════════════════════════════════════

  // ── VoyageDao: fix saveReopenPending ───────────────────────
  static Future<
    void
  >
  saveReopenPending(
    int idVente, {
    String scope = 'single',
  }) async {
    try {
      await _clearCloturePendingForVente(
        idVente,
      );
      await (await LocalDatabase.db).insert(
        'reopen_pending',
        {
          'id_voyage': idVente,
          'scope': scope,
          'created_at': DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // ✅ FIX: reflect reopen immediately in local UI
      await saveVoyageStatut(
        idVente,
        'actif',
        serverStatut: 'cloture',
      );
      print(
        '✓ VoyageDao.saveReopenPending: vente=$idVente scope=$scope',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveReopenPending: $e',
      );
    }
  }

  // ── TicketDao: add the missing scoped query ─────────────────
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
        where: "id_voyage = ? AND statut_sync = 'pending'",
        whereArgs: [
          idVente,
        ],
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

  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getPendingReopens() async {
    try {
      return await (await LocalDatabase.db).query(
        'reopen_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getPendingReopens: $e',
      );
      return [];
    }
  }

  /// Returns true when a reopen is queued for [idVente] and has not yet been
  /// synced.  Used by _mergeLocalStatuts to override a server 'cloture' with
  /// 'actif' while the device is still offline.
  static Future<
    bool
  >
  isReopenPending(
    int idVente,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'reopen_pending',
        where: "id_voyage = ? AND statut_sync = 'pending'",
        whereArgs: [
          idVente,
        ],
      );
      return rows.isNotEmpty;
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.isReopenPending: $e',
      );
      return false;
    }
  }

  static Future<
    void
  >
  markReopenSynced(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'reopen_pending',
        {
          'statut_sync': 'synced',
        },
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.markReopenSynced: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markReopenSynced: $e',
      );
    }
  }

  static Future<
    void
  >
  markReopenFailed(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'reopen_pending',
        {
          'statut_sync': 'failed',
        },
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.markReopenFailed: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markReopenFailed: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SEGMENT CACHE ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  saveSegments({
    required int idVente,
    required Map<
      String,
      dynamic
    >?
    actifSegment,
    required Map<
      String,
      dynamic
    >?
    prochainSegment,
    required List<
      dynamic
    >
    tousSecteurs,
    required bool tousClotures,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'segment_cache',
        {
          'id_voyage': idVente,
          'actif_segment':
              actifSegment !=
                  null
              ? jsonEncode(
                  actifSegment,
                )
              : null,
          'prochain_segment':
              prochainSegment !=
                  null
              ? jsonEncode(
                  prochainSegment,
                )
              : null,
          'tous_segments': jsonEncode(
            tousSecteurs,
          ),
          'tous_clotures': tousClotures
              ? 1
              : 0,
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        '✓ VoyageDao.saveSegments: vente=$idVente '
        'tousClotures=$tousClotures',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveSegments: $e',
      );
    }
  }

  static Future<
    Map<
      String,
      dynamic
    >?
  >
  getSegments(
    int idVente,
  ) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'segment_cache',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'segment':
            row['actif_segment'] !=
                null
            ? jsonDecode(
                row['actif_segment']
                    as String,
              )
            : null,
        'prochain':
            row['prochain_segment'] !=
                null
            ? jsonDecode(
                row['prochain_segment']
                    as String,
              )
            : null,
        'segments':
            jsonDecode(
                  row['tous_segments']
                      as String,
                )
                as List<
                  dynamic
                >,
        'tous_clotures':
            (row['tous_clotures']
                as int?) ==
            1,
        'cached_at': row['cached_at'],
      };
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getSegments: $e',
      );
      return null;
    }
  }

  static Future<
    void
  >
  clearSegments(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).delete(
        'segment_cache',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
      print(
        '✓ VoyageDao.clearSegments: vente=$idVente',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.clearSegments: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SEGMENT CLOTURE PENDING ──────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  saveSegmentCloturePending({
    required int idVente,
    required int idSegment,
    bool openNext = true,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'segment_cloture_pending',
        {
          'id_voyage': idVente,
          'id_segment': idSegment,
          'open_next': openNext
              ? 1
              : 0,
          'created_at': DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        '✓ VoyageDao.saveSegmentCloturePending: '
        'vente=$idVente seg=$idSegment',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.saveSegmentCloturePending: $e',
      );
    }
  }

  static Future<
    List<
      Map<
        String,
        dynamic
      >
    >
  >
  getPendingSegmentClotures() async {
    try {
      return await (await LocalDatabase.db).query(
        'segment_cloture_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.getPendingSegmentClotures: $e',
      );
      return [];
    }
  }

  static Future<
    void
  >
  markSegmentClotureSynced(
    int idVente,
    int idSegment,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {
          'statut_sync': 'synced',
        },
        where: 'id_voyage = ? AND id_segment = ?',
        whereArgs: [
          idVente,
          idSegment,
        ],
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markSegmentClotureSynced: $e',
      );
    }
  }

  static Future<
    void
  >
  markSegmentClotureFailed(
    int idVente,
    int idSegment,
  ) async {
    try {
      await (await LocalDatabase.db).update(
        'segment_cloture_pending',
        {
          'statut_sync': 'failed',
        },
        where: 'id_voyage = ? AND id_segment = ?',
        whereArgs: [
          idVente,
          idSegment,
        ],
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao.markSegmentClotureFailed: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── PRIVATE HELPERS ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<
    void
  >
  _clearCloturePendingForVente(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).delete(
        'cloture_pending',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao._clearCloturePendingForVente: $e',
      );
    }
  }

  static Future<
    void
  >
  _clearReopenPendingForVente(
    int idVente,
  ) async {
    try {
      await (await LocalDatabase.db).delete(
        'reopen_pending',
        where: 'id_voyage = ?',
        whereArgs: [
          idVente,
        ],
      );
    } catch (
      e
    ) {
      print(
        '❌ VoyageDao._clearReopenPendingForVente: $e',
      );
    }
  }
}
