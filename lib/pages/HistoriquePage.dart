import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../local_database.dart';
import '../sync_service.dart';

const Color
navyDark = Color(
  0xFF0D1B3E,
);
const Color
navyMid = Color(
  0xFF1A3260,
);
const Color
navyLight = Color(
  0xFF1E4080,
);
const Color
gold = Color(
  0xFFD4A017,
);
const Color
goldLight = Color(
  0xFFF5C842,
);
const Color
surface = Color(
  0xFFF2F5FB,
);
const Color
cardWhite = Color(
  0xFFFFFFFF,
);

enum _TabType {
  online,
  syncedOffline,
  failed,
}

class HistoriquePage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  const HistoriquePage({
    super.key,
    required this.voyage,
  });

  @override
  State<
    HistoriquePage
  >
  createState() => _HistoriquePageState();
}

class _HistoriquePageState
    extends
        State<
          HistoriquePage
        >
    with
        SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<
    dynamic
  >
  _onlineTickets = [];
  List<
    dynamic
  >
  _syncedOfflineTickets = [];
  List<
    dynamic
  >
  _failedTickets = [];

  bool isLoading = true;
  bool isOffline = false;
  bool _isSyncing = false;
  String? errorMessage;
  String? _syncMessage;

  // ── Toast state ──
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  // ─────────────────────────────────────────────────────────────
  // Toast helper
  // ─────────────────────────────────────────────────────────────

  void _showToast(
    String msg, {
    bool isError = false,
    bool isWarning = false,
    bool isInfo = false,
  }) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
        ? Colors.orange.shade700
        : isInfo
        ? Colors.lightBlue.shade700
        : const Color(
            0xFF16A34A,
          );

    final icon = isError
        ? Icons.error_outline
        : isWarning
        ? Icons.offline_bolt
        : isInfo
        ? Icons.info_outline_rounded
        : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder:
          (
            _,
          ) => _ToastWidget(
            msg: msg,
            color: color,
            icon: icon,
          ),
    );

    _toastEntry = entry;
    Overlay.of(
      context,
    ).insert(
      entry,
    );

    _toastTimer = Timer(
      const Duration(
        milliseconds: 2800,
      ),
      () {
        entry.remove();
        if (_toastEntry ==
            entry)
          _toastEntry = null;
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
    );
    _fetchAll();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _tabs.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch
  // ─────────────────────────────────────────────────────────────

  Future<
    void
  >
  _fetchAll() async {
    setState(
      () {
        isLoading = true;
        errorMessage = null;
      },
    );

    final id =
        widget.voyage['id']
            as int?;
    if (id ==
        null) {
      setState(
        () {
          errorMessage = 'ID du voyage manquant';
          isLoading = false;
        },
      );
      _showToast(
        'ID du voyage manquant',
        isError: true,
      );
      return;
    }

    final localTickets = await LocalDatabase.getTicketsByVoyage(
      id,
    );

    final syncedOffline = localTickets
        .where(
          (
            t,
          ) =>
              t['statut_sync'] ==
              'synced',
        )
        .map(
          _mapLocalTicket,
        )
        .toList();

    final failed = localTickets
        .where(
          (
            t,
          ) =>
              t['statut_sync'] ==
                  'failed' ||
              t['statut_sync'] ==
                  'pending',
        )
        .map(
          _mapLocalTicket,
        )
        .toList();

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/voyages/$id/tickets',
            ),
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );

      if (response.statusCode ==
          200) {
        final data = jsonDecode(
          response.body,
        );
        if (data['success'] ==
            true) {
          final serverList =
              data['tickets']
                  as List<
                    dynamic
                  >? ??
              [];
          final syncedServerIds = syncedOffline
              .map(
                (
                  t,
                ) =>
                    t['id_serveur']
                        as int?,
              )
              .whereType<
                int
              >()
              .toSet();
          final onlineOnly = serverList
              .where(
                (
                  t,
                ) => !syncedServerIds.contains(
                  t['id_ticket']
                      as int?,
                ),
              )
              .toList();

          setState(
            () {
              _onlineTickets = onlineOnly;
              _syncedOfflineTickets = syncedOffline;
              _failedTickets = failed;
              isOffline = false;
              isLoading = false;
            },
          );

          final total =
              onlineOnly.length +
              syncedOffline.length +
              failed.length;
          _showToast(
            '$total ticket(s) chargés avec succès',
          );
          return;
        }
      }
    } catch (
      _
    ) {}

    setState(
      () {
        _onlineTickets = [];
        _syncedOfflineTickets = syncedOffline;
        _failedTickets = failed;
        isOffline = true;
        isLoading = false;
      },
    );

    _showToast(
      'Hors-ligne — tickets locaux uniquement',
      isWarning: true,
    );
  }

  Map<
    String,
    dynamic
  >
  _mapLocalTicket(
    Map<
      String,
      dynamic
    >
    t,
  ) => {
    'id_ticket': t['id'],
    'point_depart': t['point_depart'],
    'point_arrivee': t['point_arrivee'],
    'type_tarif': t['type_tarif'],
    'quantite':
        (t['quantite']
                    as num? ??
                0)
            .toInt(),
    'prix_unitaire':
        (t['prix_unitaire']
                    as num? ??
                0)
            .toInt(),
    'montant_total':
        (t['montant_total']
                    as num? ??
                0)
            .toInt(),
    'date_heure': t['date_heure'],
    'segment_ordre': null,
    'nom_ligne': null,
    'agent': null,
    'statut_sync': t['statut_sync'],
    'id_serveur': t['id_serveur'],
    'erreur': t['erreur'],
  };

  Future<
    void
  >
  _retrySync() async {
    setState(
      () {
        _isSyncing = true;
        _syncMessage = null;
      },
    );
    _showToast(
      'Synchronisation en cours…',
      isInfo: true,
    );

    final result = await SyncService.syncPending();
    await _fetchAll();

    setState(
      () {
        _isSyncing = false;
        _syncMessage = '✓ ${result.synced} synchronisés   ✗ ${result.failed} échoués';
      },
    );

    if (result.failed >
        0) {
      _showToast(
        '${result.synced} synchronisés · ${result.failed} échoués',
        isWarning: true,
      );
    } else if (result.synced >
        0) {
      _showToast(
        '${result.synced} ticket(s) synchronisés ✓',
      );
    } else {
      _showToast(
        'Aucun ticket à synchroniser',
        isInfo: true,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  Color _tarifColor(
    String type,
  ) {
    final t = type.toLowerCase();
    if (t.contains(
      'gratuit',
    ))
      return const Color(
        0xFF16A34A,
      );
    if (t.contains(
          'armée',
        ) ||
        t.contains(
          'armee',
        ) ||
        t.contains(
          'garde',
        ) ||
        t.contains(
          'police',
        ))
      return const Color(
        0xFF1E40AF,
      );
    if (t.contains(
          'douane',
        ) ||
        t.contains(
          'ministère',
        ) ||
        t.contains(
          'ministere',
        ))
      return const Color(
        0xFF374151,
      );
    if (t.contains(
          'municipalité',
        ) ||
        t.contains(
          'municipalite',
        ) ||
        t.contains(
          'scolaire',
        ) ||
        t.contains(
          'institution',
        ) ||
        t.contains(
          'autre',
        ))
      return const Color(
        0xFF065F46,
      );
    if (t.contains(
      'abonnement',
    ))
      return const Color(
        0xFF0369A1,
      );
    if (t.contains(
      'agent',
    ))
      return const Color(
        0xFF7C3AED,
      );
    if (t.contains(
      'nfc',
    ))
      return const Color(
        0xFF1E40AF,
      );
    if (t.contains(
          'barcode',
        ) ||
        t.contains(
          'scan',
        ))
      return const Color(
        0xFF6B21A8,
      );
    if (t.contains(
      '75',
    ))
      return const Color(
        0xFF7C3AED,
      );
    if (t.contains(
      '50',
    ))
      return const Color(
        0xFFD97706,
      );
    return navyMid;
  }

  IconData _tarifIcon(
    String type,
  ) {
    final t = type.toLowerCase();
    if (t.contains(
      'gratuit',
    ))
      return Icons.card_giftcard_rounded;
    if (t.contains(
          'armée',
        ) ||
        t.contains(
          'armee',
        ) ||
        t.contains(
          'garde',
        ))
      return Icons.shield_rounded;
    if (t.contains(
      'police',
    ))
      return Icons.local_police_rounded;
    if (t.contains(
      'douane',
    ))
      return Icons.account_balance_rounded;
    if (t.contains(
          'ministère',
        ) ||
        t.contains(
          'ministere',
        ))
      return Icons.domain_rounded;
    if (t.contains(
          'municipalité',
        ) ||
        t.contains(
          'municipalite',
        ))
      return Icons.location_city_rounded;
    if (t.contains(
      'scolaire',
    ))
      return Icons.school_rounded;
    if (t.contains(
          'institution',
        ) ||
        t.contains(
          'autre',
        ))
      return Icons.groups_rounded;
    if (t.contains(
      'abonnement',
    ))
      return Icons.confirmation_number_rounded;
    if (t.contains(
      'agent',
    ))
      return Icons.badge_rounded;
    if (t.contains(
      'nfc',
    ))
      return Icons.nfc_rounded;
    if (t.contains(
          'barcode',
        ) ||
        t.contains(
          'scan',
        ))
      return Icons.qr_code_2_rounded;
    if (t.contains(
          'réduit',
        ) ||
        t.contains(
          'reduit',
        ))
      return Icons.discount_rounded;
    return Icons.person_rounded;
  }

  String _formatTime(
    String? raw,
  ) {
    if (raw ==
        null)
      return '—';
    try {
      final dt = DateTime.parse(
        raw,
      );
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (
      _
    ) {
      return raw;
    }
  }

  String _formatDay(
    String? raw,
  ) {
    if (raw ==
        null)
      return '—';
    try {
      final dt = DateTime.parse(
        raw,
      );
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (
      _
    ) {
      return raw;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context,
  ) {
    final depart =
        widget.voyage['depart'] ??
        '?';
    final arrivee =
        widget.voyage['arrivee'] ??
        '?';

    return Scaffold(
      backgroundColor: surface,
      body: isLoading
          ? Column(
              children: [
                _buildSliverHeader(
                  depart,
                  arrivee,
                  asSliverBox: false,
                ),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: navyMid,
                    ),
                  ),
                ),
              ],
            )
          : errorMessage !=
                null
          ? Column(
              children: [
                _buildSliverHeader(
                  depart,
                  arrivee,
                  asSliverBox: false,
                ),
                Expanded(
                  child: _buildError(),
                ),
              ],
            )
          : NestedScrollView(
              headerSliverBuilder:
                  (
                    _,
                    __,
                  ) => [
                    SliverToBoxAdapter(
                      child: _buildSliverHeader(
                        depart,
                        arrivee,
                        asSliverBox: true,
                      ),
                    ),
                  ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _buildTicketList(
                    tickets: _onlineTickets,
                    emptyIcon: Icons.wifi_off_rounded,
                    emptyTitle: 'Aucun ticket en ligne',
                    emptySubtitle: 'Les tickets achetés avec connexion apparaîtront ici',
                    tabType: _TabType.online,
                  ),
                  _buildTicketList(
                    tickets: _syncedOfflineTickets,
                    emptyIcon: Icons.cloud_done_outlined,
                    emptyTitle: 'Aucun ticket synchronisé hors-ligne',
                    emptySubtitle: 'Les tickets sauvegardés hors-ligne puis synchronisés apparaîtront ici',
                    tabType: _TabType.syncedOffline,
                  ),
                  _buildTicketList(
                    tickets: _failedTickets,
                    emptyIcon: Icons.check_circle_outline_rounded,
                    emptyTitle: 'Aucun ticket échoué',
                    emptySubtitle: 'Tous les tickets ont été synchronisés avec succès',
                    tabType: _TabType.failed,
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────

  Widget _buildSliverHeader(
    String depart,
    String arrivee, {
    required bool asSliverBox,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            navyDark,
            navyMid,
            navyLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        52,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(
                  context,
                ),
                child: Container(
                  padding: const EdgeInsets.all(
                    8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historique des tickets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: goldLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            depart,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.white.withOpacity(
                              0.4,
                            ),
                            size: 11,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: goldLight,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            arrivee,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              if (isOffline)
                Container(
                  margin: const EdgeInsets.only(
                    right: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        color: Colors.white,
                        size: 10,
                      ),
                      SizedBox(
                        width: 4,
                      ),
                      Text(
                        'HORS-LIGNE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              // Sync button
              GestureDetector(
                onTap: _isSyncing
                    ? null
                    : _retrySync,
                child: Container(
                  padding: const EdgeInsets.all(
                    8,
                  ),
                  margin: const EdgeInsets.only(
                    right: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
              // Refresh button
              GestureDetector(
                onTap: _fetchAll,
                child: Container(
                  padding: const EdgeInsets.all(
                    8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),

          // ── Stats row ──
          if (!isLoading &&
              errorMessage ==
                  null)
            Row(
              children: [
                _headerStat(
                  Icons.wifi_rounded,
                  'En ligne',
                  '${_onlineTickets.length}',
                  const Color(
                    0xFF86EFAC,
                  ),
                ),
                _headerStat(
                  Icons.cloud_done_outlined,
                  'Sync. hors-ligne',
                  '${_syncedOfflineTickets.length}',
                  Colors.lightBlue.shade200,
                ),
                _headerStat(
                  Icons.cloud_off_outlined,
                  'Échoués',
                  '${_failedTickets.length}',
                  Colors.red.shade300,
                ),
              ],
            ),
          const SizedBox(
            height: 10,
          ),

          // ── Sync feedback ──
          if (_syncMessage !=
              null)
            Container(
              margin: const EdgeInsets.only(
                bottom: 8,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                _syncMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),

          // ── Tab bar ──
          TabBar(
            controller: _tabs,
            indicatorColor: goldLight,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorWeight: 3,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
            ),
            tabs: [
              Tab(
                text: 'En ligne (${_onlineTickets.length})',
              ),
              Tab(
                text: 'Sync. offline (${_syncedOfflineTickets.length})',
              ),
              Tab(
                text: 'Échoués (${_failedTickets.length})',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab list builder
  // ─────────────────────────────────────────────────────────────

  Widget _buildTicketList({
    required List<
      dynamic
    >
    tickets,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required _TabType tabType,
  }) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(
            32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: navyMid.withOpacity(
                    0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  color: navyMid,
                  size: 38,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
              ),
              if (tabType ==
                  _TabType.failed) ...[
                const SizedBox(
                  height: 24,
                ),
                _retryButton(),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: navyMid,
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        itemCount:
            tickets.length +
            (tabType ==
                    _TabType.failed
                ? 1
                : 0),
        itemBuilder:
            (
              _,
              i,
            ) {
              if (tabType ==
                      _TabType.failed &&
                  i ==
                      0) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16,
                  ),
                  child: _retryButton(),
                );
              }
              final idx =
                  tabType ==
                      _TabType.failed
                  ? i -
                        1
                  : i;
              final t =
                  tickets[idx]
                      as Map<
                        String,
                        dynamic
                      >;
              final prev =
                  idx >
                      0
                  ? tickets[idx -
                            1]
                        as Map<
                          String,
                          dynamic
                        >
                  : null;
              final showDay =
                  prev ==
                      null ||
                  _formatDay(
                        t['date_heure'],
                      ) !=
                      _formatDay(
                        prev['date_heure'],
                      );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDay) ...[
                    if (idx >
                        0)
                      const SizedBox(
                        height: 8,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: navyMid.withOpacity(
                                0.08,
                              ),
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                              border: Border.all(
                                color: navyMid.withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 11,
                                  color: navyMid,
                                ),
                                const SizedBox(
                                  width: 6,
                                ),
                                Text(
                                  _formatDay(
                                    t['date_heure'],
                                  ),
                                  style: const TextStyle(
                                    color: navyMid,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Divider(
                              color: navyMid.withOpacity(
                                0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildTicketCard(
                    t,
                    tabType,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              );
            },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Ticket card
  // ─────────────────────────────────────────────────────────────

  Widget _buildTicketCard(
    Map<
      String,
      dynamic
    >
    t,
    _TabType tabType,
  ) {
    final type =
        t['type_tarif']
            as String? ??
        '';
    final color = _tarifColor(
      type,
    );
    final isFree =
        ((t['montant_total']
                    as num? ??
                0)
            .toInt()) ==
        0;
    final qty =
        (t['quantite']
                    as num? ??
                1)
            .toInt();
    final erreur =
        t['erreur']
            as String?;

    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeLabel;
    final Color? borderColor;

    switch (tabType) {
      case _TabType.online:
        badgeColor = const Color(
          0xFF16A34A,
        );
        badgeIcon = Icons.wifi_rounded;
        badgeLabel = 'En ligne';
        borderColor = null;
        break;
      case _TabType.syncedOffline:
        badgeColor = Colors.lightBlue.shade600;
        badgeIcon = Icons.cloud_done_outlined;
        badgeLabel = 'Sync. ✓';
        borderColor = Colors.lightBlue.shade200;
        break;
      case _TabType.failed:
        final isPending =
            t['statut_sync'] ==
            'pending';
        badgeColor = isPending
            ? Colors.orange.shade700
            : Colors.red.shade600;
        badgeIcon = isPending
            ? Icons.cloud_upload_outlined
            : Icons.cloud_off_outlined;
        badgeLabel = isPending
            ? 'En attente'
            : 'Échoué';
        borderColor = badgeColor.withOpacity(
          0.4,
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border:
            borderColor !=
                null
            ? Border.all(
                color: borderColor,
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: navyMid.withOpacity(
              0.06,
            ),
            blurRadius: 10,
            offset: const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(
                0.06,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(
                  16,
                ),
              ),
              border: Border(
                bottom: BorderSide(
                  color: color.withOpacity(
                    0.12,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tarifIcon(
                            type,
                          ),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            type,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color: badgeColor.withOpacity(
                        0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeIcon,
                        color: badgeColor,
                        size: 11,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      _formatTime(
                        t['date_heure'],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (qty >
                    1) ...[
                  const SizedBox(
                    width: 8,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: navyMid.withOpacity(
                        0.08,
                      ),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                      border: Border.all(
                        color: navyMid.withOpacity(
                          0.15,
                        ),
                      ),
                    ),
                    child: Text(
                      '×$qty',
                      style: const TextStyle(
                        color: navyMid,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom row ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(
                                    0xFF16A34A,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Flexible(
                                child: Text(
                                  t['point_depart'] ??
                                      '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: navyDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 13,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Flexible(
                                child: Text(
                                  t['point_arrivee'] ??
                                      '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: navyDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (t['segment_ordre'] !=
                                  null)
                                _smallTag(
                                  Icons.route,
                                  'Segment ${t['segment_ordre']}',
                                  navyMid,
                                  navyMid.withOpacity(
                                    0.08,
                                  ),
                                ),
                              if (t['nom_ligne'] !=
                                  null)
                                _smallTag(
                                  Icons.directions_bus,
                                  t['nom_ligne'],
                                  Colors.grey.shade500,
                                  Colors.grey.shade50,
                                ),
                              if (tabType !=
                                  _TabType.online)
                                _smallTag(
                                  Icons.storage_rounded,
                                  'Stocké localement',
                                  Colors.orange.shade700,
                                  Colors.orange.shade50,
                                ),
                            ],
                          ),
                          if (t['agent'] !=
                              null) ...[
                            const SizedBox(
                              height: 6,
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 12,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Flexible(
                                  child: Text(
                                    t['agent'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (qty >
                            1)
                          Text(
                            '${t['prix_unitaire']} ms / ticket',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          isFree
                              ? 'GRATUIT'
                              : '${t['montant_total']} ms',
                          style: TextStyle(
                            fontSize: isFree
                                ? 16
                                : 18,
                            fontWeight: FontWeight.bold,
                            color: isFree
                                ? const Color(
                                    0xFF16A34A,
                                  )
                                : navyDark,
                          ),
                        ),
                        if (!isFree)
                          Text(
                            'millimes',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (erreur !=
                        null &&
                    tabType ==
                        _TabType.failed) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                      border: Border.all(
                        color: Colors.red.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 13,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            erreur,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Micro-widgets
  // ─────────────────────────────────────────────────────────────

  Widget _headerStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(
                0.6,
              ),
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(
            height: 4,
          ),
        ],
      ),
    );
  }

  Widget _smallTag(
    IconData icon,
    String label,
    Color fg,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          8,
        ),
        border: Border.all(
          color: fg.withOpacity(
            0.25,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: fg,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryButton() {
    return SizedBox(
      height: 46,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          12,
        ),
        child: InkWell(
          onTap: _isSyncing
              ? null
              : _retrySync,
          borderRadius: BorderRadius.circular(
            12,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  navyDark,
                  navyLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                12,
              ),
              boxShadow: [
                BoxShadow(
                  color: navyMid.withOpacity(
                    0.3,
                  ),
                  blurRadius: 8,
                  offset: const Offset(
                    0,
                    3,
                  ),
                ),
              ],
            ),
            child: Center(
              child: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Réessayer la synchronisation',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(
                20,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: Colors.red.shade400,
                size: 44,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            _retryButton(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Toast widget — top-right, slides in from the right
// ════════════════════════════════════════════════════

class _ToastWidget
    extends
        StatefulWidget {
  final String msg;
  final Color color;
  final IconData icon;

  const _ToastWidget({
    required this.msg,
    required this.color,
    required this.icon,
  });

  @override
  State<
    _ToastWidget
  >
  createState() => _ToastWidgetState();
}

class _ToastWidgetState
    extends
        State<
          _ToastWidget
        >
    with
        SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<
    double
  >
  _opacity;
  late final Animation<
    Offset
  >
  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 220,
      ),
    );
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );
    _slide =
        Tween<
              Offset
            >(
              begin: const Offset(
                1.0,
                0,
              ),
              end: Offset.zero,
            )
            .animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: Curves.easeOut,
              ),
            );

    _ctrl.forward();

    Future.delayed(
      const Duration(
        milliseconds: 2300,
      ),
      () {
        if (mounted) _ctrl.reverse();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Positioned(
      top:
          MediaQuery.of(
            context,
          ).padding.top +
          16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 300,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(
                  12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(
                      0.35,
                    ),
                    blurRadius: 16,
                    offset: const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Flexible(
                    child: Text(
                      widget.msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
