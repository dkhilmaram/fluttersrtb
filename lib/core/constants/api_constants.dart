class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://192.168.1.16:8000';
  static const String billetterie = '$baseUrl/billetterie';

  // ── Tickets ──
  static const String vendreTicket = '$billetterie/tickets/vendre';

  // ── Voyages ──
  static const String voyagesProgrammes   = '$billetterie/voyages/programmes';
  static const String voyagesNonProgrammes = '$billetterie/voyages/non-programmes';

  // ── Timeouts ──
  static const Duration defaultTimeout = Duration(seconds: 6);
}