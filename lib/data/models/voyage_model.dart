class SegmentModel {
  final int idSegment;
  final String pointDepart;
  final String pointArrivee;
  final String statut; // en_attente | actif | cloture
  final String? dateOuverture;
  final String? dateCloture;

  const SegmentModel({
    required this.idSegment,
    required this.pointDepart,
    required this.pointArrivee,
    required this.statut,
    this.dateOuverture,
    this.dateCloture,
  });

  factory SegmentModel.fromMap(Map<String, dynamic> map) {
    return SegmentModel(
      idSegment:     map['id_segment']    as int,
      pointDepart:   map['point_depart']  as String? ?? '',
      pointArrivee:  map['point_arrivee'] as String? ?? '',
      statut:        map['statut']        as String? ?? 'en_attente',
      dateOuverture: map['date_ouverture'] as String?,
      dateCloture:   map['date_cloture']   as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id_segment':    idSegment,
    'point_depart':  pointDepart,
    'point_arrivee': pointArrivee,
    'statut':        statut,
    if (dateOuverture != null) 'date_ouverture': dateOuverture,
    if (dateCloture   != null) 'date_cloture':   dateCloture,
  };

  bool get isActif     => statut == 'actif';
  bool get isCloture   => statut == 'cloture';
  bool get isEnAttente => statut == 'en_attente';
}

// ─────────────────────────────────────────────────────────────

class VoyageModel {
  final int idVente;
  final int idLigne;
  final String pointDepart;
  final String pointArrivee;
  final String dateDepart;
  final String statut; // actif | cloture | …
  final int matriculeAgent;
  final List<SegmentModel> segments;

  const VoyageModel({
    required this.idVente,
    required this.idLigne,
    required this.pointDepart,
    required this.pointArrivee,
    required this.dateDepart,
    required this.statut,
    required this.matriculeAgent,
    this.segments = const [],
  });

  factory VoyageModel.fromMap(Map<String, dynamic> map) {
    final rawSegs = map['segments'] as List<dynamic>? ?? [];
    return VoyageModel(
      idVente:        map['id_vente']        as int,
      idLigne:        map['id_ligne']        as int? ?? 0,
      pointDepart:    map['point_depart']    as String? ?? '',
      pointArrivee:   map['point_arrivee']   as String? ?? '',
      dateDepart:     map['date_depart']     as String? ?? '',
      statut:         map['statut']          as String? ?? '',
      matriculeAgent: map['matricule_agent'] as int? ?? 0,
      segments: rawSegs
          .map((s) => SegmentModel.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id_vente':        idVente,
    'id_ligne':        idLigne,
    'point_depart':    pointDepart,
    'point_arrivee':   pointArrivee,
    'date_depart':     dateDepart,
    'statut':          statut,
    'matricule_agent': matriculeAgent,
    'segments': segments.map((s) => s.toMap()).toList(),
  };

  bool get isActif   => statut == 'actif';
  bool get isCloture => statut == 'cloture';

  SegmentModel? get activeSegment =>
      segments.where((s) => s.isActif).firstOrNull;

  SegmentModel? get nextSegment =>
      segments.where((s) => s.isEnAttente).firstOrNull;

  @override
  String toString() =>
      'VoyageModel(id=$idVente, $pointDepart→$pointArrivee, statut=$statut)';
}