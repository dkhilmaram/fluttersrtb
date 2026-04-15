import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../history/HistoriquePage.dart';
import '../voyage/cloture_voyage.dart';
import 'ticketing_page.dart';
import '../history/sync_log_page.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../../../data/database/daos/voyage_dao.dart';

// ─────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────

class VenteTicketsPage extends StatefulWidget {
  final Map<String, dynamic> voyage;

  const VenteTicketsPage({super.key, required this.voyage});

  @override
  State<VenteTicketsPage> createState() => _VenteTicketsPageState();
}

class _VenteTicketsPageState extends State<VenteTicketsPage> {
  bool isCloture         = false;
  bool isLoading         = true;
  bool _reopenConfirming = false;
  bool _reopenLoading    = false;
  int  _pendingCount     = 0;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

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

  void _showToast(String msg, {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
            ? Colors.orange.shade700
            : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.offline_bolt
            : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Pending count
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPendingCount() async {
    final pending = await TicketDao.getPendingTickets();
    if (mounted) setState(() => _pendingCount = pending.length);
  }

  // ─────────────────────────────────────────────────────────────
  // Statut resolution
  // ─────────────────────────────────────────────────────────────

  Future<void> _resolveStatut() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final id = widget.voyage['id'] as int?;
    if (id == null) {
      setState(() => isLoading = false);
      return;
    }

    String? serverStatut;
    try {
      final response = await http
          .get(Uri.parse('${ApiConstants.billetterie}/vente/$id/statut'))
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        serverStatut = data['statut'] as String?;
      }
    } catch (_) {}

    // ── Server responded ──────────────────────────────────────
    if (serverStatut != null) {
      if (serverStatut != 'cloture') {
        await VoyageDao.clearVoyageStatut(id);
      }
      if (mounted) {
        setState(() {
          isCloture = serverStatut == 'cloture';
          isLoading = false;
        });
      }
      return;
    }

    // ── Offline fallback ──────────────────────────────────────
    final lastKnown   = widget.voyage['statut'] as String? ?? 'actif';
    final localStatut = await VoyageDao.getVoyageStatut(
      id,
      currentServerStatut: lastKnown,
    );

    if (mounted) {
      setState(() {
        isCloture = localStatut == 'cloture' ||
            localStatut == 'cloture_pending' ||
            lastKnown == 'cloture';
        isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Reopen voyage
  // ─────────────────────────────────────────────────────────────

  Future<void> _reopenVoyage() async {
    final id = widget.voyage['id'] as int?;
    if (id == null) return;

    setState(() => _reopenLoading = true);

    bool success = false;
    bool offline = false;

    try {
      final response = await http
          .put(Uri.parse('${ApiConstants.billetterie}/vente/$id/reopen'))
          .timeout(ApiConstants.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        success = data['success'] == true;
      }
    } catch (_) {
      offline = true;
      await VoyageDao.clearVoyageStatut(id);
      success = true;
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        isCloture         = false;
        _reopenConfirming = false;
        _reopenLoading    = false;
      });
      _showToast(
        offline ? 'Réouverture enregistrée (hors-ligne)' : 'Voyage réouvert avec succès',
        isWarning: offline,
      );
    } else {
      setState(() {
        _reopenConfirming = false;
        _reopenLoading    = false;
      });
      _showToast('Échec de la réouverture', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String get _todayFormatted {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String get _heure {
    final dh    = widget.voyage['date_heure'] as String? ?? '';
    final parts = dh.split(' ');
    return parts.length > 1 ? parts[1].substring(0, 5) : '';
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final voyageId = widget.voyage['id'] as int?;
    final hasId    = voyageId != null;
    final depart   = widget.voyage['depart']  ?? '?';
    final arrivee  = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(depart, arrivee),

            if (isCloture)
              Container(
                width: double.infinity,
                color: const Color.fromARGB(255, 109, 108, 108),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Voyage clôturé',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            _buildInfoCard(depart, arrivee),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: CircularProgressIndicator(
                            color: AppTheme.navyMid),
                      ),
                    )
                  : isCloture
                      ? _buildClotureButtons(hasId)
                      : _buildActiveButtons(hasId),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Clôturé state
  // ─────────────────────────────────────────────────────────────

  Widget _buildClotureButtons(bool hasId) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade400, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce voyage est clôturé. Réouvrez-le pour accéder à la billetterie.',
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

        if (hasId) ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _reopenConfirming
                ? _buildReopenConfirmCard()
                : _actionBtn(
                    key: const ValueKey('reopen_btn'),
                    label: 'Réouvrir le voyage',
                    icon: Icons.lock_open_rounded,
                    colors: const [
                      Color.fromARGB(255, 3, 74, 54),
                      Color.fromARGB(255, 3, 74, 54),
                    ],
                    onTap: () => setState(() => _reopenConfirming = true),
                  ),
          ),
          const SizedBox(height: 12),
        ],

        _actionBtn(
          label: 'Historique',
          icon: Icons.history,
          colors: [AppTheme.navyDark, AppTheme.navyLight],
          onTap: hasId
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoriquePage(voyage: widget.voyage),
                    ),
                  )
              : null,
        ),
        const SizedBox(height: 12),
        _syncLogBtn(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Inline reopen confirmation card
  // ─────────────────────────────────────────────────────────────

  Widget _buildReopenConfirmCard() {
    return Container(
      key: const ValueKey('reopen_confirm'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromARGB(255, 39, 57, 56),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color.fromARGB(255, 2, 69, 50), size: 18),
              SizedBox(width: 8),
              Text(
                'Confirmer la réouverture ?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color.fromARGB(255, 3, 69, 64),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Le voyage sera remis en statut actif et la billetterie sera accessible.',
            style: TextStyle(
              color: Color.fromARGB(255, 3, 69, 64),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _reopenLoading
                        ? null
                        : () => setState(() => _reopenConfirming = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 2, 61, 30),
                      side: const BorderSide(
                          color: Color.fromARGB(255, 3, 62, 26)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _reopenLoading ? null : _reopenVoyage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 60, 51),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color.fromARGB(255, 3, 60, 51),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _reopenLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Réouvrir',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Active state buttons
  // ─────────────────────────────────────────────────────────────

  Widget _buildActiveButtons(bool hasId) {
    return Column(
      children: [
        if (hasId) ...[
          _actionBtn(
            label: 'Billetterie',
            icon: Icons.confirmation_number_rounded,
            colors: const [Color(0xFF0D6E5E), Color(0xFF0D9E87)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketingPage(
                  voyage: widget.voyage,
                  segment: {
                    'point_depart':  widget.voyage['depart']     ?? '',
                    'point_arrivee': widget.voyage['arrivee']    ?? '',
                    'id_segment':    widget.voyage['id_segment'] ?? 0,
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        _actionBtn(
          label: 'Historique',
          icon: Icons.history,
          colors: [AppTheme.navyDark, AppTheme.navyLight],
          onTap: hasId
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoriquePage(voyage: widget.voyage),
                    ),
                  )
              : null,
        ),
        const SizedBox(height: 12),

        _syncLogBtn(),

        if (hasId) ...[
          const SizedBox(height: 12),
          _actionBtn(
            label: 'Clôture Voyage',
            icon: Icons.flag_rounded,
            colors: const [Color(0xFF9B1C1C), Color(0xFFDC2626)],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClotureVoyagePage(voyage: widget.voyage),
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
  // Sync-log button
  // ─────────────────────────────────────────────────────────────

  Widget _syncLogBtn() {
    return _actionBtn(
      label: _pendingCount > 0
          ? 'Journaux de sync · $_pendingCount en attente'
          : 'Journaux de synchronisation',
      icon: Icons.sync_rounded,
      colors: _pendingCount > 0
          ? [Colors.orange.shade700, Colors.orange.shade500]
          : const [Color(0xFF1A3260), Color(0xFF1E4080)],
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SyncLogPage(agent: widget.voyage),
        ),
      ).then((_) => _loadPendingCount()),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(String depart, String arrivee) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCloture
              ? const [Color(0xFF2D2D2D), Color(0xFF4A4A4A)]
              : [AppTheme.navyDark, AppTheme.navyMid, AppTheme.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 17),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SyncLogPage(agent: widget.voyage),
                  ),
                ).then((_) => _loadPendingCount()),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sync_rounded,
                          color: Colors.white, size: 20),
                    ),
                    if (_pendingCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 3, 90, 55),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
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
          const SizedBox(height: 18),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_bus,
                  size: 44,
                  color: AppTheme.navyMid),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'S R T B',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCloture ? 'Voyage clôturé' : 'Vente & Historique',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppTheme.goldLight, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(depart,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward,
                      color: Colors.white.withOpacity(0.4), size: 13),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldLight, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(arrivee,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Voyage info card  — shows today's date
  // ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(String depart, String arrivee) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCloture
                ? Colors.grey.shade200
                : AppTheme.navyLight.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCloture ? Colors.grey : AppTheme.navyMid)
                  .withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (isCloture ? Colors.grey : AppTheme.navyMid)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.directions_bus,
                color: isCloture ? Colors.grey : AppTheme.navyMid,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
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
                          : AppTheme.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.today_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _heure.isNotEmpty
                            ? '$_heure  ·  $_todayFormatted'
                            : _todayFormatted,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCloture
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCloture
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                isCloture ? 'Clôturé' : 'Actif',
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
    Key? key,
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: enabled ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: colors.first.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: enabled ? Colors.white : Colors.grey.shade400,
                    size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: enabled ? Colors.white : Colors.grey.shade400,
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
// Toast widget
// ─────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String   msg;
  final Color    color;
  final IconData icon;

  const _ToastWidget({
    required this.msg,
    required this.color,
    required this.icon,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
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