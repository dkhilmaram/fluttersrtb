import 'package:sqflite/sqflite.dart';
import '../local_database.dart';

class TicketDao {
  // ═══════════════════════════════════════════════════════════
  // ── INSERT / UPDATE
  // ═══════════════════════════════════════════════════════════

  /// Insert a ticket row.
  /// [conflictReplace] = true overwrites an existing row;
  /// the default (IGNORE) safely skips duplicate server-id conflicts.
  static Future<int> insertTicket(
    Map<String, dynamic> ticket, {
    bool conflictReplace = false,
  }) async {
    try {
      return await (await LocalDatabase.db).insert(
        'ticket_vendu_local',
        ticket,
        conflictAlgorithm: conflictReplace
            ? ConflictAlgorithm.replace
            : ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('❌ TicketDao.insertTicket: $e');
      rethrow;
    }
  }

  /// Update only the id_segment of a cached ticket.
  static Future<void> updateTicketSegment(int localId, int idSegment) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {'id_segment': idSegment},
        where: 'id = ?',
        whereArgs: [localId],
      );
      print('✓ TicketDao.updateTicketSegment: id=$localId → id_segment=$idSegment');
    } catch (e) {
      print('❌ TicketDao.updateTicketSegment: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── QUERIES
  // ═══════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getPendingTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending'",
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getPendingTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getUnsyncedTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedTicketsForVente(
    int idVente,
  ) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where:
            "id_voyage = ? AND (statut_sync = 'pending' OR statut_sync = 'failed')",
        whereArgs: [idVente],
        orderBy: 'date_heure ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getUnsyncedTicketsForVente: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTickets() async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ TicketDao.getAllTickets: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTicketsByVoyage(
    int idVente,
  ) async {
    try {
      return await (await LocalDatabase.db).query(
        'ticket_vendu_local',
        where: 'id_voyage = ?',
        whereArgs: [idVente],
        orderBy: 'date_heure DESC',
      );
    } catch (e) {
      print('❌ TicketDao.getTicketsByVoyage: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── NFC CARD REGISTRY
  // ═══════════════════════════════════════════════════════════

  /// Look up an NFC card by its hardware UID.
  /// Returns the card data if the UID exists in the registry,
  /// or null if the card is not registered → scan is rejected.
  static Future<Map<String, dynamic>?> findByCardId(String cardId) async {
    try {
      final rows = await (await LocalDatabase.db).query(
        'tickets',
        columns: ['nom', 'type', 'expire', 'ligne', 'organisme'],
        where: 'card_id = ?',
        whereArgs: [cardId.toUpperCase().trim()],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('❌ TicketDao.findByCardId: $e');
      return null;
    }
  }
  /// Returns true if [numeroTitre] has already been validated today
/// for the given [idVoyage] — prevents double-scanning.
static Future<bool> isAlreadyScannedToday({
  required String numeroTitre,
  required int idVoyage,
}) async {
  try {
    final todayStart = DateTime.now();
    final datePrefix =
        '${todayStart.year}-${todayStart.month.toString().padLeft(2, '0')}-${todayStart.day.toString().padLeft(2, '0')}';

    final rows = await (await LocalDatabase.db).query(
      'scan_validation_log',
      columns: ['id'],
      where:
          "numero_titre = ? AND id_voyage = ? AND date_scan LIKE ? AND statut_sync != 'failed'",
      whereArgs: [numeroTitre, idVoyage, '$datePrefix%'],
      limit: 1,
    );

    return rows.isNotEmpty;
  } catch (e) {
    print('❌ TicketDao.isAlreadyScannedToday: $e');
    return false; // fail open — don't block scan on DB error
  }
}

  /// Register a new NFC card in the local registry.
  /// Uses REPLACE so re-registering updates the existing card data.
  /// Call this when syncing subscriber cards from your server.
  static Future<void> registerCard({
    required String cardId,
    required String nom,
    required String type,      // 'mensuel' | 'annuel' | 'étudiant' | etc.
    required String expire,    // ISO date: '2025-12-31'
    required String ligne,
    required String organisme,
  }) async {
    try {
      await (await LocalDatabase.db).insert(
        'tickets',
        {
          'card_id':   cardId.toUpperCase().trim(),
          'nom':       nom,
          'type':      type,
          'expire':    expire,
          'ligne':     ligne,
          'organisme': organisme,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✓ TicketDao.registerCard: $cardId → $nom');
    } catch (e) {
      print('❌ TicketDao.registerCard: $e');
      rethrow;
    }
  }

  /// Remove a card from the registry.
  static Future<void> deleteCard(String cardId) async {
    try {
      await (await LocalDatabase.db).delete(
        'tickets',
        where: 'card_id = ?',
        whereArgs: [cardId.toUpperCase().trim()],
      );
      print('✓ TicketDao.deleteCard: $cardId');
    } catch (e) {
      print('❌ TicketDao.deleteCard: $e');
    }
  }

  /// All registered NFC cards — useful for an admin management screen.
  static Future<List<Map<String, dynamic>>> getAllCards() async {
    try {
      return await (await LocalDatabase.db).query(
        'tickets',
        orderBy: 'nom ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getAllCards: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SCAN VALIDATION LOG  (v10)
  // One row per validated QR / NFC scan — synced later by SyncService.
  // ═══════════════════════════════════════════════════════════

  /// Insert a new scan validation record (offline-first).
  /// Returns the local row id, or -1 on error.
  static Future<int> insertScanLog({
    required int idVoyage,
    required int idSegment,
    required String scanMode,        // 'NFC' | 'QR'
    required String numeroTitre,
    required String nomTitulaire,
    required String typeAbonnement,
    required String organisme,
    required String ligneTitre,
    required String expire,
    required String dateScan,        // ISO 8601 datetime
    required int matriculeAgent,
  }) async {
    try {
      final id = await (await LocalDatabase.db).insert(
        'scan_validation_log',
        {
          'id_voyage':       idVoyage,
          'id_segment':      idSegment,
          'scan_mode':       scanMode,
          'numero_titre':    numeroTitre,
          'nom_titulaire':   nomTitulaire,
          'type_abonnement': typeAbonnement,
          'organisme':       organisme,
          'ligne_titre':     ligneTitre,
          'expire':          expire,
          'date_scan':       dateScan,
          'matricule_agent': matriculeAgent,
          'statut_sync':     'pending',
        },
      );
      print('✓ TicketDao.insertScanLog: id=$id mode=$scanMode titre=$numeroTitre');
      return id;
    } catch (e) {
      print('❌ TicketDao.insertScanLog: $e');
      return -1;
    }
  }

  /// All scan logs not yet successfully synced to the server.
  static Future<List<Map<String, dynamic>>> getUnsyncedScanLogs() async {
    try {
      return await (await LocalDatabase.db).query(
        'scan_validation_log',
        where: "statut_sync = 'pending' OR statut_sync = 'failed'",
        orderBy: 'date_scan ASC',
      );
    } catch (e) {
      print('❌ TicketDao.getUnsyncedScanLogs: $e');
      return [];
    }
  }

  /// Mark a scan log row as successfully synced.
  static Future<void> markScanLogSynced(int id) async {
    try {
      await (await LocalDatabase.db).update(
        'scan_validation_log',
        {'statut_sync': 'synced'},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✓ TicketDao.markScanLogSynced: id=$id');
    } catch (e) {
      print('❌ TicketDao.markScanLogSynced: $e');
    }
  }

  /// Mark a scan log row as failed (will retry on next sync).
  static Future<void> markScanLogFailed(int id, String erreur) async {
    try {
      await (await LocalDatabase.db).update(
        'scan_validation_log',
        {'statut_sync': 'failed'},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('❌ TicketDao.markScanLogFailed: id=$id err=$erreur');
    } catch (e) {
      print('❌ TicketDao.markScanLogFailed (outer): $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── DELETE
  // ═══════════════════════════════════════════════════════════

  static Future<void> deleteTicketsByVoyage(int idVente) async {
    try {
      await (await LocalDatabase.db).delete(
        'ticket_vendu_local',
        where: 'id_voyage = ?',
        whereArgs: [idVente],
      );
      print('✓ TicketDao.deleteTicketsByVoyage: vente=$idVente');
    } catch (e) {
      print('❌ TicketDao.deleteTicketsByVoyage: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ── SYNC STATUS UPDATES
  // ═══════════════════════════════════════════════════════════

  static Future<void> markSynced(int id, int idServeur) async {
    try {
      await (await LocalDatabase.db).update(
        'ticket_vendu_local',
        {'statut_sync': 'synced', 'id_serveur': idServeur},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✓ TicketDao.markSynced: id=$id → serveur=$idServeur');
    } catch (e) {
      print('❌ TicketDao.markSynced: $e');
    }
  }

  static Future<void> markFailed(int id, String erreur) async {
    try {
      await (await LocalDatabase.db).rawUpdate(
        '''
        UPDATE ticket_vendu_local
        SET statut_sync = 'failed',
            tentatives  = tentatives + 1,
            erreur      = ?
        WHERE id = ?
        ''',
        [erreur, id],
      );
      print('✓ TicketDao.markFailed: id=$id');
    } catch (e) {
      print('❌ TicketDao.markFailed: $e');
    }
  }
}