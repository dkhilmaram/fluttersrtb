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
      // ⬆️ Bumped to 10 — adds scan columns to ticket_vendu_local
      //    + scan_validation_log table for QR/NFC audit trail
      version: 10,
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
            print('✓ Added server_statut to voyage_cache');
          } catch (e) {
            print('⚠️ server_statut migration skipped: $e');
          }
        }

        // v8 — reopen_pending
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
            print('✓ Created reopen_pending table');
          } catch (e) {
            print('⚠️ reopen_pending migration skipped: $e');
          }
        }

        // v9 — tickets table for NFC UID lookup
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
            print('✓ Created tickets table');
          } catch (e) {
            print('⚠️ tickets migration skipped: $e');
          }
        }

        // v10 — scan columns on ticket_vendu_local + scan_validation_log
        if (oldVersion < 10) {
          // Add scan-specific columns to ticket_vendu_local.
          // These are written by _validerNfc() but were missing from the schema.
          for (final col in [
            'ALTER TABLE ticket_vendu_local ADD COLUMN numero_titre  TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN nom_titulaire TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN organisme     TEXT',
            'ALTER TABLE ticket_vendu_local ADD COLUMN ligne_titre   TEXT',
          ]) {
            try {
              await db.execute(col);
              print('✓ $col');
            } catch (e) {
              print('⚠️ Migration skipped: $e');
            }
          }

          // Audit log — one row per validated scan (QR or NFC)
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS scan_validation_log (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                id_voyage      INTEGER NOT NULL,
                id_segment     INTEGER NOT NULL DEFAULT 0,
                scan_mode      TEXT    NOT NULL,          -- 'NFC' | 'QR'
                numero_titre   TEXT    NOT NULL,
                nom_titulaire  TEXT    NOT NULL,
                type_abonnement TEXT   NOT NULL,
                organisme      TEXT    NOT NULL DEFAULT '—',
                ligne_titre    TEXT    NOT NULL DEFAULT '—',
                expire         TEXT    NOT NULL,
                date_scan      TEXT    NOT NULL,
                matricule_agent INTEGER NOT NULL,
                statut_sync    TEXT    NOT NULL DEFAULT 'pending'
              )
            ''');
            print('✓ Created scan_validation_log table');
          } catch (e) {
            print('⚠️ scan_validation_log migration skipped: $e');
          }
        }

        await _createAllTables(db);
        print('✓ Database upgraded');
      },
      onOpen: (db) async => _createAllTables(db),
    );
  }

  static Future<void> _createAllTables(Database db) async {
    const tables = [
      // ── Core ticket sales (offline-first) ─────────────────
      // num_titre / nom_titulaire / organisme / ligne_titre added in v10
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
      // ── v9 — NFC subscriber card registry ─────────────────
      '''CREATE TABLE IF NOT EXISTS tickets (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id   TEXT    NOT NULL UNIQUE,
        nom       TEXT    NOT NULL,
        type      TEXT    NOT NULL,
        expire    TEXT    NOT NULL,
        ligne     TEXT    NOT NULL DEFAULT '—',
        organisme TEXT    NOT NULL DEFAULT '—'
      )''',
      // ── v10 — QR/NFC scan audit log ───────────────────────
      // One row per validated scan; synced to server when online.
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