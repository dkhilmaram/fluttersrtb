class TicketModel {
  final int? id;
  final int idVente;
  final int idSegment;
  final String pointDepart;
  final String pointArrivee;
  final String typeTarif;
  final int quantite;
  final double prixUnitaire;
  final double montantTotal;
  final String dateHeure;
  final int matriculeAgent;
  final String statutSync;
  final int? idServeur;
  final int tentatives;
  final String? erreur;

  const TicketModel({
    this.id,
    required this.idVente,
    required this.idSegment,
    required this.pointDepart,
    required this.pointArrivee,
    required this.typeTarif,
    required this.quantite,
    required this.prixUnitaire,
    required this.montantTotal,
    required this.dateHeure,
    required this.matriculeAgent,
    this.statutSync = 'pending',
    this.idServeur,
    this.tentatives = 0,
    this.erreur,
  });

  factory TicketModel.fromMap(
    Map<
      String,
      dynamic
    >
    map,
  ) {
    return TicketModel(
      id:
          map['id']
              as int?,
      idVente:
          map['id_voyage']
              as int,
      idSegment:
          map['id_segment']
              as int? ??
          0,
      pointDepart:
          map['point_depart']
              as String,
      pointArrivee:
          map['point_arrivee']
              as String,
      typeTarif:
          map['type_tarif']
              as String,
      quantite:
          (map['quantite']
                  as num)
              .toInt(),
      prixUnitaire:
          (map['prix_unitaire']
                  as num)
              .toDouble(),
      montantTotal:
          (map['montant_total']
                  as num)
              .toDouble(),
      dateHeure:
          map['date_heure']
              as String,
      matriculeAgent:
          map['matricule_agent']
              as int,
      statutSync:
          map['statut_sync']
              as String? ??
          'pending',
      idServeur:
          map['id_serveur']
              as int?,
      tentatives:
          map['tentatives']
              as int? ??
          0,
      erreur:
          map['erreur']
              as String?,
    );
  }

  Map<
    String,
    dynamic
  >
  toMap() {
    return {
      if (id !=
          null)
        'id': id,
      'id_voyage': idVente,
      'id_segment': idSegment,
      'point_depart': pointDepart,
      'point_arrivee': pointArrivee,
      'type_tarif': typeTarif,
      'quantite': quantite,
      'prix_unitaire': prixUnitaire,
      'montant_total': montantTotal,
      'date_heure': dateHeure,
      'matricule_agent': matriculeAgent,
      'statut_sync': statutSync,
      if (idServeur !=
          null)
        'id_serveur': idServeur,
      'tentatives': tentatives,
      if (erreur !=
          null)
        'erreur': erreur,
    };
  }

  bool get isPending =>
      statutSync ==
      'pending';
  bool get isSynced =>
      statutSync ==
      'synced';
  bool get isFailed =>
      statutSync ==
      'failed';

  @override
  String toString() =>
      'TicketModel(id=$id, vente=$idVente, $pointDepart→$pointArrivee, '
      'total=$montantTotal, sync=$statutSync)';
}
