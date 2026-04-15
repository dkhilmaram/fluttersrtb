class SegmentModel {
  final int idSegment;
  final String pointDepart;
  final String pointArrivee;
  final int ordre;

  const SegmentModel({
    required this.idSegment,
    required this.pointDepart,
    required this.pointArrivee,
    required this.ordre,
  });

  factory SegmentModel.fromMap(Map<String, dynamic> map) {
    return SegmentModel(
      idSegment:    map['id_segment']    as int,
      pointDepart:  map['point_depart']  as String? ?? '',
      pointArrivee: map['point_arrivee'] as String? ?? '',
      ordre:        map['ordre']         as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id_segment':    idSegment,
    'point_depart':  pointDepart,
    'point_arrivee': pointArrivee,
    'ordre':         ordre,
  };
}

// ─────────────────────────────────────────────────────────────

class VoyageModel {
  final int idVente;
  final int idLigne;
  final String pointDepart;
  final String pointArrivee;
  final String dateDepart;
  final String statut;
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

  @override
  String toString() =>
      'VoyageModel(id=$idVente, $pointDepart→$pointArrivee, statut=$statut)';
}