import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../local_database.dart';
import '../route_observer.dart';
import 'ticketing_page.dart';

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
// TOAST WIDGET
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
        milliseconds: 350,
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
                0.3,
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
                    0.18,
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
                Expanded(
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
                  width: 8,
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
// SEGMENT PAGE
// ════════════════════════════════════════════════════

class SegmentPage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  const SegmentPage({
    super.key,
    required this.voyage,
  });

  @override
  State<
    SegmentPage
  >
  createState() => _SegmentPageState();
}

class _SegmentPageState
    extends
        State<
          SegmentPage
        >
    with
        SingleTickerProviderStateMixin,
        RouteAware {
  Map<
    String,
    dynamic
  >?
  secteurActif;
  Map<
    String,
    dynamic
  >?
  prochainSecteur;
  List<
    dynamic
  >
  tousSecteurs = [];
  bool tousClotures = false;
  bool isLoading = true;
  bool isActioning = false;
  bool isOffline = false;
  String? errorMessage;

  OverlayEntry? _toastEntry;

  late AnimationController _animCtrl;
  late Animation<
    double
  >
  _fadeAnim;
  late Animation<
    Offset
  >
  _slideAnim;

  int get _voyageId =>
      (widget.voyage['id_vente'] ??
              widget.voyage['id'])
          as int;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 500,
      ),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim =
        Tween<
              Offset
            >(
              begin: const Offset(
                0,
                0.05,
              ),
              end: Offset.zero,
            )
            .animate(
              CurvedAnimation(
                parent: _animCtrl,
                curve: Curves.easeOut,
              ),
            );
    _fetchAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(
      this,
      ModalRoute.of(
        context,
      )!,
    );
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    _toastEntry = null;
    routeObserver.unsubscribe(
      this,
    );
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _fetchAll();
  }

  // ════════════════════════════════════════════════════
  // TOAST
  // ════════════════════════════════════════════════════

  void _showToast(
    String msg, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;

    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? const Color(
            0xFFB45309,
          )
        : isWarning
        ? const Color(
            0xFFB45309,
          )
        : const Color(
            0xFFB45309,
          );

    final icon = isError
        ? Icons.error_outline
        : isWarning
        ? Icons.info_outline
        : Icons.check_circle_outline;

    _toastEntry = OverlayEntry(
      builder:
          (
            context,
          ) => Positioned(
            top:
                MediaQuery.of(
                  context,
                ).padding.top +
                12,
            right: 14,
            width: 260,
            child: _ToastWidget(
              message: msg,
              color: color,
              icon: icon,
              onDismiss: () {
                _toastEntry?.remove();
                _toastEntry = null;
              },
            ),
          ),
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
  // DATA
  // ════════════════════════════════════════════════════

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

    try {
      final id = _voyageId;

      final r1 = await http
          .get(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/voyages/$id/segment/actif',
            ),
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );
      final r2 = await http
          .get(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/voyages/$id/segments',
            ),
          )
          .timeout(
            const Duration(
              seconds: 6,
            ),
          );

      dynamic d1, d2;
      try {
        d1 = jsonDecode(
          r1.body,
        );
      } catch (
        _
      ) {}
      try {
        d2 = jsonDecode(
          r2.body,
        );
      } catch (
        _
      ) {}

      if (r1.statusCode ==
              200 &&
          r2.statusCode ==
              200 &&
          d1?['success'] ==
              true) {
        final actif =
            d1['segment']
                as Map<
                  String,
                  dynamic
                >?;
        final prochain =
            d1['prochain']
                as Map<
                  String,
                  dynamic
                >?;
        final segments =
            d2?['segments']
                as List<
                  dynamic
                >? ??
            [];
        final clotures =
            d1['tous_clotures'] ==
            true;

        await LocalDatabase.saveSegments(
          idVente: id,
          actifSegment: actif,
          prochainSegment: prochain,
          tousSecteurs: segments,
          tousClotures: clotures,
        );

        setState(
          () {
            secteurActif = actif;
            prochainSecteur = prochain;
            tousSecteurs = segments;
            tousClotures = clotures;
            isOffline = false;
            isLoading = false;
          },
        );
        _animCtrl.forward(
          from: 0,
        );
        return;
      }

      throw Exception(
        (d1?['message']
                as String?) ??
            'Erreur serveur (${r1.statusCode})',
      );
    } catch (
      _
    ) {
      try {
        final cached = await LocalDatabase.getSegments(
          _voyageId,
        );
        if (cached !=
            null) {
          setState(
            () {
              secteurActif = cached['segment'];
              prochainSecteur = cached['prochain'];
              tousSecteurs = cached['segments'];
              tousClotures =
                  cached['tous_clotures'] ??
                  false;
              isOffline = true;
              isLoading = false;
            },
          );
          _animCtrl.forward(
            from: 0,
          );
          WidgetsBinding.instance.addPostFrameCallback(
            (
              _,
            ) {
              _showToast(
                '📡 Mode hors-ligne — données en cache',
                isWarning: true,
              );
            },
          );
          return;
        }
      } catch (
        e
      ) {
        debugPrint(
          '❌ Cache error: $e',
        );
      }

      setState(
        () {
          errorMessage = 'Hors-ligne — aucune donnée en cache.\nConnectez-vous une première fois.';
          isLoading = false;
        },
      );
    }
  }

  Future<
    void
  >
  _ouvrirProchainSecteur() async {
    setState(
      () => isActioning = true,
    );
    try {
      final response = await http
          .put(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/voyages/$_voyageId/segment/ouvrir',
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

      final data = jsonDecode(
        response.body,
      );
      if (data['success'] ==
          true) {
        _showToast(
          'Secteur ouvert ✓',
        );
        await _fetchAll();
      } else {
        _showToast(
          data['message'] ??
              'Erreur',
          isError: true,
        );
      }
    } catch (
      e
    ) {
      _showToast(
        'Erreur : $e',
        isError: true,
      );
    }
    setState(
      () => isActioning = false,
    );
  }

  Future<
    void
  >
  _cloturerSecteurActif() async {
    if (secteurActif ==
        null)
      return;
    setState(
      () => isActioning = true,
    );

    final id = _voyageId;
    final idSeg =
        secteurActif!['id_segment']
            as int;
    bool clotureOk = false;

    try {
      final response = await http
          .put(
            Uri.parse(
              'http://172.24.114.63:8000/billetterie/voyages/$id/segments/$idSeg/cloturer',
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

      final data = jsonDecode(
        response.body,
      );
      if (data['success'] !=
          true) {
        _showToast(
          data['message'] ??
              'Erreur',
          isError: true,
        );
        setState(
          () => isActioning = false,
        );
        return;
      }
      clotureOk = true;
    } catch (
      _
    ) {}

    if (clotureOk) {
      _showToast(
        'Secteur clôturé ✓',
        isWarning: true,
      );
      await _fetchAll();

      if (!tousClotures &&
          prochainSecteur !=
              null) {
        try {
          final openResponse = await http
              .put(
                Uri.parse(
                  'http://172.24.114.63:8000/billetterie/voyages/$id/segment/ouvrir',
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
          final openData = jsonDecode(
            openResponse.body,
          );
          if (openData['success'] ==
              true) {
            await _fetchAll();
          } else {
            _showToast(
              openData['message'] ??
                  'Erreur ouverture',
              isError: true,
            );
          }
        } catch (
          e
        ) {
          _showToast(
            'Erreur ouverture : $e',
            isError: true,
          );
        }
      }
    } else {
      await _handleOfflineCloture(
        id,
        idSeg,
      );
    }

    setState(
      () => isActioning = false,
    );
  }

  Future<
    void
  >
  _handleOfflineCloture(
    int idVente,
    int idSegment,
  ) async {
    final result = await LocalDatabase.applyOfflineCloture(
      idVente: idVente,
      idSegment: idSegment,
    );

    setState(
      () {
        secteurActif = result.allDone
            ? null
            : result.newActif;
        prochainSecteur = result.allDone
            ? null
            : result.newProchain;
        tousSecteurs = result.updatedSegments;
        tousClotures = result.allDone;
        isOffline = true;
      },
    );

    _showToast(
      result.allDone
          ? 'Tous secteurs clôturés hors-ligne ✓ (sync auto dès réseau)'
          : 'Secteur clôturé hors-ligne ✓ (sync auto dès réseau)',
      isWarning: true,
    );
  }

  void _goToTicketing() {
    if (secteurActif ==
        null) {
      _showToast(
        'Aucun secteur actif',
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (
              _,
            ) => TicketingPage(
              voyage: widget.voyage,
              segment: secteurActif!,
            ),
      ),
    );
  }

  void _confirmCloture() {
    if (secteurActif ==
        null)
      return;
    showDialog(
      context: context,
      builder:
          (
            _,
          ) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                22,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  const Text(
                    'Clôturer ce secteur ?',
                    style: TextStyle(
                      color: navyDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.route,
                          size: 13,
                          color: navyMid,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            '${secteurActif!['point_depart']}  →  ${secteurActif!['point_arrivee']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: navyMid,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  if (isOffline)
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(
                          8,
                        ),
                        border: Border.all(
                          color: Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.offline_bolt,
                            size: 13,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Flexible(
                            child: Text(
                              'Hors-ligne — sera synchronisé dès la reconnexion',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    "Le secteur suivant s'ouvrira automatiquement.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 22,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(
                            context,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                            side: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                            _cloturerSecteurActif();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Clôturer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════

  Color
  _statutColor(
    String s,
  ) =>
      s ==
          'actif'
      ? const Color(
          0xFF16A34A,
        )
      : s ==
            'cloture'
      ? Colors.grey.shade400
      : Colors.orange.shade600;

  String
  _statutLabel(
    String s,
  ) =>
      s ==
          'actif'
      ? 'ACTIF'
      : s ==
            'cloture'
      ? 'CLÔTURÉ'
      : 'EN ATTENTE';

  IconData
  _statutIcon(
    String s,
  ) =>
      s ==
          'actif'
      ? Icons.radio_button_checked_rounded
      : s ==
            'cloture'
      ? Icons.check_circle_rounded
      : Icons.radio_button_unchecked_rounded;

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
      body: isLoading
          ? Column(
              children: [
                _buildHeader(
                  depart,
                  arrivee,
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
                _buildHeader(
                  depart,
                  arrivee,
                ),
                Expanded(
                  child: _buildError(),
                ),
              ],
            )
          : RefreshIndicator(
              color: navyMid,
              onRefresh: _fetchAll,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(
                          depart,
                          arrivee,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          40,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _buildBody(),
                            ],
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
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 17,
                  ),
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
            'Gestion des Segments',
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
                Flexible(
                  child: Text(
                    depart,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                Flexible(
                  child: Text(
                    arrivee,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
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
  // BODY
  // ════════════════════════════════════════════════════

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOffline) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              bottom: 16,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color: Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(
                  width: 8,
                ),
                Flexible(
                  child: Text(
                    'Mode hors-ligne — les actions seront synchronisées dès la reconnexion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Active sector ──
        if (secteurActif !=
            null) ...[
          _sectionLabel(
            'Secteur en cours',
            Icons.radio_button_checked_rounded,
            const Color(
              0xFF16A34A,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          _buildStatusCard(
            depart:
                secteurActif!['point_depart'] ??
                '',
            arrivee:
                secteurActif!['point_arrivee'] ??
                '',
            timestamp: secteurActif!['date_ouverture'],
            accent: const Color(
              0xFF16A34A,
            ),
            badgeLabel: 'ACTIF',
            icon: Icons.directions_bus_rounded,
            note: 'Ouvert',
          ),
          const SizedBox(
            height: 14,
          ),
          _actionBtn(
            label: 'Billetterie',
            sublabel: 'Vente de tickets & passages spéciaux',
            icon: Icons.confirmation_number_rounded,
            colors: [
              navyDark,
              navyLight,
            ],
            onPressed: _goToTicketing,
          ),
          const SizedBox(
            height: 10,
          ),
          _actionBtn(
            label: 'Clôturer ce secteur',
            sublabel: "Le secteur suivant s'ouvrira automatiquement",
            icon: Icons.flag_rounded,
            colors: [
              const Color(
                0xFFB45309,
              ),
              const Color(
                0xFFEA580C,
              ),
            ],
            onPressed: _confirmCloture,
            isLoading: isActioning,
          ),
          const SizedBox(
            height: 28,
          ),
        ],

        // ── Next sector (no active) ──
        if (secteurActif ==
                null &&
            !tousClotures &&
            prochainSecteur !=
                null) ...[
          _sectionLabel(
            'Prochain secteur',
            Icons.schedule_rounded,
            Colors.orange.shade600,
          ),
          const SizedBox(
            height: 10,
          ),
          _buildStatusCard(
            depart:
                prochainSecteur!['point_depart'] ??
                '',
            arrivee:
                prochainSecteur!['point_arrivee'] ??
                '',
            timestamp: null,
            accent: Colors.orange.shade600,
            badgeLabel: 'EN ATTENTE',
            icon: Icons.schedule_rounded,
            note: 'Prêt à ouvrir',
          ),
          const SizedBox(
            height: 12,
          ),
          if (!isOffline)
            _actionBtn(
              label: 'Ouvrir ce secteur',
              sublabel: 'Démarrer la vente de tickets',
              icon: Icons.play_arrow_rounded,
              colors: [
                const Color(
                  0xFF15803D,
                ),
                const Color(
                  0xFF16A34A,
                ),
              ],
              onPressed: _ouvrirProchainSecteur,
              isLoading: isActioning,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(
                        11,
                      ),
                    ),
                    child: Icon(
                      Icons.sync,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ouverture en attente de sync',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          "S'ouvrira automatiquement dès la reconnexion",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(
            height: 28,
          ),
        ],

        // ── All done ──
        if (tousClotures) ...[
          _buildAllDone(),
          const SizedBox(
            height: 28,
          ),
        ],

        // ── Full timeline ──
        if (tousSecteurs.isNotEmpty) ...[
          _sectionLabel(
            'Parcours complet · ${tousSecteurs.length} segments',
            Icons.route_rounded,
            navyMid,
          ),
          const SizedBox(
            height: 10,
          ),
          _buildTimeline(),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════════════════════

  Widget _buildStatusCard({
    required String depart,
    required String arrivee,
    required String? timestamp,
    required Color accent,
    required String badgeLabel,
    required IconData icon,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: accent.withOpacity(
            0.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: navyMid.withOpacity(
              0.07,
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
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(
                4,
              ),
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        depart,
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
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        arrivee,
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
                    Flexible(
                      child: Text(
                        timestamp !=
                                null
                            ? '$note · $timestamp'
                            : note,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: accent.withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(
                20,
              ),
              border: Border.all(
                color: accent.withOpacity(
                  0.3,
                ),
              ),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required String sublabel,
    required IconData icon,
    required List<
      Color
    >
    colors,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    final enabled = !isLoading;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: enabled
              ? onPressed
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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.15,
                    ),
                    borderRadius: BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          color: enabled
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        sublabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: enabled
                              ? Colors.white.withOpacity(
                                  0.7,
                                )
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(
                    0.6,
                  ),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(
          16,
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
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tousSecteurs.length,
        itemBuilder:
            (
              _,
              i,
            ) {
              final s =
                  tousSecteurs[i]
                      as Map<
                        String,
                        dynamic
                      >;
              final statut =
                  s['statut']
                      as String? ??
                  'en_attente';
              final color = _statutColor(
                statut,
              );
              final isActif =
                  statut ==
                  'actif';
              final isLast =
                  i ==
                  tousSecteurs.length -
                      1;

              return Column(
                children: [
                  Container(
                    color: isActif
                        ? const Color(
                            0xFF16A34A,
                          ).withOpacity(
                            0.04,
                          )
                        : Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(
                              0.08,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActif
                                  ? color
                                  : color.withOpacity(
                                      0.35,
                                    ),
                              width: isActif
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${s['ordre']}',
                              style: TextStyle(
                                color: isActif
                                    ? color
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      s['point_depart'] ??
                                          '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isActif
                                            ? navyDark
                                            : Colors.grey.shade500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      s['point_arrivee'] ??
                                          '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isActif
                                            ? navyDark
                                            : Colors.grey.shade500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (s['date_ouverture'] !=
                                      null ||
                                  s['date_cloture'] !=
                                      null) ...[
                                const SizedBox(
                                  height: 3,
                                ),
                                if (s['date_ouverture'] !=
                                    null)
                                  Text(
                                    'Ouvert · ${s['date_ouverture']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (s['date_cloture'] !=
                                    null)
                                  Text(
                                    'Clôturé · ${s['date_cloture']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                            border: Border.all(
                              color: color.withOpacity(
                                0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statutIcon(
                                  statut,
                                ),
                                color: color,
                                size: 10,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                _statutLabel(
                                  statut,
                                ),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey.shade100,
                    ),
                ],
              );
            },
      ),
    );
  }

  Widget _sectionLabel(
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 14,
        ),
        const SizedBox(
          width: 8,
        ),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: navyDark,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAllDone() {
    return Container(
      padding: const EdgeInsets.all(
        28,
      ),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: const Color(
            0xFF86EFAC,
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
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color:
                  const Color(
                    0xFF16A34A,
                  ).withOpacity(
                    0.1,
                  ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(
                0xFF16A34A,
              ),
              size: 36,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          const Text(
            'Tous les secteurs sont clôturés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: navyDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            'Vous pouvez maintenant clôturer le voyage',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade400,
                size: 32,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text(
                'Réessayer',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navyMid,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              onPressed: _fetchAll,
            ),
          ],
        ),
      ),
    );
  }
}
