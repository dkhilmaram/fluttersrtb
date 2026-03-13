import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'vente_tickets.dart';

const Color
srtbBlue = Color(
  0xFF1A3F7A,
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

    try {
      final matricule =
          widget.agent['matricule_agent'] ??
          widget.agent['matricule'];

      final response = await http.get(
        Uri.parse(
          'http://127.0.0.1:8000/billetterie/ventes/programmees/$matricule',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode ==
          200) {
        final data = jsonDecode(
          response.body,
        );
        setState(
          () {
            voyages = data['voyages'];
            isLoading = false;
          },
        );
      } else {
        setState(
          () {
            errorMessage = 'Erreur serveur : ${response.statusCode}';
            isLoading = false;
          },
        );
      }
    } catch (
      _
    ) {
      setState(
        () {
          errorMessage = 'Impossible de se connecter au serveur';
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

  /// Index of the first voyage that is NOT clôturé — this is the only one
  /// the agent can actively work on. All voyages before it are clôturé (history),
  /// all voyages after it are locked (waiting).
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
    return -1; // all done
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
          content: const Text(
            'Terminez le voyage en cours avant d\'accéder à celui-ci',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              color: srtbBlue,
              padding: const EdgeInsets.symmetric(
                vertical: 60,
                horizontal: 24,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                      ),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
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
                            size: 80,
                            color: srtbBlue,
                          ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  const Text(
                    'S R T B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  const Text(
                    'Voyages Programmés',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '${widget.agent['prenom']} ${widget.agent['nom']}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(
                24,
              ),
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: srtbBlue,
                      ),
                    )
                  : errorMessage !=
                        null
                  ? Center(
                      child: Text(
                        errorMessage!,
                      ),
                    )
                  : voyages.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun voyage programmé disponible',
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
                              !isActive; // waiting in queue
                          final dh =
                              v['date_heure']
                                  as String?;

                          // ── Visual state colours ──
                          final Color borderColor;
                          final Color bgColor;
                          final Color iconColor;
                          final Color textColor;

                          if (isCloture) {
                            borderColor = Colors.grey.shade400;
                            bgColor = Colors.grey.shade100;
                            iconColor = Colors.grey;
                            textColor = Colors.grey;
                          } else if (isActive) {
                            borderColor = srtbBlue;
                            bgColor = const Color(
                              0xFFE8F1FF,
                            );
                            iconColor = srtbBlue;
                            textColor = srtbBlue;
                          } else {
                            // locked
                            borderColor = Colors.orange.shade200;
                            bgColor = Colors.orange.shade50;
                            iconColor = Colors.orange.shade400;
                            textColor = Colors.orange.shade700;
                          }

                          return GestureDetector(
                            onTap: () {
                              if (isLocked) {
                                _showLockedSnack();
                              } else {
                                // clôturé → opens history (handled inside VenteTicketsPage)
                                // active  → opens normally
                                _openVoyage(
                                  v,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(
                                bottom: 14,
                              ),
                              padding: const EdgeInsets.all(
                                18,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  14,
                                ),
                                color: bgColor,
                              ),
                              child: Row(
                                children: [
                                  // ── Bus / lock icon ──
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        Icons.directions_bus,
                                        color: iconColor,
                                        size: 32,
                                      ),
                                      if (isLocked)
                                        Positioned(
                                          right: -6,
                                          bottom: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(
                                              2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade700,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.lock,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(
                                    width: 14,
                                  ),

                                  // ── Route + time ──
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${v['depart']} → ${v['arrivee']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 4,
                                        ),
                                        Text(
                                          '${_getTime(dh)} | ${_getDate(dh)}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isLocked) ...[
                                          const SizedBox(
                                            height: 4,
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

                                  // ── Status badge ──
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCloture
                                              ? Colors.red.shade100
                                              : isActive
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            20,
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
                                            color: isCloture
                                                ? Colors.red.shade700
                                                : isActive
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Icon(
                                        isLocked
                                            ? Icons.lock_outline
                                            : Icons.chevron_right,
                                        color: isLocked
                                            ? Colors.orange.shade400
                                            : Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
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
}
