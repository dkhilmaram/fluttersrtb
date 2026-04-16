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
      'Connectez-vous une fois avec internet\npour activer le mode hors-ligne';

  @override
  String bienvenue(String prenom, String nom) {
    return 'Bienvenue $prenom $nom !';
  }

  @override
  String bienvenueOffline(String prenom) {
    return 'Hors-ligne — Bienvenue $prenom !';
  }

  @override
  String get loginError => 'Matricule ou mot de passe incorrect';

  @override
  String get matriculeInvalid => 'Matricule invalide';

  @override
  String get offlineNoAccount => 'Hors-ligne — aucun compte local trouvé';

  @override
  String get srtbFullName => 'Société Régionale des Transports de Bizerte';

  @override
  String get mesVoyages => 'Mes Voyages';

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
  String get cloturerJournee => 'Clôture Journée';

  @override
  String get cloturerJourneeQuestion => 'Clôturer toute la journée ?';

  @override
  String get annuler => 'Annuler';

  @override
  String get confirmer => 'Confirmer';

  @override
  String get reouvrirJournee => 'Réouvrir la Journée';

  @override
  String get exporterRapport => 'Exporter & Envoyer le rapport';

  @override
  String get statutCloture => 'Clôturé';

  @override
  String get statutEnAttente => 'En attente';

  @override
  String get statutActif => 'Actif';

  @override
  String get horsLignePasDeDonnees => 'Hors-ligne — pas de données disponibles';

  @override
  String get modeHorsLigne => 'Mode hors-ligne';

  @override
  String get tousDejaClotureToast => 'Tous les voyages sont déjà clôturés';

  @override
  String get echecCloture => 'Échec de la clôture';

  @override
  String get aucunAReouvrirToast => 'Aucun voyage clôturé à réouvrir';

  @override
  String get reouvertureEnCours => 'Réouverture en cours…';

  @override
  String get echecReouverture => 'Échec de la réouverture';

  @override
  String get voyageReouvertOffline => 'Voyage réouvert (hors-ligne)';

  @override
  String get voyageReouvert => 'Voyage réouvert avec succès';

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
  String get appuyerReouvrirLabel => 'Appuyer pour réouvrir';

  @override
  String get enAttenteVoyagePrecedent => 'En attente du voyage précédent';

  @override
  String get reessayer => 'Réessayer';

  @override
  String get envoyerRapport => 'Envoyer le rapport';

  @override
  String get reouvrirJourneeQuestion => 'Réouvrir la journée ?';

  @override
  String get actionReversible => 'Cette action est réversible';

  @override
  String get reouvrirTout => 'Réouvrir tout';

  @override
  String get reouvrirCeVoyage => 'Réouvrir ce voyage ?';

  @override
  String get reouvrirVoyageBody =>
      'Le voyage sera remis en statut actif et vous pourrez à nouveau vendre des tickets.';

  @override
  String get rouvrir => 'Rouvrir';

  @override
  String journeeClotureOffline(int count) {
    return '$count voyage(s) clôturé(s) (hors-ligne)';
  }

  @override
  String journeeCloture(int count) {
    return '$count voyage(s) clôturé(s) avec succès';
  }

  @override
  String journeeReouverteOffline(int count) {
    return '$count voyage(s) réouvert(s) (hors-ligne)';
  }

  @override
  String journeeReouverte(int count) {
    return '$count voyage(s) réouvert(s) avec succès';
  }

  @override
  String erreurExport(String error) {
    return 'Erreur lors de l\'export : $error';
  }

  @override
  String voyagesConfirmBody(int count, String date) {
    return 'Vous êtes sur le point de clôturer $count voyage(s) pour le $date.';
  }

  @override
  String envoyerRapportBody(String date) {
    return 'Le rapport du $date sera envoyé par e-mail à :';
  }

  @override
  String reouvrirJourneeBody(int count, String date) {
    return 'Vous allez réouvrir $count voyage(s) clôturé(s) du $date.';
  }
}
