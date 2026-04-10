import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../ticket_repository.dart';
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

class NouveauTicketPage
    extends
        StatefulWidget {
  final Map<
    String,
    dynamic
  >
  voyage;
  final bool embeddedMode;

  const NouveauTicketPage({
    super.key,
    required this.voyage,
    this.embeddedMode = false,
  });

  @override
  State<
    NouveauTicketPage
  >
  createState() => _NouveauTicketPageState();
}

class _NouveauTicketPageState
    extends
        State<
          NouveauTicketPage
        > {
  String? pointDepart;
  String? pointArrivee;
  String? typeTarif;
  int quantite = 1;

  List<
    String
  >
  arrets = [];
  Map<
    String,
    int
  >
  prixMap = {};
  List<
    Map<
      String,
      dynamic
    >
  >
  tarifTypes = [];

  bool isLoading = true;
  bool isSaving = false;
  bool isCloturing = false;
  bool isOffline = false;
  String? errorMessage;

  int ticketsVendus = 0;
  int montantTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<
    void
  >
  _fetchData() async {
    final idLigne =
        widget.voyage['id_ligne']
            as int;
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://192.168.1.22:8000/billetterie/ligne/$idLigne/tarifs',
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
          await LocalDatabase.saveTarifs(
            idLigne,
            data,
          );
          if (mounted) {
            _applyTarifs(
              data,
              fromCache: false,
            );
          }
          return;
        }
      }
    } catch (
      _
    ) {}

    final cached = await LocalDatabase.getTarifs(
      idLigne,
    );
    if (cached !=
        null) {
      if (mounted)
        _applyTarifs(
          cached,
          fromCache: true,
        );
    } else {
      if (mounted) {
        setState(
          () {
            errorMessage = 'Hors-ligne — aucune donnée en cache.\nConnectez-vous une première fois avec internet\npour activer le mode hors-ligne.';
            isLoading = false;
          },
        );
      }
    }
  }

  void _applyTarifs(
    Map<
      String,
      dynamic
    >
    data, {
    required bool fromCache,
  }) {
    final rawArrets =
        List<
          String
        >.from(
          data['arrets'],
        );
    setState(
      () {
        isOffline = fromCache;
        arrets = _orderArretsByDirection(
          rawArrets,
        );
        prixMap =
            Map<
              String,
              int
            >.from(
              (data['prix_map']
                      as Map)
                  .map(
                    (
                      k,
                      v,
                    ) => MapEntry(
                      k.toString(),
                      v
                          as int,
                    ),
                  ),
            );
        tarifTypes =
            List<
              Map<
                String,
                dynamic
              >
            >.from(
              data['tarif_types'],
            );
        isLoading = false;
        final normalTarif = tarifTypes.firstWhere(
          (
            t,
          ) =>
              (t['type_tarif']
                      as String)
                  .toLowerCase() ==
              'normal',
          orElse: () => tarifTypes.isNotEmpty
              ? tarifTypes.first
              : {},
        );
        if (normalTarif.isNotEmpty) {
          typeTarif =
              normalTarif['type_tarif']
                  as String;
        }
      },
    );

    if (fromCache &&
        mounted) {
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
                      '📡 Mode hors-ligne — données en cache',
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
    }
  }

  List<
    String
  >
  _orderArretsByDirection(
    List<
      String
    >
    raw,
  ) {
    if (raw.isEmpty) return raw;
    final voyageDepart =
        widget.voyage['depart']
            as String? ??
        '';
    if (raw.last.trim().toLowerCase() ==
        voyageDepart.trim().toLowerCase()) {
      return raw.reversed.toList();
    }
    return raw;
  }

  List<
    String
  >
  get _departureArrets => arrets.isEmpty
      ? []
      : arrets.sublist(
          0,
          arrets.length -
              1,
        );

  List<
    String
  >
  get _arrivalArrets {
    if (pointDepart ==
        null)
      return [];
    final idx = arrets.indexOf(
      pointDepart!,
    );
    if (idx ==
            -1 ||
        idx >=
            arrets.length -
                1)
      return [];
    return arrets.sublist(
      idx +
          1,
    );
  }

  int? get _prixNormal {
    if (pointDepart ==
            null ||
        pointArrivee ==
            null ||
        pointDepart ==
            pointArrivee)
      return null;
    return prixMap['$pointDepart|$pointArrivee'] ??
        prixMap['$pointArrivee|$pointDepart'];
  }

  int? get _prixUnitaire {
    final base = _prixNormal;
    if (base ==
            null ||
        typeTarif ==
            null)
      return null;
    final tarif = tarifTypes.firstWhere(
      (
        t,
      ) =>
          t['type_tarif'] ==
          typeTarif,
      orElse: () => {},
    );
    if (tarif.isEmpty) return null;
    return (base *
            (tarif['pourcentage']
                as int) /
            100)
        .round();
  }

  int? get _prixTotal =>
      _prixUnitaire !=
          null
      ? _prixUnitaire! *
            quantite
      : null;

  int get _discountPct {
    if (typeTarif ==
        null)
      return 0;
    final tarif = tarifTypes.firstWhere(
      (
        t,
      ) =>
          t['type_tarif'] ==
          typeTarif,
      orElse: () => {},
    );
    if (tarif.isEmpty) return 0;
    return 100 -
        (tarif['pourcentage']
            as int);
  }

  bool get _canValidate =>
      typeTarif !=
          null &&
      pointDepart !=
          null &&
      pointArrivee !=
          null &&
      pointDepart !=
          pointArrivee &&
      _prixUnitaire !=
          null;

  Future<
    void
  >
  _saveTicket() async {
    final idVente =
        widget.voyage['id']
            as int?;
    final idSegment =
        widget.voyage['id_segment']
            as int?;
    final matricule =
        widget.voyage['matricule_agent']
            as int?;
    if (idVente ==
        null) {
      _showSnack(
        'ID du voyage manquant',
        isError: true,
      );
      return;
    }

    setState(
      () => isSaving = true,
    );

    final qte = quantite;
    final prixU = _prixUnitaire!;
    final prixT = _prixTotal!;
    final dep = pointDepart!;
    final arr = pointArrivee!;
    final tarif = typeTarif!;

    final result = await TicketRepository.saveTicket(
      {
        'id_vente': idVente,
        'id_segment':
            idSegment ??
            0,
        'point_depart': dep,
        'point_arrivee': arr,
        'type_tarif': tarif,
        'quantite': qte,
        'prix_unitaire': prixU,
        'montant_total': prixT,
        'matricule_agent':
            matricule ??
            0,
      },
    );

    if (result.success) {
      setState(
        () {
          ticketsVendus += qte;
          montantTotal += prixT;
          pointDepart = null;
          pointArrivee = null;
          quantite = 1;
          isOffline = result.wasOffline;
        },
      );
      if (result.wasOffline) {
        _showSnack(
          '📡 Hors-ligne — ticket sauvegardé localement',
          isWarning: true,
        );
      } else {
        _showSnack(
          prixT ==
                  0
              ? '✓  $qte passage(s) gratuit(s) enregistré(s)'
              : '✓  $qte ticket(s) · $prixT millimes',
        );
      }
    } else {
      _showSnack(
        'Erreur : ${result.error ?? 'inconnue'}',
        isError: true,
      );
    }

    setState(
      () => isSaving = false,
    );
  }

  Future<
    void
  >
  _cloturerSecteur() async {
    final idVoyage =
        widget.voyage['id']
            as int?;
    final idSegment =
        widget.voyage['id_segment']
            as int?;
    if (idVoyage ==
            null ||
        idSegment ==
            null) {
      _showSnack(
        'Informations du secteur manquantes',
        isError: true,
      );
      return;
    }
    setState(
      () => isCloturing = true,
    );
    try {
      final clotData = jsonDecode(
        (await http.put(
          Uri.parse(
            'http://192.168.1.22:8000/billetterie/voyages/$idVoyage/segments/$idSegment/cloturer',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
        )).body,
      );
      if (clotData['success'] !=
          true) {
        _showSnack(
          clotData['message'] ??
              'Erreur clôture',
          isError: true,
        );
        setState(
          () => isCloturing = false,
        );
        return;
      }
      _showSnack(
        'Secteur clôturé ✓',
        isWarning: true,
      );

      final checkData = jsonDecode(
        (await http.get(
          Uri.parse(
            'http://192.168.1.22:8000/billetterie/voyages/$idVoyage/segment/actif',
          ),
        )).body,
      );
      if (checkData['tous_clotures'] ==
              true ||
          checkData['prochain'] ==
              null) {
        if (mounted)
          Navigator.pop(
            context,
          );
        setState(
          () => isCloturing = false,
        );
        return;
      }

      final openData = jsonDecode(
        (await http.put(
          Uri.parse(
            'http://192.168.1.22:8000/billetterie/voyages/$idVoyage/segment/ouvrir',
          ),
          headers: {
            'Content-Type': 'application/json',
          },
        )).body,
      );
      if (openData['success'] !=
          true) {
        _showSnack(
          openData['message'] ??
              'Erreur ouverture',
          isError: true,
        );
        setState(
          () => isCloturing = false,
        );
        return;
      }

      final newData = jsonDecode(
        (await http.get(
          Uri.parse(
            'http://192.168.1.22:8000/billetterie/voyages/$idVoyage/segment/actif',
          ),
        )).body,
      );
      final newSecteur =
          newData['segment']
              as Map<
                String,
                dynamic
              >?;
      if (newSecteur ==
              null ||
          !mounted) {
        if (mounted)
          Navigator.pop(
            context,
          );
        setState(
          () => isCloturing = false,
        );
        return;
      }
      _showSnack(
        'Secteur suivant ouvert ✓',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (
                _,
              ) => NouveauTicketPage(
                voyage: {
                  ...widget.voyage,
                  'depart': newSecteur['point_depart'],
                  'arrivee': newSecteur['point_arrivee'],
                  'id_segment': newSecteur['id_segment'],
                  'id_ligne': widget.voyage['id_ligne'],
                },
              ),
        ),
      );
    } catch (
      e
    ) {
      _showSnack(
        'Erreur : $e',
        isError: true,
      );
      setState(
        () => isCloturing = false,
      );
    }
  }

  void _confirmCloture() {
    final dep =
        widget.voyage['depart'] ??
        '?';
    final arr =
        widget.voyage['arrivee'] ??
        '?';
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
                          '$dep  →  $arr',
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
                            _cloturerSecteur();
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

  void _vendreTicket() {
    if (!_canValidate) return;
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          navyDark,
                          navyLight,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.confirmation_number,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  const Text(
                    'Confirmer le ticket',
                    style: TextStyle(
                      color: navyDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  _confirmRow(
                    Icons.trip_origin,
                    'Montée',
                    pointDepart!,
                  ),
                  _dividerLine(),
                  _confirmRow(
                    Icons.location_on_outlined,
                    'Descente',
                    pointArrivee!,
                  ),
                  _dividerLine(),
                  _confirmRow(
                    Icons.sell_outlined,
                    'Tarif',
                    typeTarif!,
                  ),
                  _dividerLine(),
                  _confirmRow(
                    Icons.people_outline,
                    'Quantité',
                    '$quantite ticket${quantite > 1 ? 's' : ''}',
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _prixTotal ==
                              0
                          ? const Color(
                              0xFFDCFCE7,
                            )
                          : const Color(
                              0xFFEFF3FF,
                            ),
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_discountPct >
                            0)
                          Text(
                            '${_prixNormal! * quantite} ms',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (quantite >
                            1)
                          Text(
                            '$quantite × $_prixUnitaire ms',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        Text(
                          _prixTotal ==
                                  0
                              ? 'GRATUIT'
                              : '${_prixTotal} millimes',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color:
                                _prixTotal ==
                                    0
                                ? const Color(
                                    0xFF16A34A,
                                  )
                                : navyDark,
                          ),
                        ),
                        if (_discountPct >
                            0) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              '−$_discountPct% appliqué',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 18,
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
                            _saveTicket();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navyMid,
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
                            'Valider',
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

  Widget _confirmRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: navyLight.withOpacity(
              0.6,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            '$label  ',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: navyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() => Divider(
    height: 1,
    color: Colors.grey.shade100,
  );

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

  @override
  Widget build(
    BuildContext context,
  ) {
    final voyageDepart =
        widget.voyage['depart'] ??
        '?';
    final voyageArrivee =
        widget.voyage['arrivee'] ??
        '?';

    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header (hidden in embedded mode) ──
            if (!widget.embeddedMode)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Nouveau Ticket',
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
                            voyageDepart,
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
                            voyageArrivee,
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

            // ── Counter bar ──
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
                  Expanded(
                    child: _counterTile(
                      Icons.confirmation_number_outlined,
                      'Tickets vendus',
                      '$ticketsVendus',
                      navyMid,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.grey.shade100,
                  ),
                  Expanded(
                    child: _counterTile(
                      Icons.account_balance_wallet_outlined,
                      'Total collecté',
                      '$montantTotal ms',
                      const Color(
                        0xFF16A34A,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
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
                              size: 52,
                              color: Colors.orange.shade200,
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(
                                  () {
                                    isLoading = true;
                                    errorMessage = null;
                                  },
                                );
                                _fetchData();
                              },
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(
                          'Type de tarif',
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tarifTypes
                              .where(
                                (
                                  t,
                                ) =>
                                    (t['pourcentage']
                                        as int) !=
                                    0,
                              )
                              .toList()
                              .length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 3.8,
                          ),
                          itemBuilder:
                              (
                                _,
                                i,
                              ) {
                                final filteredTarifs = tarifTypes
                                    .where(
                                      (
                                        t,
                                      ) =>
                                          (t['pourcentage']
                                              as int) !=
                                          0,
                                    )
                                    .toList();
                                final t = filteredTarifs[i];
                                final type =
                                    t['type_tarif']
                                        as String;
                                final pct =
                                    t['pourcentage']
                                        as int;
                                final discount =
                                    100 -
                                    pct;
                                final isSelected =
                                    typeTarif ==
                                    type;
                                final Color accent =
                                    pct <=
                                        25
                                    ? const Color(
                                        0xFF7C3AED,
                                      )
                                    : pct <=
                                          50
                                    ? const Color(
                                        0xFFD97706,
                                      )
                                    : navyMid;
                                return GestureDetector(
                                  onTap: () => setState(
                                    () => typeTarif = type,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? accent
                                          : cardWhite,
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? accent
                                            : accent.withOpacity(
                                                0.3,
                                              ),
                                        width: 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: accent.withOpacity(
                                                  0.25,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(
                                                  0,
                                                  3,
                                                ),
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.04,
                                                ),
                                                blurRadius: 4,
                                              ),
                                            ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            discount >
                                                    0
                                                ? Icons.discount_rounded
                                                : Icons.person_rounded,
                                            color: isSelected
                                                ? Colors.white
                                                : accent,
                                            size: 16,
                                          ),
                                          const SizedBox(
                                            width: 8,
                                          ),
                                          Expanded(
                                            child: Text(
                                              type,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          if (discount >
                                              0)
                                            _tarifBadge(
                                              '−$discount%',
                                              accent,
                                              isSelected,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                        ),
                        const SizedBox(
                          height: 22,
                        ),
                        _label(
                          'Trajet',
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        _card(
                          child: Column(
                            children: [
                              _dropdownRow(
                                icon: Icons.trip_origin,
                                iconColor: const Color(
                                  0xFF16A34A,
                                ),
                                label: 'Point de montée',
                                hint: 'Choisir un arrêt',
                                value: pointDepart,
                                items: _departureArrets,
                                onChanged:
                                    (
                                      v,
                                    ) => setState(
                                      () {
                                        pointDepart = v;
                                        pointArrivee = null;
                                      },
                                    ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 14,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 1.5,
                                      height: 22,
                                      color: Colors.grey.shade200,
                                    ),
                                  ],
                                ),
                              ),
                              _dropdownRow(
                                icon: Icons.location_on,
                                iconColor: Colors.red.shade500,
                                label: 'Point de descente',
                                hint:
                                    pointDepart ==
                                        null
                                    ? 'Choisir d\'abord la montée'
                                    : 'Choisir un arrêt',
                                value: pointArrivee,
                                items: _arrivalArrets,
                                onChanged:
                                    pointDepart ==
                                        null
                                    ? null
                                    : (
                                        v,
                                      ) => setState(
                                        () => pointArrivee = v,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 22,
                        ),
                        _label(
                          'Nombre de tickets',
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        _card(
                          child: Row(
                            children: [
                              _qtyBtn(
                                Icons.remove,
                                quantite >
                                    1,
                                () => setState(
                                  () => quantite--,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '$quantite',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: navyDark,
                                      ),
                                    ),
                                    Text(
                                      quantite ==
                                              1
                                          ? 'ticket'
                                          : 'tickets',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _qtyBtn(
                                Icons.add,
                                true,
                                () => setState(
                                  () => quantite++,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 22,
                        ),
                        if (_prixUnitaire !=
                            null) ...[
                          _PriceCard(
                            prixNormal: _prixNormal,
                            prixUnitaire: _prixUnitaire!,
                            prixTotal: _prixTotal!,
                            quantite: quantite,
                            discountPct: _discountPct,
                          ),
                          const SizedBox(
                            height: 22,
                          ),
                        ],
                        _actionBtn(
                          label: isSaving
                              ? 'Enregistrement...'
                              : quantite >
                                    1
                              ? 'Valider $quantite tickets'
                              : 'Valider le ticket',
                          icon: isSaving
                              ? null
                              : Icons.confirmation_number_rounded,
                          isLoading: isSaving,
                          enabled:
                              _canValidate &&
                              !isSaving &&
                              !isCloturing,
                          colors: [
                            navyDark,
                            navyLight,
                          ],
                          onTap: _vendreTicket,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        _actionBtn(
                          label: isCloturing
                              ? 'Clôture en cours...'
                              : 'Clôturer ce secteur',
                          icon: isCloturing
                              ? null
                              : Icons.check_circle_outline_rounded,
                          isLoading: isCloturing,
                          enabled:
                              !isSaving &&
                              !isCloturing,
                          colors: [
                            const Color(
                              0xFFB45309,
                            ),
                            const Color(
                              0xFFEA580C,
                            ),
                          ],
                          onTap: _confirmCloture,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarifBadge(
    String text,
    Color accent,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withOpacity(
                0.25,
              )
            : accent.withOpacity(
                0.12,
              ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isSelected
              ? Colors.white
              : accent,
        ),
      ),
    );
  }

  Widget
  _label(
    String text,
  ) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: navyDark,
      letterSpacing: 0.5,
    ),
  );

  Widget
  _card({
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
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
    child: child,
  );

  Widget _counterTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
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
    );
  }

  Widget _dropdownRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
    required String? value,
    required List<
      String
    >
    items,
    required void Function(
      String?,
    )?
    onChanged,
  }) {
    final effectiveValue =
        (value !=
                null &&
            items.contains(
              value,
            ))
        ? value
        : null;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(
              0.1,
            ),
            borderRadius: BorderRadius.circular(
              8,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 15,
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
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              DropdownButtonHideUnderline(
                child:
                    DropdownButton<
                      String
                    >(
                      value: effectiveValue,
                      hint: Text(
                        hint,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      isExpanded: true,
                      isDense: true,
                      icon: Icon(
                        Icons.expand_more,
                        color:
                            onChanged ==
                                null
                            ? Colors.grey.shade300
                            : navyLight.withOpacity(
                                0.5,
                              ),
                        size: 18,
                      ),
                      style: const TextStyle(
                        color: navyDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: onChanged,
                      items: items
                          .map(
                            (
                              a,
                            ) => DropdownMenuItem(
                              value: a,
                              child: Text(
                                a,
                                style: const TextStyle(
                                  color: navyDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(
    IconData icon,
    bool enabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: enabled
          ? onTap
          : null,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 150,
        ),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? navyMid
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(
            12,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: navyMid.withOpacity(
                      0.3,
                    ),
                    blurRadius: 6,
                    offset: const Offset(
                      0,
                      2,
                    ),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: enabled
              ? Colors.white
              : Colors.grey.shade300,
          size: 18,
        ),
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

class _PriceCard
    extends
        StatelessWidget {
  final int? prixNormal;
  final int prixUnitaire;
  final int prixTotal;
  final int quantite;
  final int discountPct;

  const _PriceCard({
    required this.prixNormal,
    required this.prixUnitaire,
    required this.prixTotal,
    required this.quantite,
    required this.discountPct,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isFree =
        prixTotal ==
        0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        gradient: isFree
            ? const LinearGradient(
                colors: [
                  Color(
                    0xFFDCFCE7,
                  ),
                  Color(
                    0xFFF0FDF4,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(
                    0xFFEBF0FF,
                  ),
                  Color(
                    0xFFF2F5FF,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: isFree
              ? const Color(
                  0xFF86EFAC,
                )
              : const Color(
                  0xFFB8C8F0,
                ),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            isFree
                ? 'GRATUIT'
                : '$prixTotal millimes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: isFree
                  ? const Color(
                      0xFF16A34A,
                    )
                  : navyDark,
            ),
          ),
          if (quantite >
                  1 ||
              discountPct >
                  0) ...[
            const SizedBox(
              height: 8,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (quantite >
                    1)
                  _pill(
                    '$quantite × $prixUnitaire ms',
                    navyMid,
                  ),
                if (discountPct >
                    0)
                  _pill(
                    '−$discountPct%',
                    Colors.orange.shade700,
                  ),
                if (discountPct >
                        0 &&
                    prixNormal !=
                        null)
                  Text(
                    '${prixNormal! * quantite} ms',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget
  _pill(
    String text,
    Color color,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 3,
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
          0.25,
        ),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
