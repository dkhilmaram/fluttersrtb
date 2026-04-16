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
  String get matriculeError => 'Veuillez saisir votre matricule';

  @override
  String get motDePasse => 'Mot de passe';

  @override
  String get motDePasseHint => 'Entrez votre mot de passe';

  @override
  String get motDePasseError => 'Veuillez saisir votre mot de passe';

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
  String get offlineNoAccount => 'Hors ligne — aucun compte local trouvé';

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
  String get cloturerJourneeQuestion => 'Clôturer toute la journée ?';

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
  String get horsLignePasDeDonnees => 'Hors ligne — aucune donnée disponible';

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
  String get reouvrirJourneeQuestion => 'Rouvrir la journée ?';

  @override
  String get actionReversible => 'Cette action est réversible';

  @override
  String get reouvrirTout => 'Tout rouvrir';

  @override
  String get reouvrirCeVoyage => 'Rouvrir ce voyage ?';

  @override
  String get reouvrirVoyageBody =>
      'Le voyage reviendra à l\'état actif et vous pourrez à nouveau vendre des billets.';

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
  String get venteEtHistorique => 'Ventes et historique';

  @override
  String get billetterie => 'Billetterie';

  @override
  String get historique => 'Historique';

  @override
  String get journauxSync => 'Journaux de synchronisation';

  @override
  String journauxSyncEnAttente(int count) {
    return 'Journaux sync · $count en attente';
  }

  @override
  String get clotureVoyage => 'Clôture du voyage';

  @override
  String get actif => 'Actif';

  @override
  String get srtbLetters => 'S R T B';

  @override
  String get horsLignePasDeCacheErreur =>
      'Hors ligne et aucun cache disponible. Veuillez vous connecter à Internet.';

  @override
  String get horsLigneDonneesCache =>
      'Données chargées depuis le cache (mode hors ligne)';

  @override
  String get horsLigneSynchronise =>
      'Ce billet sera synchronisé dès le retour en ligne.';

  @override
  String get horsLigneActionsSync =>
      'Les actions seront synchronisées à la reconnexion.';

  @override
  String get horsLigneTicketSauvegarde =>
      'Billet sauvegardé localement (hors ligne)';

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
  String get choisirDabordMontee => 'Choisissez d\'abord la montée';

  @override
  String get aucunArretDisponible => 'Aucun arrêt disponible';

  @override
  String get nombreDeTickets => 'Nombre de billets';

  @override
  String get confirmerTicket => 'Confirmer le billet';

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
  String get qrCodeTicket => 'QR CODE DU BILLET';

  @override
  String get ticketSingulier => 'billet';

  @override
  String get ticketPluriel => 'billets';

  @override
  String get valider => 'Valider';

  @override
  String get enregistrement => 'Enregistrement…';

  @override
  String get validerLeTicket => 'Valider le billet';

  @override
  String validerTickets(int count) {
    return 'Valider $count billets';
  }

  @override
  String get passageGratuit => 'Passage gratuit';

  @override
  String get ticketsVendusLabel => 'Billets vendus';

  @override
  String get totalCollecte => 'Total collecté';

  @override
  String get idVoyageManquant => 'Identifiant du voyage manquant';

  @override
  String get inconnu => 'inconnu';

  @override
  String ticketsVendusToast(int count, int montant) {
    return '$count billet(s) vendu(s) — $montant millimes';
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
}
