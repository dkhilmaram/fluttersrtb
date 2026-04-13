import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
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

// ════════════════════════════════════════════════════
// TOAST WIDGET — slides in from top right
// ════════════════════════════════════════════════════

class _ToastWidget
    extends
        StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
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
  late AnimationController _ctrl;
  late Animation<
    double
  >
  _opacity;
  late Animation<
    Offset
  >
  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 380,
      ),
    );
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );
    // slides in from the right
    _slide =
        Tween<
              Offset
            >(
              begin: const Offset(
                1.2,
                0,
              ),
              end: Offset.zero,
            )
            .animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: Curves.easeOutBack,
              ),
            );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then(
      (
        _,
      ) => widget.onDismiss(),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return FadeTransition(
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
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(
                14,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    0.2,
                  ),
                  blurRadius: 20,
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
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.15,
                    ),
                    borderRadius: BorderRadius.circular(
                      8,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Flexible(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(
                      0.5,
                    ),
                    size: 16,
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

// ════════════════════════════════════════════════════
// CLOTURE VOYAGE PAGE
// ════════════════════════════════════════════════════

class ClotureVoyagePage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  const ClotureVoyagePage({
    super.key,
    required this.voyage,
  });

  @override
  State<
    ClotureVoyagePage
  >
  createState() => _ClotureVoyagePageState();
}

class _ClotureVoyagePageState
    extends
        State<
          ClotureVoyagePage
        > {
  bool isCloturing = false;
  bool isCloture = false;

  OverlayEntry? _toastEntry;

  String get _date {
    final dh =
        widget.voyage['date_heure']
            as String? ??
        '';
    return dh.split(
      ' ',
    )[0];
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

  @override
  void dispose() {
    _toastEntry?.remove();
    _toastEntry = null;
    super.dispose();
  }

  // ════════════════════════════════════════════════════
  // TOAST — top right, slides in from right
  // ════════════════════════════════════════════════════

  void _showToast(
    String msg, {
    bool isError = false,
  }) {
    if (!mounted) return;

    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? const Color(
            0xFFB91C1C,
          )
        : const Color(
            0xFF15803D,
          );
    final icon = isError
        ? Icons.error_outline
        : Icons.check_circle_outline;

    _toastEntry = OverlayEntry(
      builder:
          (
            ctx,
          ) {
            final topPadding = MediaQuery.of(
              ctx,
            ).padding.top;
            return Positioned(
              top:
                  topPadding +
                  14,
              right: 16,
              child: _ToastWidget(
                message: msg,
                color: color,
                icon: icon,
                onDismiss: () {
                  _toastEntry?.remove();
                  _toastEntry = null;
                },
              ),
            );
          },
    );

    Overlay.of(
      context,
    ).insert(
      _toastEntry!,
    );

    Future.delayed(
      const Duration(
        seconds: 4,
      ),
      () {
        _toastEntry?.remove();
        _toastEntry = null;
      },
    );
  }

  // ════════════════════════════════════════════════════
  // LOGIC
  // ════════════════════════════════════════════════════

  Future<
    void
  >
  _cloturerVoyage() async {
    setState(
      () => isCloturing = true,
    );
    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline = results.any(
        (
          r,
        ) =>
            r !=
            ConnectivityResult.none,
      );
      if (isOnline) {
        await _cloturerOnline();
      } else {
        await _cloturerOffline();
      }
    } catch (
      e
    ) {
      setState(
        () => isCloturing = false,
      );
      if (mounted)
        _showToast(
          'Erreur inattendue',
          isError: true,
        );
    }
  }

  Future<
    void
  >
  _cloturerOnline() async {
    final id =
        widget.voyage['id']
            as int;
    try {
      final response = await http
          .put(
            Uri.parse(
              'http://10.19.204.100:8000/billetterie/vente/$id/cloturer',
            ),
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(
              seconds: 10,
            ),
          );

      if (response.statusCode ==
          200) {
        final data = jsonDecode(
          response.body,
        );
        if (data['success'] ==
            true) {
          await LocalDatabase.saveVoyageStatut(
            id,
            'cloture',
            serverStatut: 'cloture',
          );
          await _markAllSegmentsClotureLocally(
            id,
          );
          _onClotureDone();
        } else {
          setState(
            () => isCloturing = false,
          );
          if (mounted)
            _showToast(
              data['message'] ??
                  'Erreur',
              isError: true,
            );
        }
      } else {
        await _cloturerOffline();
      }
    } catch (
      e
    ) {
      await _cloturerOffline();
    }
  }

  Future<
    void
  >
  _cloturerOffline() async {
    final id =
        widget.voyage['id']
            as int;
    final lastKnownServerStatut =
        widget.voyage['statut']
            as String? ??
        'actif';

    await LocalDatabase.saveVoyageStatut(
      id,
      'cloture_pending',
      serverStatut: lastKnownServerStatut,
    );
    await _markAllSegmentsClotureLocally(
      id,
    );
    await _queuePendingSegmentClotures(
      id,
    );
    await LocalDatabase.saveCloturePending(
      id,
    );

    if (mounted) {
      _showToast(
        'Hors ligne — clôture enregistrée, sera envoyée à la reconnexion',
      );
    }
    _onClotureDone();
  }

  Future<
    void
  >
  _markAllSegmentsClotureLocally(
    int idVente,
  ) async {
    final cached = await LocalDatabase.getSegments(
      idVente,
    );
    if (cached ==
        null)
      return;

    final now = DateTime.now().toString().substring(
      0,
      19,
    );
    final segments =
        (cached['segments']
                    as List<
                      dynamic
                    >? ??
                [])
            .map(
              (
                s,
              ) {
                final seg =
                    Map<
                      String,
                      dynamic
                    >.from(
                      s
                          as Map,
                    );
                if (seg['statut'] !=
                    'cloture') {
                  seg['statut'] = 'cloture';
                  seg['date_cloture'] ??= now;
                }
                return seg;
              },
            )
            .toList();

    await LocalDatabase.saveSegments(
      idVente: idVente,
      actifSegment: null,
      prochainSegment: null,
      tousSecteurs: segments,
      tousClotures: true,
    );
  }

  Future<
    void
  >
  _queuePendingSegmentClotures(
    int idVente,
  ) async {
    final cached = await LocalDatabase.getSegments(
      idVente,
    );
    if (cached ==
        null)
      return;

    final segments =
        cached['segments']
            as List<
              dynamic
            >? ??
        [];
    for (final s in segments) {
      final seg =
          s
              as Map<
                String,
                dynamic
              >;
      final statut =
          seg['statut']
              as String? ??
          '';
      if (statut ==
          'cloture')
        continue;
      final idSeg =
          seg['id_segment']
              as int;
      await LocalDatabase.saveSegmentCloturePending(
        idVente: idVente,
        idSegment: idSeg,
        openNext: false,
      );
    }
  }

  void _onClotureDone() {
    setState(
      () {
        isCloture = true;
        isCloturing = false;
      },
    );
    Future.delayed(
      const Duration(
        seconds: 2,
      ),
      () {
        if (mounted) {
          Navigator.pop(
            context,
          );
          Navigator.pop(
            context,
          );
        }
      },
    );
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(
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
              child: isCloture
                  ? _buildSuccess()
                  : _buildForm(
                      depart,
                      arrivee,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════

  Widget _buildHeader(
    String depart,
    String arrivee,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(
              0xFF7F1D1D,
            ),
            Color(
              0xFFB91C1C,
            ),
            Color(
              0xFFDC2626,
            ),
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
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: isCloturing
                  ? null
                  : () => Navigator.pop(
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
                  ) => Icon(
                    Icons.directions_bus,
                    size: 44,
                    color: Colors.red.shade700,
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
            'Fin du Voyage',
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

  // ════════════════════════════════════════════════════
  // SUCCESS STATE
  // ════════════════════════════════════════════════════

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(
          height: 40,
        ),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: navyMid.withOpacity(
              0.1,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: navyMid.withOpacity(
                0.3,
              ),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: navyMid,
            size: 52,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        const Text(
          'Voyage clôturé !',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: navyDark,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          'Tous les secteurs ont été clôturés.',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          'Retour en cours...',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // FORM STATE
  // ════════════════════════════════════════════════════

  Widget _buildForm(
    String depart,
    String arrivee,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Voyage info card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            16,
          ),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: navyLight.withOpacity(
                0.15,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: navyMid.withOpacity(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voyage en cours',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: navyMid.withOpacity(
                        0.1,
                      ),
                      borderRadius: BorderRadius.circular(
                        11,
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: navyMid,
                      size: 22,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: navyDark,
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
                ],
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        // ── Warning card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            16,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: Colors.red.shade100,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(
                    'Attention',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              _warningItem(
                'Cette action est irréversible',
              ),
              _warningItem(
                'Tous les secteurs seront automatiquement clôturés',
              ),
              _warningItem(
                'Aucune vente ne sera possible après clôture',
              ),
              _warningItem(
                'Le voyage sera marqué comme terminé',
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 28,
        ),

        // ── Confirm button ──
        _actionBtn(
          label: isCloturing
              ? 'Clôture en cours...'
              : 'Confirmer la clôture',
          icon: isCloturing
              ? null
              : Icons.flag_rounded,
          isLoading: isCloturing,
          enabled: !isCloturing,
          colors: const [
            Color(
              0xFF7F1D1D,
            ),
            Color(
              0xFFDC2626,
            ),
          ],
          onTap: _cloturerVoyage,
        ),

        const SizedBox(
          height: 12,
        ),

        // ── Cancel button ──
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: isCloturing
                ? null
                : () => Navigator.pop(
                    context,
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: navyMid,
              side: BorderSide(
                color: navyMid.withOpacity(
                  0.3,
                ),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  14,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: isCloturing
                      ? Colors.grey.shade300
                      : navyMid,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  'Annuler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCloturing
                        ? Colors.grey.shade300
                        : navyMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════

  Widget _warningItem(
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              color: Colors.red.shade700,
              size: 12,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData? icon,
    required bool isLoading,
    required bool enabled,
    required List<
      Color
    >
    colors,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: enabled
              ? onTap
              : null,
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
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else if (icon !=
                    null)
                  Icon(
                    icon,
                    color: enabled
                        ? Colors.white
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                const SizedBox(
                  width: 8,
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
