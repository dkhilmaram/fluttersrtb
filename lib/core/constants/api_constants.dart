class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://172.24.114.63:8000';
  static const String billetterie = '$baseUrl/billetterie';

  // ── Tickets ──
  static const String vendreTicket = '$billetterie/tickets/vendre';

  // ── Voyages ──
  static const String voyagesProgrammesBase = '$billetterie/ventes/programmees';
  static const String voyagesNonProgrammesBase = '$billetterie/ventes/agent';

  static String voyagesProgrammes(
    int matricule,
  ) => '$voyagesProgrammesBase/$matricule';
  static String voyagesNonProgrammes(
    int matricule,
  ) => '$voyagesNonProgrammesBase/$matricule';

  // ── Clôture / Réouverture ──
  static const String clotureJournee = '$billetterie/ventes/cloturer-journee';
  static const String reopenJournee = '$billetterie/ventes/reopen-journee';

  static String cloturerVoyage(
    int idVente,
  ) => '$billetterie/vente/$idVente/cloturer';
  static String reopenVoyage(
    int idVente,
  ) => '$billetterie/vente/$idVente/reopen';

  // ── Segments ──
  static String voyageSegments(
    int idVente,
  ) => '$billetterie/voyages/$idVente/segments';
  static String ouvrirSegment(
    int idVente,
  ) => '$billetterie/voyages/$idVente/segment/ouvrir';
  static String cloturerSegment(
    int idVente,
    int idSegment,
  ) => '$billetterie/voyages/$idVente/segments/$idSegment/cloturer';

  // ── Timeouts ──
  static const Duration defaultTimeout = Duration(
    seconds: 6,
  );
  static const Duration actionTimeout = Duration(
    seconds: 10,
  );
  static const Duration reopenTimeout = Duration(
    seconds: 8,
  );
}
