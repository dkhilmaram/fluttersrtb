// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'SRTB';

  @override
  String get connexion => 'Connexion';

  @override
  String get matricule => 'Matricule';

  @override
  String get matriculeHint => 'Entrez votre matricule';

  @override
  String get matriculeError => 'Veuillez entrer votre matricule';

  @override
  String get motDePasse => 'Mot de passe';

  @override
  String get motDePasseHint => 'Entrez votre mot de passe';

  @override
  String get motDePasseError => 'Veuillez entrer votre mot de passe';

  @override
  String get seConnecter => 'Se connecter';

  @override
  String get offlineHint =>
      'Connectez-vous une fois en ligne\npour activer le mode hors ligne';

  @override
  String bienvenue(String prenom, String nom) {
    return 'Bienvenue $prenom $nom !';
  }

  @override
  String bienvenueOffline(String prenom) {
    return 'Hors ligne — Bienvenue $prenom !';
  }

  @override
  String get loginError => 'Matricule ou mot de passe incorrect';

  @override
  String get matriculeInvalid => 'Matricule invalide';

  @override
  String get offlineNoAccount => 'Hors ligne — Aucun compte local trouvé';

  @override
  String get srtbFullName => 'Société Régionale de Transport de Bizerte';

  @override
  String get mesVoyages => 'Mes voyages';

  @override
  String get programmes => 'Programmés';

  @override
  String get nonProgrammes => 'Non programmés';

  @override
  String get total => 'Total';

  @override
  String get clotures => 'Clôturés';

  @override
  String get enCours => 'En cours';

  @override
  String get actifs => 'Actifs';

  @override
  String get aucunVoyageProgramme => 'Aucun voyage programmé';

  @override
  String get aucunVoyageNonProgramme => 'Aucun voyage non programmé';

  @override
  String get cloturerJournee => 'Clôturer la journée';

  @override
  String get cloturerJourneeQuestion =>
      'Souhaitez-vous clôturer toute la journée ?';

  @override
  String get annuler => 'Annuler';

  @override
  String get confirmer => 'Confirmer';

  @override
  String get reouvrirJournee => 'Rouvrir la journée';

  @override
  String get exporterRapport => 'Exporter et envoyer le rapport';

  @override
  String get statutCloture => 'Clôturé';

  @override
  String get statutEnAttente => 'En attente';

  @override
  String get statutActif => 'Actif';

  @override
  String get horsLignePasDeDonnees => 'Hors ligne — Aucune donnée disponible';

  @override
  String get modeHorsLigne => 'Mode hors ligne';

  @override
  String get tousDejaClotureToast => 'Tous les voyages sont déjà clôturés';

  @override
  String get echecCloture => 'Échec de la clôture';

  @override
  String get aucunAReouvrirToast => 'Aucun voyage clôturé à rouvrir';

  @override
  String get reouvertureEnCours => 'Réouverture en cours…';

  @override
  String get echecReouverture => 'Échec de la réouverture';

  @override
  String get voyageReouvertOffline => 'Voyage rouvert (hors ligne)';

  @override
  String get voyageReouvert => 'Voyage rouvert avec succès';

  @override
  String get generationExcel => 'Génération du fichier Excel…';

  @override
  String get generationPdf => 'Génération du fichier PDF…';

  @override
  String get rapportEnvoye => 'Rapport envoyé avec succès';

  @override
  String get terminerVoyageEnCoursToast =>
      'Terminez le voyage en cours avant de continuer';

  @override
  String get cloturureEnCours => 'Clôture en cours…';

  @override
  String get envoiEnCours => 'Envoi en cours…';

  @override
  String get appuyerReouvrirLabel => 'Appuyer pour rouvrir';

  @override
  String get enAttenteVoyagePrecedent => 'En attente du voyage précédent';

  @override
  String get reessayer => 'Réessayer';

  @override
  String get envoyerRapport => 'Envoyer le rapport';

  @override
  String get reouvrirJourneeQuestion => 'Souhaitez-vous rouvrir la journée ?';

  @override
  String get actionReversible => 'Cette action est réversible';

  @override
  String get reouvrirTout => 'Rouvrir tout';

  @override
  String get reouvrirCeVoyage => 'Souhaitez-vous rouvrir ce voyage ?';

  @override
  String get reouvrirVoyageBody =>
      'Le voyage reviendra à l\'état actif et vous pourrez à nouveau vendre des tickets.';

  @override
  String get rouvrir => 'Rouvrir';

  @override
  String journeeClotureOffline(int count) {
    return '$count voyage(s) clôturé(s) (hors ligne)';
  }

  @override
  String journeeCloture(int count) {
    return '$count voyage(s) clôturé(s) avec succès';
  }

  @override
  String journeeReouverteOffline(int count) {
    return '$count voyage(s) rouvert(s) (hors ligne)';
  }

  @override
  String journeeReouverte(int count) {
    return '$count voyage(s) rouvert(s) avec succès';
  }

  @override
  String erreurExport(String error) {
    return 'Erreur lors de l\'export : $error';
  }

  @override
  String voyagesConfirmBody(int count, String date) {
    return 'Vous êtes sur le point de clôturer $count voyage(s) du $date.';
  }

  @override
  String envoyerRapportBody(String date) {
    return 'Le rapport du $date sera envoyé par e-mail à :';
  }

  @override
  String reouvrirJourneeBody(int count, String date) {
    return 'Vous allez rouvrir $count voyage(s) clôturé(s) du $date.';
  }

  @override
  String get venteEtHistorique => 'Vente & Historique';

  @override
  String get billetterie => 'Billetterie';

  @override
  String get historique => 'Historique';

  @override
  String get journauxSync => 'Journaux de sync';

  @override
  String journauxSyncEnAttente(int count) {
    return 'Journaux de sync · $count en attente';
  }

  @override
  String get clotureVoyage => 'Clôture du voyage';

  @override
  String get actif => 'Actif';

  @override
  String get srtbLetters => 'S R T B';

  @override
  String get horsLignePasDeCacheErreur =>
      'Hors ligne et pas de cache. Veuillez vous connecter à Internet.';

  @override
  String get horsLigneDonneesCache =>
      'Données chargées depuis le cache (hors ligne)';

  @override
  String get horsLigneSynchronise =>
      'Ce ticket sera synchronisé lors du retour en ligne.';

  @override
  String get horsLigneActionsSync =>
      'Les actions seront synchronisées lors du retour en ligne.';

  @override
  String get horsLigneTicketSauvegarde =>
      'Ticket enregistré localement (hors ligne)';

  @override
  String get typeDeTarif => 'Type de tarif';

  @override
  String get trajetLabel => 'Trajet';

  @override
  String get pointDeMontee => 'Point de montée';

  @override
  String get pointDeDescente => 'Point de descente';

  @override
  String get choisirArret => 'Choisir un arrêt';

  @override
  String get choisirDabordMontee => 'Choisir d\'abord la montée';

  @override
  String get aucunArretDisponible => 'Aucun arrêt disponible';

  @override
  String get nombreDeTickets => 'Nombre de tickets';

  @override
  String get confirmerTicket => 'Confirmer le ticket';

  @override
  String get monteeLabel => 'Montée';

  @override
  String get descenteLabel => 'Descente';

  @override
  String get tarifLabel => 'Tarif';

  @override
  String get quantiteLabel => 'Quantité';

  @override
  String get millimes => 'millimes';

  @override
  String get gratuit => 'Gratuit';

  @override
  String get qrCodeTicket => 'QR Code du ticket';

  @override
  String get ticketSingulier => 'ticket';

  @override
  String get ticketPluriel => 'tickets';

  @override
  String get valider => 'Valider';

  @override
  String get enregistrement => 'Enregistrement…';

  @override
  String get validerLeTicket => 'Valider le ticket';

  @override
  String validerTickets(int count) {
    return 'Valider $count tickets';
  }

  @override
  String get passageGratuit => 'Passage gratuit';

  @override
  String get ticketsVendusLabel => 'Tickets vendus';

  @override
  String get totalCollecte => 'Total collecté';

  @override
  String get idVoyageManquant => 'ID voyage manquant';

  @override
  String get inconnu => 'Inconnu';

  @override
  String ticketsVendusToast(int count, int montant) {
    return '$count ticket(s) vendu(s) — $montant millimes';
  }

  @override
  String passagesGratuitsEnregistres(int count) {
    return '$count passage(s) gratuit(s) enregistré(s)';
  }

  @override
  String ticketErreur(String message) {
    return 'Erreur : $message';
  }

  @override
  String pourcentageApplique(int pct) {
    return '−$pct% appliqué';
  }

  @override
  String get institutionAgence => 'Institution / Agence';

  @override
  String get typeSpecial => 'Type spécial';

  @override
  String get nombreDePersonnes => 'Nombre de personnes';

  @override
  String get personne => 'personne';

  @override
  String get personnes => 'personnes';

  @override
  String get enregistrerLePassage => 'Enregistrer le passage';

  @override
  String get enregistrementEnCours => 'Enregistrement...';

  @override
  String passagesSession(int count) {
    return '$count passage(s) enregistré(s) cette session';
  }

  @override
  String passagesToast(int count) {
    return '$count passage(s) enregistré(s)';
  }

  @override
  String get erreurInconnue => 'inconnue';

  @override
  String get passagesGratuitsSpeciaux => 'Passages Gratuits & Spéciaux';

  @override
  String resumePassage(int count, String typeTarif) {
    return '$count personne(s) · $typeTarif';
  }

  @override
  String erreurPassage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get categorieArmeeNationale => 'Armée nationale';

  @override
  String get categorieGardeNationale => 'Garde nationale';

  @override
  String get categoriePoliceNationale => 'Police nationale';

  @override
  String get categorieDouane => 'Douane';

  @override
  String get categorieMinistere => 'Ministère';

  @override
  String get categorieMunicipalite => 'Municipalité';

  @override
  String get categorieEtablissementScolaire => 'Établissement scolaire';

  @override
  String get categorieAutreInstitution => 'Autre institution';

  @override
  String get categorieAbonnement => 'Abonnement';

  @override
  String get categorieAgent => 'Agent';

  @override
  String get historiqueVoyage => 'Historique du voyage';

  @override
  String get tickets => 'Tickets';

  @override
  String get finance => 'Finance';

  @override
  String get liste => 'Liste';

  @override
  String get parSegment => 'Par segment';

  @override
  String get apercu => 'Aperçu';

  @override
  String get parTarif => 'Par tarif';

  @override
  String get bilan => 'Bilan';

  @override
  String get aucunTicketAujourdhui => 'Aucun ticket aujourd\'hui';

  @override
  String get ticketsAujourdhuiApparaitront =>
      'Les tickets d\'aujourd\'hui apparaîtront ici';

  @override
  String get aucunSegmentDisponible => 'Aucun segment disponible';

  @override
  String get segmentInfoIndisponible =>
      'Les informations de segment ne sont pas disponibles';

  @override
  String get aucunTarif => 'Aucun tarif';

  @override
  String get donneesApparaitrontIci => 'Les données apparaîtront ici';

  @override
  String get recetteTotale => 'Recette totale';

  @override
  String get ticketsVendus => 'Tickets vendus';

  @override
  String get aujourdhui => 'aujourd\'hui';

  @override
  String get prixMoyen => 'Prix moyen';

  @override
  String get ticketPayant => 'ticket payant';

  @override
  String get repartitionRecettes => 'Répartition des recettes';

  @override
  String get recetteParTarif => 'Recette par tarif';

  @override
  String get detailFinancierParTarif => 'Détail financier par tarif';

  @override
  String get recetteTotaleVoyage => 'Recette totale du voyage — aujourd\'hui';

  @override
  String equivalentDT(String dt) {
    return '≈ $dt DT';
  }

  @override
  String get ticketsPayants => 'Tickets payants';

  @override
  String get totalVoyageurs => 'Total voyageurs';

  @override
  String get prixMoyenPayants => 'Prix moyen (payants)';

  @override
  String get analyseGratuites => 'Analyse des gratuités';

  @override
  String get manqueAGagnerEstime => 'Manque à gagner estimé';

  @override
  String get tauxGratuite => 'Taux de gratuité';

  @override
  String get payants => 'Payants';

  @override
  String get typesTarifUtilises => 'Types de tarif utilisés';

  @override
  String segmentsPluralLabel(int count) {
    return '$count segment(s)';
  }

  @override
  String get recetteParSegment => 'Recette par segment';

  @override
  String segmentLePlusRentable(String seg) {
    return 'Segment le + rentable : seg. $seg';
  }

  @override
  String get nonClasse => 'Non classé';

  @override
  String get enAttenteSyncLabel => 'En attente';

  @override
  String get echecSyncLabel => 'Échec';

  @override
  String prixUnitaireParTicket(int prix) {
    return '$prix ms/ticket';
  }

  @override
  String segLabel(String seg) {
    return 'Segment $seg';
  }

  @override
  String ticketsAujourdhuiCount(int count) {
    return '$count ticket(s) aujourd\'hui';
  }

  @override
  String ticketsCountAvecSync(int count, int pending, int failed) {
    return '$count ticket(s) aujourd\'hui · $pending en attente · $failed échoué(s)';
  }

  @override
  String get horsLigneAucunTicketLocal =>
      'Hors-ligne — aucun ticket local aujourd\'hui';

  @override
  String horsLigneTicketsEnAttente(int count) {
    return 'Hors-ligne — $count ticket(s) en attente aujourd\'hui';
  }

  @override
  String horsLigneTicketsCache(int count) {
    return 'Hors-ligne — $count ticket(s) en cache (aujourd\'hui)';
  }

  @override
  String get idVoyageManquantError => 'ID du voyage manquant';

  @override
  String get msRecette => 'ms recette';

  @override
  String get prixUnitaireMs => 'prix unitaire (ms)';

  @override
  String get journauxSyncTitle => 'Journaux de synchronisation';

  @override
  String get reseauOperationnel => 'Réseau opérationnel';

  @override
  String requetesEnAttente(int count) {
    return '$count requête(s) en attente';
  }

  @override
  String get kpiOk => '200 OK';

  @override
  String get kpiErreur => '5xx Erreur';

  @override
  String get kpiEnFile => 'En file';

  @override
  String get kpiTauxReussite => 'Taux réussite';

  @override
  String syncResultat(int synced, int failed) {
    return '✓ $synced synchronisés   ✗ $failed échoués';
  }

  @override
  String get tabFileAttente => 'File d\'attente';

  @override
  String get tabRequetesHttp => 'Requêtes HTTP';

  @override
  String get tabConsole => 'Console';

  @override
  String get fileAttenteVide => 'File d\'attente vide';

  @override
  String get tousTicketsSynchronises => 'Tous les tickets sont synchronisés';

  @override
  String get aucuneRequete => 'Aucune requête enregistrée';

  @override
  String syncConsoleTitle(int count) {
    return 'sync_log — $count entrées';
  }

  @override
  String get aucunLogDisponible => 'Aucun log disponible';

  @override
  String ticketsLocaux(int count) {
    return 'Tickets locaux — $count entrées';
  }

  @override
  String get aucunTicketLocal => 'Aucun ticket local';

  @override
  String retryLabel(int count) {
    return '$count× retry';
  }

  @override
  String get statusSynced => 'synced';

  @override
  String get statusFailed => 'failed';

  @override
  String get statusPending => 'pending';

  @override
  String get finDuVoyage => 'Fin du Voyage';

  @override
  String get voyageEnCours => 'Voyage en cours';

  @override
  String get attentionTitre => 'Attention';

  @override
  String get clotureIrreversible => 'Cette action est irréversible';

  @override
  String get clotureAucuneVente =>
      'Aucune vente ne sera possible après clôture';

  @override
  String get clotureVoyageMarque => 'Le voyage sera marqué comme terminé';

  @override
  String get confirmerCloture => 'Confirmer la clôture';

  @override
  String get clotureEnCours => 'Clôture en cours...';

  @override
  String get voyageCloture => 'Voyage clôturé !';

  @override
  String get retourEnCours => 'Retour en cours...';

  @override
  String get erreurInattendue => 'Erreur inattendue';

  @override
  String get horsLigneCloturePending =>
      'Hors ligne — clôture enregistrée, sera envoyée à la reconnexion';

  @override
  String get scanReadMode => 'Mode de lecture';

  @override
  String get scanModeNfc => 'NFC';

  @override
  String get scanNfcSublabel => 'Approcher la carte';

  @override
  String get scanModeQr => 'Code-barres';

  @override
  String get scanQrSublabel => 'Scanner le QR / code';

  @override
  String get scanNfcUnavailable => 'NFC non disponible sur cet appareil';

  @override
  String get scanNfcApproach => 'Approchez votre carte de transport';

  @override
  String get scanNfcUnreadable => 'Carte NFC illisible ou invalide';

  @override
  String get scanNfcReadError => 'Erreur de lecture';

  @override
  String scanNfcError(String error) {
    return 'Erreur NFC : $error';
  }

  @override
  String get scanNfcSheetTitle => 'Approchez la carte NFC';

  @override
  String get scanNfcSheetSubtitle =>
      'Maintenez la carte contre\nle dos de votre téléphone';

  @override
  String get scanCameraTitle => 'Scanner le code-barres / QR';

  @override
  String get scanCameraHint => 'Centrez le code dans le cadre';

  @override
  String get scanUnknown => 'Inconnu';

  @override
  String get scanIncompleteData =>
      'Données du titre incomplètes (id, type ou expire manquant)';

  @override
  String scanCardNotFound(String cardId) {
    return 'Carte non reconnue\n$cardId';
  }

  @override
  String scanLookupError(String error) {
    return 'Erreur lors de la recherche : $error';
  }

  @override
  String get scanPrefix => 'Scan';

  @override
  String get scanValidatedToast => 'Titre validé et enregistré ✓';

  @override
  String scanSaveError(String error) {
    return 'Erreur : $error';
  }

  @override
  String scanSessionCount(int count) {
    return '$count titre(s) validé(s) cette session';
  }

  @override
  String get scanFieldSubscriptionType => 'Type d\'abonnement';

  @override
  String get scanFieldOrganisme => 'Organisme';

  @override
  String get scanFieldAuthorisedLine => 'Ligne autorisée';

  @override
  String get scanFieldExpiry => 'Expire le';

  @override
  String get scanFieldStatus => 'Statut';

  @override
  String get scanStatusExpired => 'Expiré';

  @override
  String get scanStatusValid => 'Valide';

  @override
  String get scanExpiredWarning =>
      'Ce titre est expiré et ne peut pas être validé.';

  @override
  String get scanSaving => 'Enregistrement...';

  @override
  String get scanBtnExpired => 'Titre expiré';

  @override
  String get scanBtnValidate => 'Valider & Enregistrer';

  @override
  String get scanIdleTitle => 'Prêt à scanner';

  @override
  String get scanIdleSubtitle =>
      'Choisissez NFC ou Code-barres\npour lancer la lecture';

  @override
  String get scanSearching => 'Recherche du titre…';

  @override
  String get scanInvalidTitle => 'Titre invalide';

  @override
  String get scanErrorSubtitle =>
      'Ce titre de transport ne peut pas être accepté.';
}
