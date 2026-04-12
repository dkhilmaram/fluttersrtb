import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../local_database.dart';
import 'vente_tickets.dart';

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

class VoyageProgrammePage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  agent;
  const VoyageProgrammePage({
    super.key,
    required this.agent,
  });

  @override
  State<
    VoyageProgrammePage
  >
  createState() => _VoyageProgrammePageState();
}

class _VoyageProgrammePageState
    extends
        State<
          VoyageProgrammePage
        >
    with
        SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<
    dynamic
  >
  voyagesProgrammes = [];
  bool isLoadingProgrammes = true;
  bool isOfflineProgrammes = false;
  String? errorProgrammes;

  List<
    dynamic
  >
  voyagesNonProgrammes = [];
  bool isLoadingNonProgrammes = true;
  bool isOfflineNonProgrammes = false;
  String? errorNonProgrammes;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
    );
    _fetchProgrammes();
    _fetchNonProgrammes();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Toast — top-right slide-in
  // ─────────────────────────────────────────────────────────────

  void _showToast(
    String msg, {
    bool isError = false,
    bool isWarning = false,
    bool isOffline = false,
  }) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final Color color;
    final IconData icon;

    if (isOffline) {
      color = const Color(
        0xFF8B1A1A,
      );
      icon = Icons.wifi_off_rounded;
    } else if (isError) {
      color = const Color(
        0xFF8B1A1A,
      );
      icon = Icons.error_outline;
    } else if (isWarning) {
      color = Colors.orange.shade700;
      icon = Icons.offline_bolt;
    } else {
      color = const Color(
        0xFF16A34A,
      );
      icon = Icons.check_circle_outline;
    }

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
  // Getters
  // ─────────────────────────────────────────────────────────────

  int get _matricule =>
      widget.agent['matricule_agent'] ??
      widget.agent['matricule'];

  int get _matriculeNonProg => -_matricule;

  int get _activeIndex {
    for (
      int i = 0;
      i <
          voyagesProgrammes.length;
      i++
    ) {
      if (voyagesProgrammes[i]['statut'] !=
          'cloture')
        return i;
    }
    return -1;
  }

  // ─────────────────────────────────────────────────────────────
  // Merge local offline statuts
  // ─────────────────────────────────────────────────────────────

  Future<
    List<
      dynamic
    >
  >
  _mergeLocalStatuts(
    List<
      dynamic
    >
    voyages,
  ) async {
    final pendingClotures = await LocalDatabase.getPendingClotures();
    final pendingIds = pendingClotures
        .map(
          (
            r,
          ) =>
              r['id_vente']
                  as int,
        )
        .toSet();

    final merged =
        <
          dynamic
        >[];
    for (final v in voyages) {
      final voyage =
          Map<
            String,
            dynamic
          >.from(
            v
                as Map,
          );
      final idVente =
          (voyage['id_vente'] ??
                  voyage['id'])
              as int?;

      if (idVente !=
          null) {
        if (pendingIds.contains(
          idVente,
        )) {
          voyage['statut'] = 'cloture';
        } else {
          final localStatut = await LocalDatabase.getVoyageStatut(
            idVente,
          );
          if (localStatut ==
                  'cloture' ||
              localStatut ==
                  'cloture_pending') {
            voyage['statut'] = 'cloture';
          }
        }
      }
      merged.add(
        voyage,
      );
    }
    return merged;
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch — Programmés
  // ─────────────────────────────────────────────────────────────

  Future<
    void
  >
  _fetchProgrammes() async {
    setState(
      () {
        isLoadingProgrammes = true;
        errorProgrammes = null;
      },
    );

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/ventes/programmees/$_matricule',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );

      if (response.statusCode ==
          200) {
        final list =
            jsonDecode(
                  response.body,
                )['voyages']
                as List<
                  dynamic
                >;
        await LocalDatabase.saveVoyages(
          _matricule,
          list,
        );
        setState(
          () {
            voyagesProgrammes = list;
            isOfflineProgrammes = false;
            isLoadingProgrammes = false;
          },
        );
        return;
      }
    } catch (
      _
    ) {}

    final cached = await LocalDatabase.getVoyages(
      _matricule,
    );
    if (cached !=
        null) {
      final merged = await _mergeLocalStatuts(
        cached,
      );
      setState(
        () {
          voyagesProgrammes = merged;
          isOfflineProgrammes = true;
          isLoadingProgrammes = false;
        },
      );
      _maybeShowOfflineToast();
    } else {
      setState(
        () {
          errorProgrammes =
              'Hors-ligne — aucune donnée en cache.\n'
              'Connectez-vous une première fois pour activer le mode hors-ligne.';
          isLoadingProgrammes = false;
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch — Non programmés
  // ─────────────────────────────────────────────────────────────

  Future<
    void
  >
  _fetchNonProgrammes() async {
    setState(
      () {
        isLoadingNonProgrammes = true;
        errorNonProgrammes = null;
      },
    );

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/ventes/agent/$_matricule',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );

      if (response.statusCode ==
          200) {
        final all =
            jsonDecode(
                  response.body,
                )['voyages']
                as List<
                  dynamic
                >;
        final list = all
            .where(
              (
                v,
              ) =>
                  v['type'] !=
                  'programmé',
            )
            .map(
              (
                v,
              ) {
                final voyage =
                    Map<
                      String,
                      dynamic
                    >.from(
                      v
                          as Map,
                    );
                voyage['matricule_agent'] ??= _matricule;
                voyage['id_appareil'] ??= widget.agent['id_appareil'];
                voyage['id_billet'] ??= widget.agent['id_billet'];
                voyage['code_agence'] ??= widget.agent['code_agence'];
                voyage['statut'] ??= 'actif';
                return voyage;
              },
            )
            .toList();

        await LocalDatabase.saveVoyages(
          _matriculeNonProg,
          list,
        );
        setState(
          () {
            voyagesNonProgrammes = list;
            isOfflineNonProgrammes = false;
            isLoadingNonProgrammes = false;
          },
        );
        return;
      }
    } catch (
      _
    ) {}

    final cached = await LocalDatabase.getVoyages(
      _matriculeNonProg,
    );
    if (cached !=
        null) {
      final list = cached.map(
        (
          v,
        ) {
          final voyage =
              Map<
                String,
                dynamic
              >.from(
                v
                    as Map,
              );
          voyage['matricule_agent'] ??= _matricule;
          voyage['id_appareil'] ??= widget.agent['id_appareil'];
          voyage['id_billet'] ??= widget.agent['id_billet'];
          voyage['code_agence'] ??= widget.agent['code_agence'];
          voyage['statut'] ??= 'actif';
          return voyage;
        },
      ).toList();

      final merged = await _mergeLocalStatuts(
        list,
      );
      setState(
        () {
          voyagesNonProgrammes = merged;
          isOfflineNonProgrammes = true;
          isLoadingNonProgrammes = false;
        },
      );
      _maybeShowOfflineToast();
    } else {
      setState(
        () {
          errorNonProgrammes =
              'Hors-ligne — aucune donnée en cache.\n'
              'Connectez-vous une première fois pour activer le mode hors-ligne.';
          isLoadingNonProgrammes = false;
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Show offline toast only once even if both tabs are offline
  // ─────────────────────────────────────────────────────────────

  void _maybeShowOfflineToast() {
    if (_toastEntry ==
        null) {
      _showToast(
        'Mode hors-ligne · données en cache',
        isOffline: true,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String
  _getDate(
    String? dh,
  ) =>
      dh
          ?.split(
            ' ',
          )
          .first ??
      '';
  String
  _getTime(
    String? dh,
  ) =>
      (dh !=
              null &&
          dh
                  .split(
                    ' ',
                  )
                  .length >
              1)
      ? dh
            .split(
              ' ',
            )[1]
            .substring(
              0,
              5,
            )
      : '';

  void _openVoyage(
    Map<
      String,
      dynamic
    >
    voyage,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (
              _,
            ) => VenteTicketsPage(
              voyage: voyage,
            ),
      ),
    ).then(
      (
        _,
      ) {
        _fetchProgrammes();
        _fetchNonProgrammes();
      },
    );
  }

  void _showLockedSnack() {
    _showToast(
      "Terminez le voyage en cours avant d'accéder à celui-ci",
      isWarning: true,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: surface,
      body: NestedScrollView(
        headerSliverBuilder:
            (
              _,
              __,
            ) => [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
            ],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProgrammesTab(),
                  _buildNonProgrammesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final agent = widget.agent;
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
        24,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
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
          ),
          const SizedBox(
            height: 18,
          ),
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(
              8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                18,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.3,
                  ),
                  blurRadius: 16,
                  offset: const Offset(
                    0,
                    6,
                  ),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder:
                  (
                    _,
                    __,
                    ___,
                  ) => const Icon(
                    Icons.directions_bus,
                    size: 44,
                    color: navyMid,
                  ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          const Text(
            'S R T B',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            'Mes Voyages',
            style: TextStyle(
              color: Colors.white.withOpacity(
                0.7,
              ),
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(
                30,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(
                  0.2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: goldLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  '${agent['prenom']} ${agent['nom']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab bar
  // ─────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: navyDark,
      child: TabBar(
        controller: _tabController,
        indicatorColor: goldLight,
        indicatorWeight: 3,
        labelColor: goldLight,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                ),
                const SizedBox(
                  width: 5,
                ),
                const Flexible(
                  child: Text(
                    'Programmés',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                _tabBadge(
                  voyagesProgrammes.length,
                  isLoadingProgrammes,
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_bus_outlined,
                  size: 14,
                ),
                const SizedBox(
                  width: 5,
                ),
                const Flexible(
                  child: Text(
                    'Non programmés',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                _tabBadge(
                  voyagesNonProgrammes.length,
                  isLoadingNonProgrammes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 1 — Programmés
  // ─────────────────────────────────────────────────────────────

  Widget _buildProgrammesTab() {
    if (isLoadingProgrammes) {
      return const Center(
        child: CircularProgressIndicator(
          color: navyMid,
        ),
      );
    }
    if (errorProgrammes !=
        null) {
      return _buildError(
        errorProgrammes!,
        _fetchProgrammes,
      );
    }

    final activeIdx = _activeIndex;

    return Column(
      children: [
        if (voyagesProgrammes.isNotEmpty)
          _buildStatsBar(
            [
              _statTile(
                Icons.directions_bus_outlined,
                'Total',
                '${voyagesProgrammes.length}',
                navyMid,
              ),
              _statTile(
                Icons.check_circle_outline,
                'Clôturés',
                '${voyagesProgrammes.where((v) => v['statut'] == 'cloture').length}',
                Colors.grey,
              ),
              _statTile(
                Icons.play_circle_outline,
                'En cours',
                activeIdx >=
                        0
                    ? '1'
                    : '0',
                const Color(
                  0xFF16A34A,
                ),
              ),
            ],
          ),
        Expanded(
          child: voyagesProgrammes.isEmpty
              ? _buildEmpty(
                  'Aucun voyage programmé',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    40,
                  ),
                  itemCount: voyagesProgrammes.length,
                  itemBuilder:
                      (
                        _,
                        i,
                      ) {
                        final v =
                            voyagesProgrammes[i]
                                as Map<
                                  String,
                                  dynamic
                                >;
                        final isCloture =
                            v['statut'] ==
                            'cloture';
                        final isActive =
                            i ==
                            activeIdx;
                        final isLocked =
                            !isCloture &&
                            !isActive;

                        final Color accent, bgColor, borderColor;
                        if (isCloture) {
                          accent = Colors.grey;
                          bgColor = Colors.grey.shade50;
                          borderColor = Colors.grey.shade200;
                        } else if (isActive) {
                          accent = navyMid;
                          bgColor = const Color(
                            0xFFEBF0FF,
                          );
                          borderColor = navyLight;
                        } else {
                          accent = Colors.orange.shade700;
                          bgColor = Colors.orange.shade50;
                          borderColor = Colors.orange.shade200;
                        }

                        return _buildVoyageCard(
                          voyage: v,
                          accent: accent,
                          bgColor: bgColor,
                          borderColor: borderColor,
                          isActive: isActive,
                          isCloture: isCloture,
                          isLocked: isLocked,
                          onTap: isLocked
                              ? _showLockedSnack
                              : () => _openVoyage(
                                  v,
                                ),
                          extraLabel: isLocked
                              ? 'En attente du voyage précédent'
                              : null,
                          extraLabelColor: Colors.orange.shade600,
                        );
                      },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tab 2 — Non programmés
  // ─────────────────────────────────────────────────────────────

  Widget _buildNonProgrammesTab() {
    if (isLoadingNonProgrammes) {
      return const Center(
        child: CircularProgressIndicator(
          color: navyMid,
        ),
      );
    }
    if (errorNonProgrammes !=
        null) {
      return _buildError(
        errorNonProgrammes!,
        _fetchNonProgrammes,
      );
    }

    return Column(
      children: [
        if (voyagesNonProgrammes.isNotEmpty)
          _buildStatsBar(
            [
              _statTile(
                Icons.directions_bus_outlined,
                'Total',
                '${voyagesNonProgrammes.length}',
                navyMid,
              ),
              _statTile(
                Icons.check_circle_outline,
                'Clôturés',
                '${voyagesNonProgrammes.where((v) => v['statut'] == 'cloture').length}',
                Colors.grey,
              ),
              _statTile(
                Icons.play_circle_outline,
                'Actifs',
                '${voyagesNonProgrammes.where((v) => v['statut'] != 'cloture').length}',
                const Color(
                  0xFF16A34A,
                ),
              ),
            ],
          ),
        Expanded(
          child: voyagesNonProgrammes.isEmpty
              ? _buildEmpty(
                  'Aucun voyage non programmé',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    40,
                  ),
                  itemCount: voyagesNonProgrammes.length,
                  itemBuilder:
                      (
                        _,
                        i,
                      ) {
                        final v =
                            voyagesNonProgrammes[i]
                                as Map<
                                  String,
                                  dynamic
                                >;
                        final isCloture =
                            v['statut'] ==
                            'cloture';

                        final Color accent, bgColor, borderColor;
                        if (isCloture) {
                          accent = Colors.grey;
                          bgColor = Colors.grey.shade50;
                          borderColor = Colors.grey.shade200;
                        } else {
                          accent = const Color(
                            0xFF0E7C5B,
                          );
                          bgColor = const Color(
                            0xFFE8F5F0,
                          );
                          borderColor = const Color(
                            0xFF6ECBAD,
                          );
                        }

                        final typeLabel =
                            ((v['type']
                                        as String?) ??
                                    '')
                                .isNotEmpty
                            ? v['type']
                                  as String
                            : 'Spontané';

                        return _buildVoyageCard(
                          voyage: v,
                          accent: accent,
                          bgColor: bgColor,
                          borderColor: borderColor,
                          isActive: !isCloture,
                          isCloture: isCloture,
                          isLocked: false,
                          onTap: () => _openVoyage(
                            v,
                          ),
                          extraLabel: isCloture
                              ? null
                              : typeLabel,
                          extraLabelColor: accent,
                        );
                      },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Voyage card
  // ─────────────────────────────────────────────────────────────

  Widget _buildVoyageCard({
    required Map<
      String,
      dynamic
    >
    voyage,
    required Color accent,
    required Color bgColor,
    required Color borderColor,
    required bool isActive,
    required bool isCloture,
    required bool isLocked,
    required VoidCallback onTap,
    String? extraLabel,
    Color? extraLabelColor,
  }) {
    final dh =
        voyage['date_heure']
            as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(
                isCloture
                    ? 0.04
                    : 0.08,
              ),
              blurRadius: 10,
              offset: const Offset(
                0,
                3,
              ),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            16,
          ),
          child: Row(
            children: [
              // ── Bus icon + status dot ──
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(
                        0.12,
                      ),
                      borderRadius: BorderRadius.circular(
                        13,
                      ),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  if (isCloture)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _statusDot(
                        Colors.grey,
                        Icons.history,
                        10,
                      ),
                    )
                  else if (isLocked)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _statusDot(
                        Colors.orange.shade700,
                        Icons.lock,
                        10,
                      ),
                    )
                  else if (isActive)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _statusDot(
                        const Color(
                          0xFF16A34A,
                        ),
                        Icons.play_arrow,
                        11,
                      ),
                    ),
                ],
              ),
              const SizedBox(
                width: 14,
              ),

              // ── Middle text column — EXPANDED so it can shrink ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route row
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                (isActive &&
                                    !isLocked &&
                                    !isCloture)
                                ? goldLight
                                : accent.withOpacity(
                                    0.6,
                                  ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            '${voyage['depart']} → ${voyage['arrivee']}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCloture
                                  ? Colors.grey.shade400
                                  : navyDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),

                    // ── FIX: date/time row — text wrapped in Flexible ──
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Flexible(
                          child: Text(
                            '${_getTime(dh)}  ·  ${_getDate(dh)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (extraLabel !=
                            null &&
                        extraLabel.isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        extraLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              extraLabelColor ??
                              accent,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(
                width: 10,
              ),

              // ── Right badge + chevron ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(
                        0.12,
                      ),
                      borderRadius: BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color: accent.withOpacity(
                          0.25,
                        ),
                      ),
                    ),
                    child: Text(
                      isCloture
                          ? 'Clôturé'
                          : isLocked
                          ? 'En attente'
                          : 'Actif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Icon(
                    isCloture
                        ? Icons.history
                        : isLocked
                        ? Icons.lock_outline
                        : Icons.chevron_right,
                    color: accent.withOpacity(
                      0.5,
                    ),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Micro-widgets
  // ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar(
    List<
      Widget
    >
    tiles,
  ) {
    final separated =
        <
          Widget
        >[];
    for (
      int i = 0;
      i <
          tiles.length;
      i++
    ) {
      separated.add(
        tiles[i],
      );
      if (i <
          tiles.length -
              1) {
        separated.add(
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade100,
          ),
        );
      }
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(
          16,
        ),
        boxShadow: [
          BoxShadow(
            color: navyMid.withOpacity(
              0.07,
            ),
            blurRadius: 16,
            offset: const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
      child: Row(
        children: separated,
      ),
    );
  }

  Widget _statTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(
    Color color,
    IconData icon,
    double iconSize,
  ) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: cardWhite,
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }

  Widget _tabBadge(
    int count,
    bool loading,
  ) {
    if (loading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(
          0.15,
        ),
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildError(
    String message,
    VoidCallback retry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.orange.shade200,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(
                Icons.refresh,
                size: 16,
              ),
              label: const Text(
                'Réessayer',
              ),
              style: TextButton.styleFrom(
                foregroundColor: navyMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 52,
            color: Colors.grey.shade200,
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Toast widget — top-right, slides in from the right
// ─────────────────────────────────────────────────────────────

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
        milliseconds: 2400,
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
                    color: Colors.black.withOpacity(
                      0.25,
                    ),
                    blurRadius: 12,
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
