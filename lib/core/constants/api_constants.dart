class ApiConstants {
  ApiConstants._();

  static const String baseUrl     = 'http://192.168.1.19:8000';
  static const String billetterie = '$baseUrl/billetterie';

  // ── Web backend (Node.js)
  static const String webBaseUrl     = 'http://192.168.1.19:5000';
  static const String agentHeartbeat = '$webBaseUrl/api/sync/heartbeat';

  // ── Tickets
  static const String vendreTicket = '$billetterie/tickets/vendre';
  static const String logScan      = '$billetterie/scan/log';


  // ── NFC Cards
  static const String nfcRegister  = '$billetterie/nfc/register';
  static const String nfcCards     = '$billetterie/nfc/cards';
  static String nfcLookup(String uid) => '$billetterie/nfc/lookup/$uid';

  // ── Voyages
  static const String voyagesProgrammesBase    = '$billetterie/ventes/programmees';
  static const String voyagesNonProgrammesBase = '$billetterie/ventes/agent';

  static String voyagesProgrammes(int matricule)    => '$voyagesProgrammesBase/$matricule';
  static String voyagesNonProgrammes(int matricule) => '$voyagesNonProgrammesBase/$matricule';

  // ── Clôture / Réouverture
  static const String clotureJournee = '$billetterie/ventes/cloturer-journee';
  static const String reopenJournee  = '$billetterie/ventes/reopen-journee';

  static String cloturerVoyage(int idVente) => '$billetterie/vente/$idVente/cloturer';
  static String reopenVoyage(int idVente)   => '$billetterie/vente/$idVente/reopen';

  // ── Segments
  static String voyageSegments(int idVente)                 => '$billetterie/voyages/$idVente/segments';
  static String ouvrirSegment(int idVente)                  => '$billetterie/voyages/$idVente/segment/ouvrir';
  static String cloturerSegment(int idVente, int idSegment) => '$billetterie/voyages/$idVente/segments/$idSegment/cloturer';

  // ── Timeouts
  static const Duration defaultTimeout = Duration(seconds: 6);
  static const Duration actionTimeout  = Duration(seconds: 10);
  static const Duration reopenTimeout  = Duration(seconds: 8);
}