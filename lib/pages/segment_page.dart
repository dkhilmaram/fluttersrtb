import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'nouveauticketPage.dart';

// ── Color palette (matches NouveauTicketPage) ──
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
        SingleTickerProviderStateMixin {
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
  String? errorMessage;

  late AnimationController _animCtrl;
  late Animation<
    double
  >
  _fadeAnim;
  late Animation<
    Offset
  >
  _slideAnim;

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
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

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
      final id =
          widget.voyage['id']
              as int?;
      if (id ==
          null)
        throw Exception(
          "ID du voyage manquant",
        );

      final r1 = await http.get(
        Uri.parse(
          'http://127.0.0.1:8000/billetterie/voyages/$id/segment/actif',
        ),
      );
      final r2 = await http.get(
        Uri.parse(
          'http://127.0.0.1:8000/billetterie/voyages/$id/segments',
        ),
      );

      if (r1.statusCode ==
              200 &&
          r2.statusCode ==
              200) {
        final d1 = jsonDecode(
          r1.body,
        );
        final d2 = jsonDecode(
          r2.body,
        );
        if (d1['success'] ==
            true) {
          setState(
            () {
              secteurActif =
                  d1['segment']
                      as Map<
                        String,
                        dynamic
                      >?;
              prochainSecteur =
                  d1['prochain']
                      as Map<
                        String,
                        dynamic
                      >?;
              tousClotures =
                  d1['tous_clotures'] ==
                  true;
              tousSecteurs =
                  d2['segments']
                      as List<
                        dynamic
                      >? ??
                  [];
              isLoading = false;
            },
          );
          _animCtrl.forward(
            from: 0,
          );
        } else {
          throw Exception(
            d1['message'] ??
                'Erreur inconnue',
          );
        }
      } else {
        throw Exception(
          'Erreur serveur (${r1.statusCode})',
        );
      }
    } catch (
      e
    ) {
      setState(
        () {
          errorMessage = e.toString().replaceFirst(
            'Exception: ',
            '',
          );
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
      final id =
          widget.voyage['id']
              as int?;
      final response = await http.put(
        Uri.parse(
          'http://127.0.0.1:8000/billetterie/voyages/$id/segment/ouvrir',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(
        response.body,
      );
      if (data['success'] ==
          true) {
        _showSnack(
          'Secteur ouvert ✓',
        );
        await _fetchAll();
      } else {
        _showSnack(
          data['message'] ??
              'Erreur',
          isError: true,
        );
      }
    } catch (
      e
    ) {
      _showSnack(
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
    try {
      final id =
          widget.voyage['id']
              as int?;
      final idSeg =
          secteurActif!['id_segment']
              as int?;

      final response = await http.put(
        Uri.parse(
          'http://127.0.0.1:8000/billetterie/voyages/$id/segments/$idSeg/cloturer',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(
        response.body,
      );
      if (data['success'] !=
          true) {
        _showSnack(
          data['message'] ??
              'Erreur',
          isError: true,
        );
        setState(
          () => isActioning = false,
        );
        return;
      }

      _showSnack(
        'Secteur clôturé ✓',
        isWarning: true,
      );
      await _fetchAll();

      if (!tousClotures &&
          prochainSecteur !=
              null) {
        final openResponse = await http.put(
          Uri.parse(
            'http://127.0.0.1:8000/billetterie/voyages/$id/segment/ouvrir',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        final openData = jsonDecode(
          openResponse.body,
        );
        if (openData['success'] ==
            true) {
          await _fetchAll();
          if (secteurActif !=
                  null &&
              mounted) {
            final idLigne =
                widget.voyage['id_ligne']
                    as int?;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (
                      _,
                    ) => NouveauTicketPage(
                      voyage: {
                        ...widget.voyage,
                        'depart': secteurActif!['point_depart'],
                        'arrivee': secteurActif!['point_arrivee'],
                        'id_segment': secteurActif!['id_segment'],
                        'id_ligne': idLigne,
                      },
                    ),
              ),
            );
          }
        } else {
          _showSnack(
            openData['message'] ??
                'Erreur ouverture',
            isError: true,
          );
        }
      }
    } catch (
      e
    ) {
      _showSnack(
        'Erreur : $e',
        isError: true,
      );
    }
    setState(
      () => isActioning = false,
    );
  }

  void _showSnack(
    String msg, {
    bool isError = false,
    bool isWarning = false,
  }) {
    final color = isError
        ? Colors.red.shade700
        : isWarning
        ? Colors.orange.shade700
        : const Color(
            0xFF16A34A,
          );
    ScaffoldMessenger.of(
        context,
      )
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : isWarning
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                color: Colors.white,
                size: 17,
              ),
              const SizedBox(
                width: 8,
              ),
              Flexible(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
          ),
          margin: const EdgeInsets.all(
            14,
          ),
          duration: const Duration(
            seconds: 3,
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
                        Text(
                          '${secteurActif!['point_depart']}  →  ${secteurActif!['point_arrivee']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: navyMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    'Le secteur suivant s\'ouvrira automatiquement.',
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

  void _goToSellTickets() {
    if (secteurActif ==
        null) {
      _showSnack(
        "Aucun secteur actif",
        isError: true,
      );
      return;
    }
    final idLigne =
        widget.voyage['id_ligne']
            as int?;
    if (idLigne ==
        null) {
      _showSnack(
        "Ligne introuvable",
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
            ) => NouveauTicketPage(
              voyage: {
                ...widget.voyage,
                'depart': secteurActif!['point_depart'],
                'arrivee': secteurActif!['point_arrivee'],
                'id_segment': secteurActif!['id_segment'],
                'id_ligne': idLigne,
              },
            ),
      ),
    );
  }

  Color _statutColor(
    String s,
  ) {
    switch (s) {
      case 'actif':
        return const Color(
          0xFF16A34A,
        );
      case 'cloture':
        return Colors.grey.shade400;
      default:
        return Colors.orange.shade600;
    }
  }

  String _statutLabel(
    String s,
  ) {
    switch (s) {
      case 'actif':
        return 'ACTIF';
      case 'cloture':
        return 'CLÔTURÉ';
      default:
        return 'EN ATTENTE';
    }
  }

  IconData _statutIcon(
    String s,
  ) {
    switch (s) {
      case 'actif':
        return Icons.radio_button_checked_rounded;
      case 'cloture':
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final departGlobal =
        widget.voyage['depart'] ??
        '?';
    final arriveeGlobal =
        widget.voyage['arrivee'] ??
        '?';

    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          _buildHeader(
            departGlobal,
            arriveeGlobal,
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: navyMid,
                    ),
                  )
                : errorMessage !=
                      null
                ? _buildError()
                : RefreshIndicator(
                    color: navyMid,
                    onRefresh: _fetchAll,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            40,
                          ),
                          child: _buildBody(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header (mirrors NouveauTicketPage header exactly) ──
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
          // Back + refresh row
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
          // Logo
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
          // Route pill
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

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Secteur actif ──
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
            height: 12,
          ),
          _actionBtn(
            label: 'Nouveau Ticket',
            sublabel: '${secteurActif!['point_depart']} → ${secteurActif!['point_arrivee']}',
            icon: Icons.confirmation_number_rounded,
            colors: [
              navyDark,
              navyLight,
            ],
            onPressed: _goToSellTickets,
          ),
          const SizedBox(
            height: 10,
          ),
          _actionBtn(
            label: 'Clôturer ce secteur',
            sublabel: 'Le secteur suivant s\'ouvrira automatiquement',
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

        // ── Prochain secteur ──
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
          ),
          const SizedBox(
            height: 28,
          ),
        ],

        // ── Tous clôturés ──
        if (tousClotures) ...[
          _buildAllDone(),
          const SizedBox(
            height: 28,
          ),
        ],

        // ── Timeline ──
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

  // ── Status card (matches NouveauTicketPage card style) ──
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
          // Left accent bar
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
          // Icon box
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
                    Text(
                      timestamp !=
                              null
                          ? '$note · $timestamp'
                          : note,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
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
          // Badge
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

  // ── Action button (same as NouveauTicketPage _actionBtn) ──
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
    final bool enabled = !isLoading;
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

  // ── Timeline ──
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
              final isActive =
                  statut ==
                  'actif';
              final isLast =
                  i ==
                  tousSecteurs.length -
                      1;

              return Column(
                children: [
                  Container(
                    color: isActive
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
                        // Order circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(
                              0.08,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive
                                  ? color
                                  : color.withOpacity(
                                      0.35,
                                    ),
                              width: isActive
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${s['ordre']}',
                              style: TextStyle(
                                color: isActive
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
                                        color: isActive
                                            ? navyDark
                                            : Colors.grey.shade500,
                                      ),
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
                                        color: isActive
                                            ? navyDark
                                            : Colors.grey.shade500,
                                      ),
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
                                  ),
                                if (s['date_cloture'] !=
                                    null)
                                  Text(
                                    'Clôturé · ${s['date_cloture']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                    ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: navyDark,
            letterSpacing: 0.3,
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
