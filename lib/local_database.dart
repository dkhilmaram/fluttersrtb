import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────
// Result type for shared offline cloture logic
// ─────────────────────────────────────────────────────────────

class OfflineClotureResult {
  final bool allDone;
  final Map<String, dynamic>? newActif;
  final Map<String, dynamic>? newProchain;
  final List<dynamic> updatedSegments;

  const OfflineClotureResult({
    required this.allDone,
    required this.newActif,
    required this.newProchain,
    required this.updatedSegments,
  });
}

// ─────────────────────────────────────────────────────────────
// LocalDatabase
// ─────────────────────────────────────────────────────────────

class LocalDatabase {
  // ── Singleton ──────────────────────────────────────────────
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'srtb_offline.db');
    return openDatabase(
      path,
      version: 6, // bumped: removed id_billet from schema assumptions
      onCreate: (db, version) async {
        print('📦 Creating database v$version...');
        await _createAllTables(db);
        print('✓ Database created');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('⬆️ Upgrading database v$oldVersion → v$newVersion...');
        await _createAllTables(db);
        print('✓ Database upgraded');
      },
      onOpen: (db) async {
        // Ensure tables exist on every open (handles fresh installs
        // or corrupted state without bumping the version).
        await _createAllTables(db);
      },
    );
  }

  // ── Schema ─────────────────────────────────────────────────
  // NOTE: voyages_cache stores the raw JSON list returned by the server.
  // id_billet was removed from the vente table on the server, so any
  // previously cached voyages that contain id_billet are harmless —
  // the Flutter code no longer reads that field.

  static Future<void> _createAllTables(Database db) async {
    const tables = [
      // Tickets sold locally (pending sync to server)
      '''CREATE TABLE IF NOT EXISTS ticket_vendu_local (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente         INTEGER NOT NULL,
        id_segment       INTEGER NOT NULL DEFAULT 0,
        point_depart     TEXT    NOT NULL,
        point_arrivee    TEXT    NOT NULL,
        type_tarif       TEXT    NOT NULL,
        quantite         INTEGER NOT NULL,
        prix_unitaire    REAL    NOT NULL,
        montant_total    REAL    NOT NULL,
        date_heure       TEXT    NOT NULL,
        matricule_agent  INTEGER NOT NULL,
        statut_sync      TEXT    NOT NULL DEFAULT 'pending',
        id_serveur       INTEGER UNIQUE,
        tentatives       INTEGER NOT NULL DEFAULT 0,
        erreur           TEXT
      )''',

      // Sync attempt log
      '''CREATE TABLE IF NOT EXISTS sync_log (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_ticket_local  INTEGER NOT NULL,
        date_tentative   TEXT    NOT NULL,
        statut           TEXT    NOT NULL,
        message          TEXT
      )''',

      // Cached tarifs per ligne
      '''CREATE TABLE IF NOT EXISTS tarif_cache (
        id_ligne     INTEGER PRIMARY KEY,
        arrets       TEXT    NOT NULL,
        prix_map     TEXT    NOT NULL,
        tarif_types  TEXT    NOT NULL,
        cached_at    TEXT    NOT NULL
      )''',

      // Per-voyage statut override (used to show cloture before server confirms)
      '''CREATE TABLE IF NOT EXISTS voyage_cache (
        id_vente       INTEGER PRIMARY KEY,
        statut         TEXT    NOT NULL,
        server_statut  TEXT,
        cached_at      TEXT    NOT NULL
      )''',

      // Full voyages list per agent (programmés and non-programmés stored
      // under positive and negative matricule respectively)
      '''CREATE TABLE IF NOT EXISTS voyages_cache (
        matricule  INTEGER PRIMARY KEY,
        data       TEXT    NOT NULL,
        cached_at  TEXT    NOT NULL
      )''',

      // Cached segment state for a voyage
      '''CREATE TABLE IF NOT EXISTS segment_cache (
        id_vente         INTEGER PRIMARY KEY,
        actif_segment    TEXT,
        prochain_segment TEXT,
        tous_segments    TEXT    NOT NULL,
        tous_clotures    INTEGER NOT NULL DEFAULT 0,
        cached_at        TEXT    NOT NULL
      )''',

      // Cached agent credentials for offline login
      '''CREATE TABLE IF NOT EXISTS agent_cache (
        matricule    INTEGER PRIMARY KEY,
        mot_de_passe TEXT    NOT NULL,
        employe_data TEXT    NOT NULL,
        cached_at    TEXT    NOT NULL
      )''',

      // Pending full-voyage clotures (offline → to sync when back online)
      '''CREATE TABLE IF NOT EXISTS cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente    INTEGER NOT NULL UNIQUE,
        created_at  TEXT    NOT NULL,
        statut_sync TEXT    NOT NULL DEFAULT 'pending'
      )''',

      // Pending segment-level clotures (offline → to sync when back online)
      '''CREATE TABLE IF NOT EXISTS segment_cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente    INTEGER NOT NULL,
        id_segment  INTEGER NOT NULL,
        open_next   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL,
        statut_sync TEXT    NOT NULL DEFAULT 'pending',
        UNIQUE(id_vente, id_segment)
      )''',
    ];

    for (final sql in tables) {
      try {
        await db.execute(sql);
      } catch (e) {
        print('⚠️ Table creation error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── OFFLINE CLOTURE (shared logic) ──────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<OfflineClotureResult> applyOfflineCloture({
    required int idVente,
    required int idSegment,
  }) async {
    final cached = await getSegments(idVente);

    final List<dynamic> allSegs =
        (cached?['segments'] as List<dynamic>?) ?? [];
    final Map<String, dynamic>? prochainSeg =
        cached?['prochain'] as Map<String, dynamic>?;

    // Apply cloture to the target segment; activate the next one if present
    final updatedSegments = allSegs.map((s) {
      final seg = Map<String, dynamic>.from(s as Map);
      if (seg['id_segment'] == idSegment) {
        seg['statut']       = 'cloture';
        seg['date_cloture'] = _now();
      } else if (prochainSeg != null &&
          seg['id_segment'] == prochainSeg['id_segment']) {
        seg['statut']         = 'actif';
        seg['date_ouverture'] = _now();
      }
      return seg;
    }).toList();

    Map<String, dynamic>? newActif;
    Map<String, dynamic>? newProchain;

    if (prochainSeg != null) {
      newActif = Map<String, dynamic>.from(prochainSeg)
        ..['statut']         = 'actif'
        ..['date_ouverture'] = _now();

      // Find the segment after newActif that is still en_attente
      bool passedActif = false;
      for (final s in updatedSegments) {
        final seg = s as Map<String, dynamic>;
        if (seg['id_segment'] == newActif['id_segment']) {
          passedActif = true;
          continue;
        }
        if (passedActif && seg['statut'] == 'en_attente') {
          newProchain = seg;
          break;
        }
      }
    }

    final allDone = prochainSeg == null ||
        updatedSegments
            .every((s) => (s as Map<String, dynamic>)['statut'] == 'cloture');

    await saveSegments(
      idVente:         idVente,
      actifSegment:    allDone ? null : newActif,
      prochainSegment: allDone ? null : newProchain,
      tousSecteurs:    updatedSegments,
      tousClotures:    allDone,
    );

    await saveSegmentCloturePending(
      idVente:    idVente,
      idSegment:  idSegment,
      openNext:   !allDone && prochainSeg != null,
    );

    print(
      '✓ applyOfflineCloture: vente=$idVente seg=$idSegment '
      'allDone=$allDone newActif=${newActif?['id_segment']}',
    );

    return OfflineClotureResult(
      allDone:          allDone,
      newActif:         newActif,
      newProchain:      newProchain,
      updatedSegments:  updatedSegments,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TICKET METHODS ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  /// Insert a ticket row. Use [conflictReplace] = true only when you want
  /// to overwrite an existing row; the default (IGNORE) safely skips
  /// duplicate server-id conflicts.
  static Future<int> insertTicket(
    Map<String, dynamic> ticket, {
    bool conflictReplace = false,
  }) async {
    try {
      return await (await db).insert(
        'ticket_vendu_local',
        ticket,
        conflictAlgorithm:
            conflictReplace ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('❌ insertTicket: $e');
      rethrow;
    }
  }

  /// Update only the id_segment of a cached ticket (called after server sync
  /// reveals the correct segment order for a row cached with id_segment = 0).
  static Future<void> updateTicketSegment(int localId, int idSegment) async {
    try {
      await (await db).update(
        'ticket_vendu_local',
        {'id_segment': idSegment},
        where: 'id = ?',
        whereArgs: [localId],
      );
      print('✓ updateTicketSegment: id=$localId → id_segment=$idSegment');
    } catch (e) {
      print('❌ updateTicketSegment: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingTickets() async {
    try {
      return await (await db).query(
        'ticket_vendu_local',
        where: 'statut_sync = ?',
        whereArgs: ['pending'],
      );
    } catch (e) {
      print('❌ getPendingTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTickets() async {
    try {
      return await (await db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ getUnsyncedTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTickets() async {
    try {
      return await (await db).query(
        'ticket_vendu_local',
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ getAllTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTicketsByVoyage(
      int idVente) async {
    try {
      return await (await db).query(
        'ticket_vendu_local',
        where: 'id_vente = ?',
        whereArgs: [idVente],
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ getTicketsByVoyage: $e');
      return [];
    }
  }

  static Future<void> deleteTicketsByVoyage(int idVente) async {
    try {
      await (await db).delete(
        'ticket_vendu_local',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ deleteTicketsByVoyage: vente=$idVente');
    } catch (e) {
      print('❌ deleteTicketsByVoyage: $e');
    }
  }

  static Future<void> markSynced(int id, int idServeur) async {
    try {
      await (await db).update(
        'ticket_vendu_local',
        {'statut_sync': 'synced', 'id_serveur': idServeur},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ markSynced: $e');
    }
  }

  static Future<void> markFailed(int id, String erreur) async {
    try {
      await (await db).rawUpdate('''
        UPDATE ticket_vendu_local
        SET statut_sync = 'failed', tentatives = tentatives + 1, erreur = ?
        WHERE id = ?
      ''', [erreur, id]);
    } catch (e) {
      print('❌ markFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SYNC LOG ────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> insertLog({
    required int idTicketLocal,
    required String statut,
    String? message,
  }) async {
    try {
      await (await db).insert('sync_log', {
        'id_ticket_local': idTicketLocal,
        'date_tentative':  DateTime.now().toIso8601String(),
        'statut':          statut,
        'message':         message,
      });
    } catch (e) {
      print('❌ insertLog: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      return await (await db).rawQuery('''
        SELECT l.*, t.point_depart, t.point_arrivee,
               t.montant_total, t.statut_sync, t.matricule_agent
        FROM sync_log l
        JOIN ticket_vendu_local t ON l.id_ticket_local = t.id
        ORDER BY l.date_tentative DESC
      ''');
    } catch (e) {
      print('❌ getLogs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── TARIF CACHE ─────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveTarifs(int idLigne, Map<String, dynamic> data) async {
    try {
      await (await db).insert(
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
      print('❌ saveTarifs: $e');
    }
  }

  static Future<Map<String, dynamic>?> getTarifs(int idLigne) async {
    try {
      final rows = await (await db).query(
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
      print('❌ getTarifs: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGE STATUT CACHE ──────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyageStatut(
    int idVente,
    String statut, {
    String? serverStatut,
  }) async {
    try {
      await (await db).insert(
        'voyage_cache',
        {
          'id_vente':      idVente,
          'statut':        statut,
          'server_statut': serverStatut,
          'cached_at':     DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ saveVoyageStatut: $e');
    }
  }

  /// Returns the locally-overridden statut for a voyage, or null if no
  /// override exists. Automatically discards the override if the server
  /// statut has changed (e.g. another device already synced the cloture).
  static Future<String?> getVoyageStatut(
    int idVente, {
    String? currentServerStatut,
  }) async {
    try {
      final rows = await (await db).query(
        'voyage_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      if (rows.isEmpty) return null;

      final row         = rows.first;
      final cached      = row['statut']        as String?;
      final serverSaved = row['server_statut'] as String?;

      // If the server has moved on, our local override is stale — discard it.
      if (currentServerStatut != null &&
          serverSaved != null &&
          currentServerStatut != serverSaved) {
        print(
          '🔄 Server statut changed ($serverSaved → $currentServerStatut) '
          'for vente $idVente — discarding local cache',
        );
        await clearVoyageStatut(idVente);
        await _clearCloturePendingForVente(idVente);
        return null;
      }

      return cached;
    } catch (e) {
      print('❌ getVoyageStatut: $e');
      return null;
    }
  }

  static Future<void> clearVoyageStatut(int idVente) async {
    try {
      await (await db).delete(
        'voyage_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ clearVoyageStatut: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── VOYAGES LIST CACHE ───────────────────────────────────────
  // Positive matricule  → voyages programmés
  // Negative matricule  → voyages non programmés
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveVoyages(int matricule, List<dynamic> voyages) async {
    try {
      await (await db).insert(
        'voyages_cache',
        {
          'matricule': matricule,
          'data':      jsonEncode(voyages),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ saveVoyages: matricule=$matricule (${voyages.length} items)');
    } catch (e) {
      print('❌ saveVoyages: $e');
    }
  }

  static Future<List<dynamic>?> getVoyages(int matricule) async {
    try {
      final rows = await (await db).query(
        'voyages_cache',
        where: 'matricule = ?',
        whereArgs: [matricule],
      );
      if (rows.isEmpty) {
        print('ℹ️ No voyages cached for matricule=$matricule');
        return null;
      }
      final list = jsonDecode(rows.first['data'] as String) as List<dynamic>;
      print('✓ getVoyages: matricule=$matricule (${list.length} items)');
      return list;
    } catch (e) {
      print('❌ getVoyages: $e');
      return null;
    }
  }

  /// Call this when a fresh server response arrives so old cached voyage
  /// statut overrides don't linger for voyages the server now shows as active.
  static Future<void> clearStaleVoyageStatuts(
      List<dynamic> serverVoyages) async {
    try {
      for (final v in serverVoyages) {
        final voyage   = v as Map<String, dynamic>;
        final idVente  = voyage['id_vente'] as int?;
        final statut   = voyage['statut']   as String?;
        if (idVente != null && statut != null) {
          await getVoyageStatut(idVente, currentServerStatut: statut);
        }
      }
    } catch (e) {
      print('❌ clearStaleVoyageStatuts: $e');
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
      await (await db).insert(
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
      print('✓ saveSegments: vente=$idVente tousClotures=$tousClotures');
    } catch (e) {
      print('❌ saveSegments: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSegments(int idVente) async {
    try {
      final rows = await (await db).query(
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
        'segments':     jsonDecode(row['tous_segments'] as String) as List<dynamic>,
        'tous_clotures': (row['tous_clotures'] as int?) == 1,
        'cached_at':     row['cached_at'],
      };
    } catch (e) {
      print('❌ getSegments: $e');
      return null;
    }
  }

  static Future<void> clearSegments(int idVente) async {
    try {
      await (await db).delete(
        'segment_cache',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ clearSegments: vente=$idVente');
    } catch (e) {
      print('❌ clearSegments: $e');
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
      await (await db).insert(
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
      print('✓ saveSegmentCloturePending: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ saveSegmentCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSegmentClotures() async {
    try {
      return await (await db).query(
        'segment_cloture_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ getPendingSegmentClotures: $e');
      return [];
    }
  }

  static Future<void> markSegmentClotureSynced(
      int idVente, int idSegment) async {
    try {
      await (await db).update(
        'segment_cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
      print('✓ markSegmentClotureSynced: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ markSegmentClotureSynced: $e');
    }
  }

  static Future<void> markSegmentClotureFailed(
      int idVente, int idSegment) async {
    try {
      await (await db).update(
        'segment_cloture_pending',
        {'statut_sync': 'failed'},
        where: 'id_vente = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
      print('✓ markSegmentClotureFailed: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ markSegmentClotureFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── AGENT CACHE ──────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveAgent({
    required int matricule,
    required String motDePasse,
    required Map<String, dynamic> employeData,
  }) async {
    try {
      await (await db).insert(
        'agent_cache',
        {
          'matricule':    matricule,
          'mot_de_passe': motDePasse,
          'employe_data': jsonEncode(employeData),
          'cached_at':    DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ saveAgent: matricule=$matricule');
    } catch (e) {
      print('❌ saveAgent: $e');
    }
  }

  static Future<Map<String, dynamic>?> getAgent(
      int matricule, String motDePasse) async {
    try {
      final rows = await (await db).query(
        'agent_cache',
        where: 'matricule = ? AND mot_de_passe = ?',
        whereArgs: [matricule, motDePasse],
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['employe_data'] as String)
          as Map<String, dynamic>;
    } catch (e) {
      print('❌ getAgent: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── CLOTURE PENDING (full voyage) ───────────────────────────
  // ═══════════════════════════════════════════════════════════

  static Future<void> saveCloturePending(int idVente) async {
    try {
      await (await db).insert(
        'cloture_pending',
        {
          'id_vente':    idVente,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ saveCloturePending: vente=$idVente');
    } catch (e) {
      print('❌ saveCloturePending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingClotures() async {
    try {
      return await (await db).query(
        'cloture_pending',
        where: "statut_sync = 'pending'",
      );
    } catch (e) {
      print('❌ getPendingClotures: $e');
      return [];
    }
  }

  static Future<void> markClotureSynced(int idVente) async {
    try {
      await (await db).update(
        'cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ markClotureSynced: vente=$idVente');
    } catch (e) {
      print('❌ markClotureSynced: $e');
    }
  }

  static Future<void> markClotureFailed(int idVente) async {
    try {
      await (await db).update(
        'cloture_pending',
        {'statut_sync': 'failed'},
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ markClotureFailed: vente=$idVente');
    } catch (e) {
      print('❌ markClotureFailed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── PRIVATE HELPERS ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  static String _now() =>
      DateTime.now().toString().substring(0, 19);

  /// Internal helper — clears cloture_pending for a voyage without going
  /// through the public API (avoids double-await-db calls).
  static Future<void> _clearCloturePendingForVente(int idVente) async {
    try {
      await (await db).delete(
        'cloture_pending',
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
    } catch (e) {
      print('❌ _clearCloturePendingForVente: $e');
    }
  }
}