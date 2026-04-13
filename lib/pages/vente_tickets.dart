import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'HistoriquePage.dart';
import 'cloture_voyage.dart';
import 'segment_page.dart';
import '../sync_log_page.dart';
import '../local_database.dart';

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

class VenteTicketsPage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  const VenteTicketsPage({
    super.key,
    required this.voyage,
  });

  @override
  State<
    VenteTicketsPage
  >
  createState() => _VenteTicketsPageState();
}

class _VenteTicketsPageState
    extends
        State<
          VenteTicketsPage
        > {
  bool isCloture = false;
  bool isLoading = true;
  int _pendingCount = 0;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
    _resolveStatut();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Toast
  // ─────────────────────────────────────────────────────────────

  void _showToast(
    String msg, {
    bool isError = false,
    bool isWarning = false,
  }) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
        ? Colors.orange.shade700
        : const Color(
            0xFF16A34A,
          );

    final icon = isError
        ? Icons.error_outline
        : isWarning
        ? Icons.offline_bolt
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
        milliseconds: 2500,
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
  // Pending count
  // ─────────────────────────────────────────────────────────────

  Future<
    void
  >
  _loadPendingCount() async {
    final pending = await LocalDatabase.getPendingTickets();
    if (mounted)
      setState(
        () => _pendingCount = pending.length,
      );
  }

  // ─────────────────────────────────────────────────────────────
  // Statut resolution — server always wins over local cache.
  //
  // Priority:
  //   1. Ask the server (online) — most accurate, detects manual resets.
  //   2. Fall back to local cache if offline — BUT pass the last known
  //      server statut so stale 'cloture' entries are discarded when
  //      the server has been manually reset to 'actif'.
  // ─────────────────────────────────────────────────────────────

  Future<
    void
  >
  _resolveStatut() async {
    if (!mounted) return;
    setState(
      () => isLoading = true,
    );

    final id =
        widget.voyage['id']
            as int?;

    if (id ==
        null) {
      setState(
        () => isLoading = false,
      );
      return;
    }

    // ── Step 1: always try the server first ──
    String? serverStatut;
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://10.19.204.100:8000/billetterie/vente/$id/statut',
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
        serverStatut =
            data['statut']
                as String?;
      }
    } catch (
      _
    ) {
      // Network unavailable — will fall through to offline path below.
    }

    if (serverStatut !=
        null) {
      // ── Online path: server responded ──
      if (serverStatut !=
          'cloture') {
        await LocalDatabase.clearVoyageStatut(
          id,
        );
      }
      if (mounted) {
        setState(
          () {
            isCloture =
                serverStatut ==
                'cloture';
            isLoading = false;
          },
        );
      }
      return;
    }

    // ── Offline path: server unreachable ──
    final lastKnownServerStatut =
        widget.voyage['statut']
            as String? ??
        'actif';

    final localStatut = await LocalDatabase.getVoyageStatut(
      id,
      currentServerStatut: lastKnownServerStatut,
    );

    if (mounted) {
      setState(
        () {
          isCloture =
              localStatut ==
                  'cloture' ||
              localStatut ==
                  'cloture_pending' ||
              lastKnownServerStatut ==
                  'cloture';
          isLoading = false;
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String get _date {
    final dh =
        widget.voyage['date_heure']
            as String? ??
        '';
    return dh
        .split(
          ' ',
        )
        .first;
  }

  String get _heure {
    final dh =
        widget.voyage['date_heure']
            as String? ??
        '';
    final parts = dh.split(
      ' ',
    );
    return parts.length >
            1
        ? parts[1].substring(
            0,
            5,
          )
        : '';
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context,
  ) {
    final voyageId =
        widget.voyage['id']
            as int?;
    final hasId =
        voyageId !=
        null;
    final depart =
        widget.voyage['depart'] ??
        '?';
    final arrivee =
        widget.voyage['arrivee'] ??
        '?';

    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(
              depart,
              arrivee,
            ),

            if (isCloture)
              Container(
                width: double.infinity,
                color: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      'Voyage clôturé — Aucune vente possible',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            _buildInfoCard(
              depart,
              arrivee,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                40,
              ),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 40,
                        ),
                        child: CircularProgressIndicator(
                          color: navyMid,
                        ),
                      ),
                    )
                  : isCloture
                  ? _buildClotureButtons(
                      hasId,
                    )
                  : _buildActiveButtons(
                      hasId,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Button sets
  // ─────────────────────────────────────────────────────────────

  Widget _buildClotureButtons(
    bool hasId,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            bottom: 20,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.grey.shade400,
                size: 18,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  'Ce voyage est clôturé. Vous pouvez consulter '
                  'l\'historique et les journaux en lecture seule.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _actionBtn(
          label: 'Historique',
          icon: Icons.history,
          colors: [
            navyDark,
            navyLight,
          ],
          onTap: hasId
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (
                          _,
                        ) => HistoriquePage(
                          voyage: widget.voyage,
                        ),
                  ),
                )
              : null,
        ),
        const SizedBox(
          height: 12,
        ),
        _actionBtn(
          label:
              _pendingCount >
                  0
              ? 'Journaux de sync · $_pendingCount en attente'
              : 'Journaux de synchronisation',
          icon: Icons.sync_rounded,
          colors:
              _pendingCount >
                  0
              ? [
                  Colors.orange.shade700,
                  Colors.orange.shade500,
                ]
              : [
                  const Color(
                    0xFF1A3260,
                  ),
                  const Color(
                    0xFF1E4080,
                  ),
                ],
          onTap: () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (
                        _,
                      ) => const SyncLogPage(),
                ),
              ).then(
                (
                  _,
                ) => _loadPendingCount(),
              ),
        ),
      ],
    );
  }

  Widget _buildActiveButtons(
    bool hasId,
  ) {
    return Column(
      children: [
        if (hasId) ...[
          _actionBtn(
            label: 'Secteurs du voyage',
            icon: Icons.route,
            colors: [
              const Color(
                0xFF0D6E5E,
              ),
              const Color(
                0xFF0D9E87,
              ),
            ],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (
                      _,
                    ) => SegmentPage(
                      voyage: widget.voyage,
                    ),
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
        ],
        _actionBtn(
          label: 'Historique',
          icon: Icons.history,
          colors: [
            navyDark,
            navyLight,
          ],
          onTap: hasId
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (
                          _,
                        ) => HistoriquePage(
                          voyage: widget.voyage,
                        ),
                  ),
                )
              : null,
        ),
        const SizedBox(
          height: 12,
        ),
        _actionBtn(
          label:
              _pendingCount >
                  0
              ? 'Journaux de sync · $_pendingCount en attente'
              : 'Journaux de synchronisation',
          icon: Icons.sync_rounded,
          colors:
              _pendingCount >
                  0
              ? [
                  Colors.orange.shade700,
                  Colors.orange.shade500,
                ]
              : [
                  const Color(
                    0xFF1A3260,
                  ),
                  const Color(
                    0xFF1E4080,
                  ),
                ],
          onTap: () =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (
                        _,
                      ) => const SyncLogPage(),
                ),
              ).then(
                (
                  _,
                ) => _loadPendingCount(),
              ),
        ),
        if (hasId) ...[
          const SizedBox(
            height: 12,
          ),
          _actionBtn(
            label: 'Clôture Voyage',
            icon: Icons.flag_rounded,
            colors: [
              const Color(
                0xFF9B1C1C,
              ),
              const Color(
                0xFFDC2626,
              ),
            ],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (
                        _,
                      ) => ClotureVoyagePage(
                        voyage: widget.voyage,
                      ),
                ),
              );
              await _resolveStatut();
            },
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(
    String depart,
    String arrivee,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCloture
              ? [
                  const Color(
                    0xFF2D2D2D,
                  ),
                  const Color(
                    0xFF4A4A4A,
                  ),
                ]
              : [
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
        28,
      ),
      child: Column(
        children: [
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
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (
                              _,
                            ) => const SyncLogPage(),
                      ),
                    ).then(
                      (
                        _,
                      ) => _loadPendingCount(),
                    ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
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
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    if (_pendingCount >
                        0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          Container(
            width: 72,
            height: 72,
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
            padding: const EdgeInsets.all(
              8,
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
            isCloture
                ? 'Historique & Journaux'
                : 'Vente & Historique',
            style: TextStyle(
              color: Colors.white.withOpacity(
                0.7,
              ),
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(
            height: 14,
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
                  depart,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white.withOpacity(
                      0.4,
                    ),
                    size: 13,
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: goldLight,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  arrivee,
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
  // Voyage info card
  // ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(
    String depart,
    String arrivee,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: isCloture
                ? Colors.grey.shade200
                : navyLight.withOpacity(
                    0.2,
                  ),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isCloture
                          ? Colors.grey
                          : navyMid)
                      .withOpacity(
                        0.06,
                      ),
              blurRadius: 12,
              offset: const Offset(
                0,
                3,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    (isCloture
                            ? Colors.grey
                            : navyMid)
                        .withOpacity(
                          0.1,
                        ),
                borderRadius: BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                Icons.directions_bus,
                color: isCloture
                    ? Colors.grey
                    : navyMid,
                size: 24,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$depart → $arrivee',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isCloture
                          ? Colors.grey.shade400
                          : navyDark,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        '$_heure  ·  $_date',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isCloture
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color: isCloture
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                isCloture
                    ? 'Clôturé'
                    : 'Actif',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isCloture
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Action button
  // ─────────────────────────────────────────────────────────────

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required List<
      Color
    >
    colors,
    required VoidCallback? onTap,
  }) {
    final enabled =
        onTap !=
        null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            14,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled
                  ? null
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(
                14,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: colors.first.withOpacity(
                          0.35,
                        ),
                        blurRadius: 12,
                        offset: const Offset(
                          0,
                          4,
                        ),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? Colors.white
                      : Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: enabled
                        ? Colors.white
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        milliseconds: 2100,
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
