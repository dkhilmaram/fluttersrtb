import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDatabase {
  static Database? _db;
  static bool _initialized = false;

  static Future<Database> get db async {
    _db ??= await _init();
    if (!_initialized) {
      await _ensureAllTablesExist(_db!);
      _initialized = true;
    }
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'srtb_offline.db');
    final database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        print('📦 Creating new database (v$version)...');
        await _createTables(db);
        print('✓ Database created successfully');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('⬆️ Upgrading database from v$oldVersion to v$newVersion...');
        await _ensureAllTablesExist(db);
        print('✓ Database upgraded successfully');
      },
      onOpen: (db) async {
        print('🔓 Database opened, checking schema...');
        await _ensureAllTablesExist(db);
      },
    );
    await _ensureAllTablesExist(database);
    return database;
  }

  static Future<void> _createTables(Database db) async {
    final tables = [
      '''CREATE TABLE IF NOT EXISTS ticket_vendu_local (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente         INTEGER NOT NULL,
        id_segment       INTEGER NOT NULL,
        point_depart     TEXT NOT NULL,
        point_arrivee    TEXT NOT NULL,
        type_tarif       TEXT NOT NULL,
        quantite         INTEGER NOT NULL,
        prix_unitaire    REAL NOT NULL,
        montant_total    REAL NOT NULL,
        date_heure       TEXT NOT NULL,
        matricule_agent  INTEGER NOT NULL,
        statut_sync      TEXT NOT NULL DEFAULT 'pending',
        id_serveur       INTEGER,
        tentatives       INTEGER NOT NULL DEFAULT 0,
        erreur           TEXT
      )''',
      '''CREATE TABLE IF NOT EXISTS sync_log (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_ticket_local  INTEGER NOT NULL,
        date_tentative   TEXT NOT NULL,
        statut           TEXT NOT NULL,
        message          TEXT
      )''',
      '''CREATE TABLE IF NOT EXISTS tarif_cache (
        id_ligne     INTEGER PRIMARY KEY,
        arrets       TEXT NOT NULL,
        prix_map     TEXT NOT NULL,
        tarif_types  TEXT NOT NULL,
        cached_at    TEXT NOT NULL
      )''',
      // ✅ Added server_statut column to know what the server last said
      '''CREATE TABLE IF NOT EXISTS voyage_cache (
        id_vente       INTEGER PRIMARY KEY,
        statut         TEXT NOT NULL,
        server_statut  TEXT,
        cached_at      TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS voyages_cache (
        matricule    INTEGER NOT NULL,
        data         TEXT NOT NULL,
        cached_at    TEXT NOT NULL,
        PRIMARY KEY (matricule)
      )''',
      '''CREATE TABLE IF NOT EXISTS segment_cache (
        id_vente         INTEGER PRIMARY KEY,
        actif_segment    TEXT,
        prochain_segment TEXT,
        tous_segments    TEXT NOT NULL,
        tous_clotures    INTEGER NOT NULL DEFAULT 0,
        cached_at        TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS agent_cache (
        matricule    INTEGER PRIMARY KEY,
        mot_de_passe TEXT NOT NULL,
        employe_data TEXT NOT NULL,
        cached_at    TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente    INTEGER NOT NULL UNIQUE,
        created_at  TEXT NOT NULL,
        statut_sync TEXT NOT NULL DEFAULT 'pending'
      )''',
      '''CREATE TABLE IF NOT EXISTS segment_cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_vente    INTEGER NOT NULL,
        id_segment  INTEGER NOT NULL,
        open_next   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL,
        statut_sync TEXT NOT NULL DEFAULT 'pending',
        UNIQUE(id_vente, id_segment)
      )''',
    ];

    for (final sql in tables) {
      try {
        await db.execute(sql);
      } catch (e) {
        print('⚠️ Table creation: $e');
      }
    }
  }

  static Future<void> _ensureAllTablesExist(Database db) async {
    try {
      await _createTables(db);
    } catch (e) {
      print('❌ Error ensuring tables: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // ── TICKET METHODS ──
  // ═══════════════════════════════════════════════

  static Future<int> insertTicket(Map<String, dynamic> ticket) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.insert('ticket_vendu_local', ticket);
    } catch (e) {
      print('❌ Error inserting ticket: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingTickets() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query('ticket_vendu_local',
          where: 'statut_sync = ?', whereArgs: ['pending']);
    } catch (e) {
      print('❌ Error getting pending tickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTickets() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ Error getting unsynced tickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTickets() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query('ticket_vendu_local',
          orderBy: 'date_heure DESC');
    } catch (e) {
      print('❌ Error getting all tickets: $e');
      return [];
    }
  }

  static Future<void> markSynced(int id, int idServeur) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.update(
        'ticket_vendu_local',
        {'statut_sync': 'synced', 'id_serveur': idServeur},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error marking synced: $e');
    }
  }

  static Future<void> markFailed(int id, String erreur) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.rawUpdate('''
        UPDATE ticket_vendu_local
        SET statut_sync = 'failed', tentatives = tentatives + 1, erreur = ?
        WHERE id = ?
      ''', [erreur, id]);
    } catch (e) {
      print('❌ Error marking failed: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getTicketsByVoyage(
      int idVente) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query(
        'ticket_vendu_local',
        where: 'id_vente = ?',
        whereArgs: [idVente],
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ Error getting tickets by voyage: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // ── SYNC LOG METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> insertLog({
    required int idTicketLocal,
    required String statut,
    String? message,
  }) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert('sync_log', {
        'id_ticket_local': idTicketLocal,
        'date_tentative': DateTime.now().toIso8601String(),
        'statut': statut,
        'message': message,
      });
    } catch (e) {
      print('❌ Error inserting log: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.rawQuery('''
        SELECT l.*, t.point_depart, t.point_arrivee, t.montant_total,
               t.statut_sync, t.matricule_agent
        FROM sync_log l
        JOIN ticket_vendu_local t ON l.id_ticket_local = t.id
        ORDER BY l.date_tentative DESC
      ''');
    } catch (e) {
      print('❌ Error getting logs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════
  // ── TARIF CACHE METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveTarifs(
      int idLigne, Map<String, dynamic> data) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'tarif_cache',
        {
          'id_ligne': idLigne,
          'arrets': jsonEncode(data['arrets']),
          'prix_map': jsonEncode(data['prix_map']),
          'tarif_types': jsonEncode(data['tarif_types']),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error saving tarifs: $e');
    }
  }

  static Future<Map<String, dynamic>?> getTarifs(int idLigne) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      final rows = await database.query('tarif_cache',
          where: 'id_ligne = ?', whereArgs: [idLigne]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'arrets': jsonDecode(row['arrets'] as String),
        'prix_map': jsonDecode(row['prix_map'] as String),
        'tarif_types': jsonDecode(row['tarif_types'] as String),
        'cached_at': row['cached_at'],
      };
    } catch (e) {
      print('❌ Error getting tarifs: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ── VOYAGE STATUT CACHE METHODS ──
  // ═══════════════════════════════════════════════

  /// Save the local pending statut (e.g. 'cloture_pending') AND remember
  /// what the server last told us ([serverStatut]) so we can detect when
  /// the server has been reset manually.
  static Future<void> saveVoyageStatut(
    int idVente,
    String statut, {
    String? serverStatut,
  }) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
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
      print('❌ Error saving voyage statut: $e');
    }
  }

  /// Returns the cached statut ONLY if it represents a locally-pending
  /// action (i.e. 'cloture_pending') AND the server hasn't moved on.
  /// If the server statut no longer matches what we last saw, we discard
  /// the local override so the server value wins.
  static Future<String?> getVoyageStatut(int idVente,
      {String? currentServerStatut}) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      final rows = await database.query('voyage_cache',
          where: 'id_vente = ?', whereArgs: [idVente]);
      if (rows.isEmpty) return null;

      final row          = rows.first;
      final cached       = row['statut']        as String?;
      final serverSaved  = row['server_statut'] as String?;

      // ── If the server statut has changed since we cached ──
      // e.g. someone manually reset the voyage to 'actif' on the DB,
      // the server will now return 'actif'. Discard our local override.
      if (currentServerStatut != null &&
          serverSaved != null &&
          currentServerStatut != serverSaved) {
        print(
          '🔄 Server statut changed ($serverSaved → $currentServerStatut) '
          'for vente $idVente — discarding local cache',
        );
        await database.delete('voyage_cache',
            where: 'id_vente = ?', whereArgs: [idVente]);
        // Also clear any stale cloture_pending queue entry
        await database.delete('cloture_pending',
            where: 'id_vente = ?', whereArgs: [idVente]);
        return null;
      }

      return cached;
    } catch (e) {
      print('❌ Error getting voyage statut: $e');
      return null;
    }
  }

  /// Hard-clear the local statut for a voyage (e.g. after a successful sync).
  static Future<void> clearVoyageStatut(int idVente) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.delete('voyage_cache',
          where: 'id_vente = ?', whereArgs: [idVente]);
    } catch (e) {
      print('❌ Error clearing voyage statut: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // ── VOYAGES LIST CACHE METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveVoyages(
      int matricule, List<dynamic> voyages) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'voyages_cache',
        {
          'matricule': matricule,
          'data': jsonEncode(voyages),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Voyages saved successfully');
    } catch (e) {
      print('❌ Error saving voyages: $e');
    }
  }

  static Future<List<dynamic>?> getVoyages(int matricule) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      final rows = await database.query('voyages_cache',
          where: 'matricule = ?', whereArgs: [matricule]);
      if (rows.isEmpty) {
        print('ℹ️ No voyages cached for matricule: $matricule');
        return null;
      }
      final result =
          jsonDecode(rows.first['data'] as String) as List<dynamic>;
      print('✓ Voyages retrieved (${result.length} items)');
      return result;
    } catch (e) {
      print('❌ Error getting voyages: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ── SEGMENT CACHE METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveSegments({
    required int idVente,
    required Map<String, dynamic>? actifSegment,
    required Map<String, dynamic>? prochainSegment,
    required List<dynamic> tousSecteurs,
    required bool tousClotures,
  }) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'segment_cache',
        {
          'id_vente':        idVente,
          'actif_segment':   actifSegment != null ? jsonEncode(actifSegment) : null,
          'prochain_segment':prochainSegment != null ? jsonEncode(prochainSegment) : null,
          'tous_segments':   jsonEncode(tousSecteurs),
          'tous_clotures':   tousClotures ? 1 : 0,
          'cached_at':       DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Segments cached successfully');
    } catch (e) {
      print('❌ Error saving segments: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSegments(int idVente) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      final rows = await database.query('segment_cache',
          where: 'id_vente = ?', whereArgs: [idVente]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'segment': row['actif_segment'] != null
            ? jsonDecode(row['actif_segment'] as String)
            : null,
        'prochain': row['prochain_segment'] != null
            ? jsonDecode(row['prochain_segment'] as String)
            : null,
        'segments':
            jsonDecode(row['tous_segments'] as String) as List<dynamic>,
        'tous_clotures': (row['tous_clotures'] as int?) == 1,
        'cached_at': row['cached_at'],
      };
    } catch (e) {
      print('❌ Error getting segments: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ── SEGMENT CLOTURE PENDING METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveSegmentCloturePending({
    required int idVente,
    required int idSegment,
    bool openNext = true,
  }) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'segment_cloture_pending',
        {
          'id_vente':   idVente,
          'id_segment': idSegment,
          'open_next':  openNext ? 1 : 0,
          'created_at': DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Segment cloture pending saved: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ Error saving segment cloture pending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSegmentClotures() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query(
        'segment_cloture_pending',
        where: "statut_sync = 'pending'",
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ Error getting pending segment clotures: $e');
      return [];
    }
  }

  static Future<void> markSegmentClotureSynced(
      int idVente, int idSegment) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.update(
        'segment_cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ? AND id_segment = ?',
        whereArgs: [idVente, idSegment],
      );
      print('✓ Segment cloture synced: vente=$idVente seg=$idSegment');
    } catch (e) {
      print('❌ Error marking segment cloture synced: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // ── AGENT CACHE METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveAgent({
    required int matricule,
    required String motDePasse,
    required Map<String, dynamic> employeData,
  }) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'agent_cache',
        {
          'matricule':    matricule,
          'mot_de_passe': motDePasse,
          'employe_data': jsonEncode(employeData),
          'cached_at':    DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Agent cached successfully');
    } catch (e) {
      print('❌ Error saving agent: $e');
    }
  }

  static Future<Map<String, dynamic>?> getAgent(
      int matricule, String motDePasse) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      final rows = await database.query(
        'agent_cache',
        where: 'matricule = ? AND mot_de_passe = ?',
        whereArgs: [matricule, motDePasse],
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['employe_data'] as String)
          as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error getting agent: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════
  // ── CLÔTURE PENDING METHODS ──
  // ═══════════════════════════════════════════════

  static Future<void> saveCloturePending(int idVente) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.insert(
        'cloture_pending',
        {
          'id_vente':    idVente,
          'created_at':  DateTime.now().toIso8601String(),
          'statut_sync': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ Clôture pending saved for vente $idVente');
    } catch (e) {
      print('❌ Error saving clôture pending: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingClotures() async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      return await database.query(
        'cloture_pending',
        where: "statut_sync = 'pending'",
      );
    } catch (e) {
      print('❌ Error getting pending clôtures: $e');
      return [];
    }
  }

  static Future<void> markClotureSynced(int idVente) async {
    final database = await db;
    await _ensureAllTablesExist(database);
    try {
      await database.update(
        'cloture_pending',
        {'statut_sync': 'synced'},
        where: 'id_vente = ?',
        whereArgs: [idVente],
      );
      print('✓ Clôture marked synced for vente $idVente');
    } catch (e) {
      print('❌ Error marking clôture synced: $e');
    }
  }
}