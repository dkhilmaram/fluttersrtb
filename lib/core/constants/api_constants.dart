class ApiConstants {
  ApiConstants._();

  static const String baseUrl     = 'http://192.168.1.16:8000';
  static const String billetterie = '$baseUrl/billetterie';

  // ── Tickets ──
  static const String vendreTicket = '$billetterie/tickets/vendre';

  // ── Voyages ──
  static const String voyagesProgrammes    = '$billetterie/voyages/programmes';
  static const String voyagesNonProgrammes = '$billetterie/voyages/non-programmes';

  // ── Sync ──
  static String voyageSegments(int idVente) =>
      '$billetterie/voyages/$idVente/segments';
  static String ouvrirSegment(int idVente) =>
      '$billetterie/voyages/$idVente/segment/ouvrir';
  static String cloturerSegment(int idVente, int idSegment) =>
      '$billetterie/voyages/$idVente/segments/$idSegment/cloturer';
  static String cloturerVoyage(int idVente) =>
      '$billetterie/vente/$idVente/cloturer';

  // ── Timeouts ──
  static const Duration defaultTimeout = Duration(seconds: 6);
}