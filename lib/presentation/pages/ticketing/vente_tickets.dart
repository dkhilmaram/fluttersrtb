import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../history/HistoriquePage.dart';
import '../voyage/cloture_voyage.dart';
import 'ticketing_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/daos/ticket_dao.dart';
import '../../widgets/language_switcher.dart';

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
  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  int? get _voyageId {
    final raw = widget.voyage['id_voyage'] ?? widget.voyage['id'];
    if (raw == null) return null;
    return raw is int ? raw : int.tryParse(raw.toString());
  }

  bool get _isPending => widget.voyage['_is_pending'] == true;

  bool get _hasId => _voyageId != null;

  String get _todayFormatted {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String get _heure {
    final dh    = widget.voyage['date_heure'] as String? ?? '';
    final parts = dh.split(' ');
    if (parts.length > 1) {
      final timePart = parts[1];
      return timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
    }
    if (dh.contains('T')) {
      final timePart = dh.split('T').last;
      return timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
    }
    return '';
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
  // Navigation helpers
  // ─────────────────────────────────────────────────────────────

  void _openBilletterie() {
    final t  = AppLocalizations.of(context)!;
    final id = _voyageId;
    if (id == null) {
      _showToast(t.voyageSansIdentifiant, isError: true);
      return;
    }

    Navigator.push(
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
    );
  }

  void _openHistorique() {
    final t = AppLocalizations.of(context)!;
    if (!_hasId) {
      _showToast(t.aucunHistoriqueDisponible, isWarning: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriquePage(voyage: widget.voyage),
      ),
    );
  }

  Future<void> _openCloture() async {
    final t  = AppLocalizations.of(context)!;
    final id = _voyageId;
    if (id == null || id < 0) {
      _showToast(t.horsLigneCloturePendingSync, isWarning: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClotureVoyagePage(voyage: widget.voyage),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final depart  = widget.voyage['depart']  ?? '?';
    final arrivee = widget.voyage['arrivee'] ?? '?';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(depart, arrivee),
            _buildInfoCard(depart, arrivee),
            if (_isPending) _buildPendingBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Pending banner
  // ─────────────────────────────────────────────────────────────

  Widget _buildPendingBanner() {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined,
                color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.voyageHorsLigneSyncMessage,
                style: TextStyle(
                  fontSize: 12,
                  color:    Colors.amber.shade800,
                  height:   1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Action buttons
  // ─────────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final t = AppLocalizations.of(context)!;

    final canCloture = _hasId && !_isPending && (_voyageId ?? 0) > 0;

    return Column(
      children: [
        if (_hasId) ...[
          _actionBtn(
            label:  t.billetterie,
            icon:   Icons.confirmation_number_rounded,
            colors: const [Color(0xFF0D6E5E), Color(0xFF0D9E87)],
            onTap:  _openBilletterie,
            badge:  _isPending ? t.horsLigneLabel : null,
          ),
          const SizedBox(height: 12),
        ],

        _actionBtn(
          label:  t.historique,
          icon:   Icons.history,
          colors: [AppTheme.navyDark, AppTheme.navyLight],
          onTap:  _hasId ? _openHistorique : null,
        ),

        if (canCloture) ...[
          const SizedBox(height: 12),
          _actionBtn(
            label:  t.clotureVoyage,
            icon:   Icons.flag_rounded,
            colors: const [Color(0xFF9B1C1C), Color(0xFFDC2626)],
            onTap:  _openCloture,
          ),
        ],

        if (_isPending) ...[
          const SizedBox(height: 12),
          _actionBtn(
            label:  t.clotureVoyage,
            icon:   Icons.flag_rounded,
            colors: const [Color(0xFF9B1C1C), Color(0xFFDC2626)],
            onTap:  null,
            badge:  t.syncDisponibleApres,
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(String depart, String arrivee) {
    final t = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navyDark, AppTheme.navyMid, AppTheme.navyLight],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 36),
      child: Column(
        children: [
          // ── Top row ──
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size:  17,
                  ),
                ),
              ),
              const Spacer(),
              if (_isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, color: Colors.amber, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        t.voyageEnAttenteSync,
                        style: const TextStyle(
                          color:      Colors.amber,
                          fontSize:   11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              const LanguageSwitcher(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Logo ──
          Container(
            width:  72,
            height: 72,
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/logo_srtb.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.directions_bus,
                size:  44,
                color: AppTheme.navyMid,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            t.srtbLetters,
            style: const TextStyle(
              color:         Colors.white,
              fontSize:      20,
              fontWeight:    FontWeight.bold,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.venteEtHistorique,
            style: TextStyle(
              color:         Colors.white.withOpacity(0.7),
              fontSize:      12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // ── Route pill ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border:       Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.goldLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  depart,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white.withOpacity(0.4),
                    size:  13,
                  ),
                ),
                Container(
                  width:  7,
                  height: 7,
                  decoration: BoxDecoration(
                    color:  Colors.transparent,
                    shape:  BoxShape.circle,
                    border: Border.all(color: AppTheme.goldLight, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  arrivee,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
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
  // Info card
  // ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(String depart, String arrivee) {
    final t = AppLocalizations.of(context)!;

    final Color statusBg, statusBorder, statusFg;
    final String statusLabel;
    if (_isPending) {
      statusBg     = Colors.amber.shade50;
      statusBorder = Colors.amber.shade300;
      statusFg     = Colors.amber.shade800;
      statusLabel  = '⏳ Sync';
    } else {
      statusBg     = Colors.green.shade50;
      statusBorder = Colors.green.shade200;
      statusFg     = Colors.green.shade700;
      statusLabel  = t.actif;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.navyLight.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:      AppTheme.navyMid.withOpacity(0.06),
              blurRadius: 12,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  46,
              height: 46,
              decoration: BoxDecoration(
                color:        AppTheme.navyMid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: AppTheme.navyMid,
                size:  24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$depart → $arrivee',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                      color:      AppTheme.navyDark,
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
                          color:    Colors.grey.shade400,
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
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        statusBg,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: statusBorder),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   11,
                  color:      statusFg,
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
    Key?                 key,
    required String      label,
    required IconData    icon,
    required List<Color> colors,
    required VoidCallback? onTap,
    String?              badge,
  }) {
    final enabled = onTap != null;

    return SizedBox(
      key:    key,
      width:  double.infinity,
      height: 54,
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: colors,
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    )
                  : null,
              color:        enabled ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color:      colors.first.withOpacity(0.35),
                        blurRadius: 12,
                        offset:     const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: enabled ? Colors.white : Colors.grey.shade400,
                      size:  20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize:      14,
                        fontWeight:    FontWeight.bold,
                        letterSpacing: 0.3,
                        color: enabled ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(
                            enabled ? 0.2 : 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.bold,
                          color: enabled
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
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
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end:   Offset.zero,
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
      top:   MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color:        widget.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:      widget.color.withOpacity(0.35),
                    blurRadius: 16,
                    offset:     const Offset(0, 4),
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
                        color:      Colors.white,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        height:     1.3,
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