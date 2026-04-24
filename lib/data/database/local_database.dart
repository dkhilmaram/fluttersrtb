import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

class LocalDatabase {
  LocalDatabase._();

  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'srtb_offline.db');
    return openDatabase(
      path,
      version: 13,
      onCreate: (db, version) async {
        print('📦 Creating database v$version...');
        await _createAllTables(db);
        print('✓ Database created');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('⬆️ Upgrading database v$oldVersion → v$newVersion...');

        if (oldVersion < 7) {
          try {
            await db.execute(
              'ALTER TABLE voyage_cache ADD COLUMN server_statut TEXT',
            );
          } catch (e) { print('⚠️ v7 skipped: $e'); }
        }

        if (oldVersion < 8) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS reopen_pending (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                id_voyage   INTEGER NOT NULL UNIQUE,
                scope       TEXT    NOT NULL DEFAULT 'single',
                created_at  TEXT    NOT NULL,
                statut_sync TEXT    NOT NULL DEFAULT 'pending'
              )
            ''');
          } catch (e) { print('⚠️ v8 skipped: $e'); }
        }

        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS tickets (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                card_id   TEXT    NOT NULL UNIQUE,
                nom       TEXT    NOT NULL,
                type      TEXT    NOT NULL,
                expire    TEXT    NOT NULL,
                ligne     TEXT    NOT NULL DEFAULT '—',
                organisme TEXT    NOT NULL DEFAULT '—'
              )
            ''');
          } catch (e) { print('⚠️ v9 skipped: $e'); }
        }

        if (oldVersion < 10) {
          for (final col in [
            'ALTER TABLE ticket_vendu_local ADD COLUMN numero_titre  TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN nom_titulaire TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN organisme     TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN ligne_titre   TEXT',
          ]) {
            try { await db.execute(col); } catch (e) { print('⚠️ v10 col skipped: $e'); }
          }
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS scan_validation_log (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                id_voyage       INTEGER NOT NULL,
                id_segment      INTEGER NOT NULL DEFAULT 0,
                scan_mode       TEXT    NOT NULL,
                numero_titre    TEXT    NOT NULL,
                nom_titulaire   TEXT    NOT NULL,
                type_abonnement TEXT    NOT NULL,
                organisme       TEXT    NOT NULL DEFAULT '—',
                ligne_titre     TEXT    NOT NULL DEFAULT '—',
                expire          TEXT    NOT NULL,
                date_scan       TEXT    NOT NULL,
                matricule_agent INTEGER NOT NULL,
                statut_sync     TEXT    NOT NULL DEFAULT 'pending'
              )
            ''');
          } catch (e) { print('⚠️ v10 scan_log skipped: $e'); }
        }

        if (oldVersion < 11) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS heartbeat_log (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                payload    TEXT    NOT NULL,
                created_at TEXT    NOT NULL
              )
            ''');
          } catch (e) { print('⚠️ v11 skipped: $e'); }
        }

        if (oldVersion < 12) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS heartbeat_queue (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                payload    TEXT    NOT NULL,
                created_at TEXT    NOT NULL
              )
            ''');
          } catch (e) { print('⚠️ v12 skipped: $e'); }
        }

        // v13 — control_log for Contrôleur scan history
        if (oldVersion < 13) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS control_log (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                ticket_id        TEXT    NOT NULL,
                ticket_type      TEXT    NOT NULL,
                resultat         TEXT    NOT NULL,
                matricule_agent  INTEGER NOT NULL,
                date_controle    TEXT    NOT NULL,
                info_json        TEXT    NOT NULL DEFAULT '{}',
                statut_sync      TEXT    NOT NULL DEFAULT 'pending'
              )
            ''');
            print('✓ Created control_log table');
          } catch (e) { print('⚠️ v13 skipped: $e'); }
        }

        await _createAllTables(db);
        print('✓ Database upgraded');
      },
      onOpen: (db) async => _createAllTables(db),
    );
  }

  static Future<void> _createAllTables(Database db) async {
    const tables = [
      '''CREATE TABLE IF NOT EXISTS ticket_vendu_local (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_voyage        INTEGER NOT NULL,
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
        erreur           TEXT,
        numero_titre     TEXT,
        nom_titulaire    TEXT,
        organisme        TEXT,
        ligne_titre      TEXT
      )''',

      '''CREATE TABLE IF NOT EXISTS sync_log (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_ticket_local  INTEGER NOT NULL,
        date_tentative   TEXT    NOT NULL,
        statut           TEXT    NOT NULL,
        message          TEXT
      )''',

      '''CREATE TABLE IF NOT EXISTS tarif_cache (
        id_ligne     INTEGER PRIMARY KEY,
        arrets       TEXT    NOT NULL,
        prix_map     TEXT    NOT NULL,
        tarif_types  TEXT    NOT NULL,
        cached_at    TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS voyage_cache (
        id_voyage      INTEGER PRIMARY KEY,
        statut         TEXT    NOT NULL,
        server_statut  TEXT,
        cached_at      TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS voyages_cache (
        matricule  INTEGER PRIMARY KEY,
        data       TEXT    NOT NULL,
        cached_at  TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS segment_cache (
        id_voyage        INTEGER PRIMARY KEY,
        actif_segment    TEXT,
        prochain_segment TEXT,
        tous_segments    TEXT    NOT NULL,
        tous_clotures    INTEGER NOT NULL DEFAULT 0,
        cached_at        TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS agent_cache (
        matricule    INTEGER PRIMARY KEY,
        mot_de_passe TEXT    NOT NULL,
        employe_data TEXT    NOT NULL,
        cached_at    TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_voyage   INTEGER NOT NULL UNIQUE,
        created_at  TEXT    NOT NULL,
        statut_sync TEXT    NOT NULL DEFAULT 'pending'
      )''',

      '''CREATE TABLE IF NOT EXISTS segment_cloture_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_voyage   INTEGER NOT NULL,
        id_segment  INTEGER NOT NULL,
        open_next   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT    NOT NULL,
        statut_sync TEXT    NOT NULL DEFAULT 'pending',
        UNIQUE(id_voyage, id_segment)
      )''',

      '''CREATE TABLE IF NOT EXISTS reopen_pending (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_voyage   INTEGER NOT NULL UNIQUE,
        scope       TEXT    NOT NULL DEFAULT 'single',
        created_at  TEXT    NOT NULL,
        statut_sync TEXT    NOT NULL DEFAULT 'pending'
      )''',

      '''CREATE TABLE IF NOT EXISTS tickets (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id   TEXT    NOT NULL UNIQUE,
        nom       TEXT    NOT NULL,
        type      TEXT    NOT NULL,
        expire    TEXT    NOT NULL,
        ligne     TEXT    NOT NULL DEFAULT '—',
        organisme TEXT    NOT NULL DEFAULT '—'
      )''',

      '''CREATE TABLE IF NOT EXISTS scan_validation_log (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        id_voyage       INTEGER NOT NULL,
        id_segment      INTEGER NOT NULL DEFAULT 0,
        scan_mode       TEXT    NOT NULL,
        numero_titre    TEXT    NOT NULL,
        nom_titulaire   TEXT    NOT NULL,
        type_abonnement TEXT    NOT NULL,
        organisme       TEXT    NOT NULL DEFAULT '—',
        ligne_titre     TEXT    NOT NULL DEFAULT '—',
        expire          TEXT    NOT NULL,
        date_scan       TEXT    NOT NULL,
        matricule_agent INTEGER NOT NULL,
        statut_sync     TEXT    NOT NULL DEFAULT 'pending'
      )''',

      '''CREATE TABLE IF NOT EXISTS heartbeat_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        payload    TEXT    NOT NULL,
        created_at TEXT    NOT NULL
      )''',

      '''CREATE TABLE IF NOT EXISTS heartbeat_queue (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        payload    TEXT    NOT NULL,
        created_at TEXT    NOT NULL
      )''',

      // v13
      '''CREATE TABLE IF NOT EXISTS control_log (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id        TEXT    NOT NULL,
        ticket_type      TEXT    NOT NULL,
        resultat         TEXT    NOT NULL,
        matricule_agent  INTEGER NOT NULL,
        date_controle    TEXT    NOT NULL,
        info_json        TEXT    NOT NULL DEFAULT '{}',
        statut_sync      TEXT    NOT NULL DEFAULT 'pending'
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
}