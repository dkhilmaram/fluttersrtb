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
        > {
  List<
    dynamic
  >
  voyages = [];
  bool isLoading = true;
  bool isOffline = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVoyages();
  }

  Future<
    void
  >
  _fetchVoyages() async {
    setState(
      () {
        isLoading = true;
        errorMessage = null;
      },
    );

    final matricule =
        widget.agent['matricule_agent'] ??
        widget.agent['matricule'];

    // ── 1. Try server ──
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://127.0.0.1:8000/billetterie/ventes/programmees/$matricule',
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
        final data = jsonDecode(
          response.body,
        );
        final list =
            data['voyages']
                as List<
                  dynamic
                >;
        // ── Save to cache ──
        await LocalDatabase.saveVoyages(
          matricule
              as int,
          list,
        );
        setState(
          () {
            voyages = list;
            isOffline = false;
            isLoading = false;
          },
        );
        return;
      }
    } catch (
      _
    ) {
      // No internet — fall through to cache
    }

    // ── 2. Offline: load from cache ──
    final cached = await LocalDatabase.getVoyages(
      matricule
          as int,
    );
    if (cached !=
        null) {
      setState(
        () {
          voyages = cached;
          isOffline = true;
          isLoading = false;
        },
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (
          _,
        ) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.offline_bolt,
                    color: Colors.white,
                    size: 15,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Flexible(
                    child: Text(
                      '📡 Mode hors-ligne — voyages en cache',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
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
                seconds: 4,
              ),
            ),
          );
        },
      );
    } else {
      setState(
        () {
          errorMessage = 'Hors-ligne — aucune donnée en cache.\nConnectez-vous une première fois pour activer le mode hors-ligne.';
          isLoading = false;
        },
      );
    }
  }

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
      dh !=
              null &&
          dh
                  .split(
                    ' ',
                  )
                  .length >
              1
      ? dh
            .split(
              ' ',
            )[1]
            .substring(
              0,
              5,
            )
      : '';

  int get _activeIndex {
    for (
      int i = 0;
      i <
          voyages.length;
      i++
    ) {
      if (voyages[i]['statut'] !=
          'cloture')
        return i;
    }
    return -1;
  }

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
      ) => _fetchVoyages(),
    );
  }

  void _showLockedSnack() {
    ScaffoldMessenger.of(
        context,
      )
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 17,
              ),
              const SizedBox(
                width: 8,
              ),
              const Flexible(
                child: Text(
                  'Terminez le voyage en cours avant d\'accéder à celui-ci',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
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

  @override
  Widget build(
    BuildContext context,
  ) {
    final activeIdx = _activeIndex;
    final agent = widget.agent;

    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
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
                  // ── Offline badge next to title ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Voyages Programmés',
                        style: TextStyle(
                          color: Colors.white.withOpacity(
                            0.7,
                          ),
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(
                          width: 8,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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
                      ],
                    ],
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
            ),

            // ── Stats bar ──
            if (!isLoading &&
                errorMessage ==
                    null &&
                voyages.isNotEmpty)
              Container(
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
                  children: [
                    _statTile(
                      Icons.directions_bus_outlined,
                      'Total',
                      '${voyages.length}',
                      navyMid,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.shade100,
                    ),
                    _statTile(
                      Icons.check_circle_outline,
                      'Clôturés',
                      '${voyages.where((v) => v['statut'] == 'cloture').length}',
                      Colors.grey,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.shade100,
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
              ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                40,
              ),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 60,
                        ),
                        child: CircularProgressIndicator(
                          color: navyMid,
                        ),
                      ),
                    )
                  : errorMessage !=
                        null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 60,
                        ),
                        child: Column(
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
                              errorMessage!,
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
                              onPressed: _fetchVoyages,
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
                    )
                  : voyages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 60,
                        ),
                        child: Column(
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
                              'Aucun voyage programmé',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: List.generate(
                        voyages.length,
                        (
                          i,
                        ) {
                          final v =
                              voyages[i]
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
                          final dh =
                              v['date_heure']
                                  as String?;

                          final Color accent;
                          final Color bgColor;
                          final Color borderColor;

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

                          return GestureDetector(
                            onTap: () => isLocked
                                ? _showLockedSnack()
                                : _openVoyage(
                                    v,
                                  ),
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
                                        if (isLocked)
                                          Positioned(
                                            right: -4,
                                            bottom: -4,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade700,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: cardWhite,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.lock,
                                                color: Colors.white,
                                                size: 10,
                                              ),
                                            ),
                                          ),
                                        if (isActive)
                                          Positioned(
                                            right: -4,
                                            bottom: -4,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF16A34A,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: cardWhite,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 11,
                                              ),
                                            ),
                                          ),
                                      ],
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
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: isActive
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
                                                  '${v['depart']} → ${v['arrivee']}',
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
                                                '${_getTime(dh)}  ·  ${_getDate(dh)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isLocked) ...[
                                            const SizedBox(
                                              height: 5,
                                            ),
                                            Text(
                                              'En attente du voyage précédent',
                                              style: TextStyle(
                                                color: Colors.orange.shade600,
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
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            isCloture
                                                ? 'Clôturé'
                                                : isActive
                                                ? 'Actif'
                                                : 'En attente',
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
                                          isLocked
                                              ? Icons.lock_outline
                                              : isCloture
                                              ? Icons.history
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
                        },
                      ),
                    ),
            ),
          ],
        ),
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
}
