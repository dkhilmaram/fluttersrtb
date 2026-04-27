import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'SRTB'**
  String get appTitle;

  /// No description provided for @connexion.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get connexion;

  /// No description provided for @matricule.
  ///
  /// In fr, this message translates to:
  /// **'Matricule'**
  String get matricule;

  /// No description provided for @matriculeHint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre matricule'**
  String get matriculeHint;

  /// No description provided for @matriculeError.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre matricule'**
  String get matriculeError;

  /// No description provided for @motDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get motDePasse;

  /// No description provided for @motDePasseHint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre mot de passe'**
  String get motDePasseHint;

  /// No description provided for @motDePasseError.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre mot de passe'**
  String get motDePasseError;

  /// No description provided for @seConnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get seConnecter;

  /// No description provided for @offlineHint.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous une fois en ligne\npour activer le mode hors ligne'**
  String get offlineHint;

  /// No description provided for @bienvenue.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue {prenom} {nom} !'**
  String bienvenue(String prenom, String nom);

  /// No description provided for @bienvenueOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — Bienvenue {prenom} !'**
  String bienvenueOffline(String prenom);

  /// No description provided for @loginError.
  ///
  /// In fr, this message translates to:
  /// **'Matricule ou mot de passe incorrect'**
  String get loginError;

  /// No description provided for @matriculeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Matricule invalide'**
  String get matriculeInvalid;

  /// No description provided for @offlineNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — Aucun compte local trouvé'**
  String get offlineNoAccount;

  /// No description provided for @srtbFullName.
  ///
  /// In fr, this message translates to:
  /// **'Société Régionale de Transport de Bizerte'**
  String get srtbFullName;

  /// No description provided for @mesVoyages.
  ///
  /// In fr, this message translates to:
  /// **'Mes voyages'**
  String get mesVoyages;

  /// No description provided for @programmes.
  ///
  /// In fr, this message translates to:
  /// **'Programmés'**
  String get programmes;

  /// No description provided for @nonProgrammes.
  ///
  /// In fr, this message translates to:
  /// **'Non programmés'**
  String get nonProgrammes;

  /// No description provided for @total.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @clotures.
  ///
  /// In fr, this message translates to:
  /// **'Clôturés'**
  String get clotures;

  /// No description provided for @enCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get enCours;

  /// No description provided for @actifs.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get actifs;

  /// No description provided for @aucunVoyageProgramme.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyage programmé'**
  String get aucunVoyageProgramme;

  /// No description provided for @aucunVoyageNonProgramme.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyage non programmé'**
  String get aucunVoyageNonProgramme;

  /// No description provided for @cloturerJournee.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la journée'**
  String get cloturerJournee;

  /// No description provided for @cloturerJourneeQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous clôturer toute la journée ?'**
  String get cloturerJourneeQuestion;

  /// No description provided for @annuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get annuler;

  /// No description provided for @confirmer.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirmer;

  /// No description provided for @reouvrirJournee.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir la journée'**
  String get reouvrirJournee;

  /// No description provided for @exporterRapport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter et envoyer le rapport'**
  String get exporterRapport;

  /// No description provided for @statutCloture.
  ///
  /// In fr, this message translates to:
  /// **'Clôturé'**
  String get statutCloture;

  /// No description provided for @statutEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statutEnAttente;

  /// No description provided for @statutActif.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get statutActif;

  /// No description provided for @horsLignePasDeDonnees.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — Aucune donnée disponible'**
  String get horsLignePasDeDonnees;

  /// No description provided for @modeHorsLigne.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne'**
  String get modeHorsLigne;

  /// No description provided for @tousDejaClotureToast.
  ///
  /// In fr, this message translates to:
  /// **'Tous les voyages sont déjà clôturés'**
  String get tousDejaClotureToast;

  /// No description provided for @echecCloture.
  ///
  /// In fr, this message translates to:
  /// **'Échec de la clôture'**
  String get echecCloture;

  /// No description provided for @aucunAReouvrirToast.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyage clôturé à rouvrir'**
  String get aucunAReouvrirToast;

  /// No description provided for @reouvertureEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Réouverture en cours…'**
  String get reouvertureEnCours;

  /// No description provided for @echecReouverture.
  ///
  /// In fr, this message translates to:
  /// **'Échec de la réouverture'**
  String get echecReouverture;

  /// No description provided for @voyageReouvertOffline.
  ///
  /// In fr, this message translates to:
  /// **'Voyage rouvert (hors ligne)'**
  String get voyageReouvertOffline;

  /// No description provided for @voyageReouvert.
  ///
  /// In fr, this message translates to:
  /// **'Voyage rouvert avec succès'**
  String get voyageReouvert;

  /// No description provided for @generationExcel.
  ///
  /// In fr, this message translates to:
  /// **'Génération du fichier Excel…'**
  String get generationExcel;

  /// No description provided for @generationPdf.
  ///
  /// In fr, this message translates to:
  /// **'Génération du fichier PDF…'**
  String get generationPdf;

  /// No description provided for @rapportEnvoye.
  ///
  /// In fr, this message translates to:
  /// **'Rapport envoyé avec succès'**
  String get rapportEnvoye;

  /// No description provided for @terminerVoyageEnCoursToast.
  ///
  /// In fr, this message translates to:
  /// **'Terminez le voyage en cours avant de continuer'**
  String get terminerVoyageEnCoursToast;

  /// No description provided for @cloturureEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Clôture en cours…'**
  String get cloturureEnCours;

  /// No description provided for @envoiEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours…'**
  String get envoiEnCours;

  /// No description provided for @appuyerReouvrirLabel.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour rouvrir'**
  String get appuyerReouvrirLabel;

  /// No description provided for @enAttenteVoyagePrecedent.
  ///
  /// In fr, this message translates to:
  /// **'En attente du voyage précédent'**
  String get enAttenteVoyagePrecedent;

  /// No description provided for @reessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get reessayer;

  /// No description provided for @envoyerRapport.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le rapport'**
  String get envoyerRapport;

  /// No description provided for @reouvrirJourneeQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous rouvrir la journée ?'**
  String get reouvrirJourneeQuestion;

  /// No description provided for @actionReversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est réversible'**
  String get actionReversible;

  /// No description provided for @reouvrirTout.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir tout'**
  String get reouvrirTout;

  /// No description provided for @reouvrirCeVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous rouvrir ce voyage ?'**
  String get reouvrirCeVoyage;

  /// No description provided for @reouvrirVoyageBody.
  ///
  /// In fr, this message translates to:
  /// **'Le voyage reviendra à l\'état actif et vous pourrez à nouveau vendre des tickets.'**
  String get reouvrirVoyageBody;

  /// No description provided for @rouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir'**
  String get rouvrir;

  /// No description provided for @journeeClotureOffline.
  ///
  /// In fr, this message translates to:
  /// **'{count} voyage(s) clôturé(s) (hors ligne)'**
  String journeeClotureOffline(int count);

  /// No description provided for @journeeCloture.
  ///
  /// In fr, this message translates to:
  /// **'{count} voyage(s) clôturé(s) avec succès'**
  String journeeCloture(int count);

  /// No description provided for @journeeReouverteOffline.
  ///
  /// In fr, this message translates to:
  /// **'{count} voyage(s) rouvert(s) (hors ligne)'**
  String journeeReouverteOffline(int count);

  /// No description provided for @journeeReouverte.
  ///
  /// In fr, this message translates to:
  /// **'{count} voyage(s) rouvert(s) avec succès'**
  String journeeReouverte(int count);

  /// No description provided for @erreurExport.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'export : {error}'**
  String erreurExport(String error);

  /// No description provided for @voyagesConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes sur le point de clôturer {count} voyage(s) du {date}.'**
  String voyagesConfirmBody(int count, String date);

  /// No description provided for @envoyerRapportBody.
  ///
  /// In fr, this message translates to:
  /// **'Le rapport du {date} sera envoyé par e-mail à :'**
  String envoyerRapportBody(String date);

  /// No description provided for @reouvrirJourneeBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez rouvrir {count} voyage(s) clôturé(s) du {date}.'**
  String reouvrirJourneeBody(int count, String date);

  /// No description provided for @venteEtHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Vente & Historique'**
  String get venteEtHistorique;

  /// No description provided for @billetterie.
  ///
  /// In fr, this message translates to:
  /// **'Billetterie'**
  String get billetterie;

  /// No description provided for @historique.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historique;

  /// No description provided for @journauxSync.
  ///
  /// In fr, this message translates to:
  /// **'Journaux de sync'**
  String get journauxSync;

  /// No description provided for @journauxSyncEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'Journaux de sync · {count} en attente'**
  String journauxSyncEnAttente(int count);

  /// No description provided for @clotureVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Clôture du voyage'**
  String get clotureVoyage;

  /// No description provided for @actif.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get actif;

  /// No description provided for @srtbLetters.
  ///
  /// In fr, this message translates to:
  /// **'S R T B'**
  String get srtbLetters;

  /// No description provided for @horsLignePasDeCacheErreur.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne et pas de cache. Veuillez vous connecter à Internet.'**
  String get horsLignePasDeCacheErreur;

  /// No description provided for @horsLigneDonneesCache.
  ///
  /// In fr, this message translates to:
  /// **'Données chargées depuis le cache (hors ligne)'**
  String get horsLigneDonneesCache;

  /// No description provided for @horsLigneSynchronise.
  ///
  /// In fr, this message translates to:
  /// **'Ce ticket sera synchronisé lors du retour en ligne.'**
  String get horsLigneSynchronise;

  /// No description provided for @horsLigneActionsSync.
  ///
  /// In fr, this message translates to:
  /// **'Les actions seront synchronisées lors du retour en ligne.'**
  String get horsLigneActionsSync;

  /// No description provided for @horsLigneTicketSauvegarde.
  ///
  /// In fr, this message translates to:
  /// **'Ticket enregistré localement (hors ligne)'**
  String get horsLigneTicketSauvegarde;

  /// No description provided for @typeDeTarif.
  ///
  /// In fr, this message translates to:
  /// **'Type de tarif'**
  String get typeDeTarif;

  /// No description provided for @trajetLabel.
  ///
  /// In fr, this message translates to:
  /// **'Trajet'**
  String get trajetLabel;

  /// No description provided for @pointDeMontee.
  ///
  /// In fr, this message translates to:
  /// **'Point de montée'**
  String get pointDeMontee;

  /// No description provided for @pointDeDescente.
  ///
  /// In fr, this message translates to:
  /// **'Point de descente'**
  String get pointDeDescente;

  /// No description provided for @choisirArret.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un arrêt'**
  String get choisirArret;

  /// No description provided for @choisirDabordMontee.
  ///
  /// In fr, this message translates to:
  /// **'Choisir d\'abord la montée'**
  String get choisirDabordMontee;

  /// No description provided for @aucunArretDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Aucun arrêt disponible'**
  String get aucunArretDisponible;

  /// No description provided for @nombreDeTickets.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de tickets'**
  String get nombreDeTickets;

  /// No description provided for @confirmerTicket.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le ticket'**
  String get confirmerTicket;

  /// No description provided for @monteeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montée'**
  String get monteeLabel;

  /// No description provided for @descenteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Descente'**
  String get descenteLabel;

  /// No description provided for @tarifLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tarif'**
  String get tarifLabel;

  /// No description provided for @quantiteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get quantiteLabel;

  /// No description provided for @millimes.
  ///
  /// In fr, this message translates to:
  /// **'millimes'**
  String get millimes;

  /// No description provided for @gratuit.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit'**
  String get gratuit;

  /// No description provided for @qrCodeTicket.
  ///
  /// In fr, this message translates to:
  /// **'QR Code du ticket'**
  String get qrCodeTicket;

  /// No description provided for @ticketSingulier.
  ///
  /// In fr, this message translates to:
  /// **'ticket'**
  String get ticketSingulier;

  /// No description provided for @ticketPluriel.
  ///
  /// In fr, this message translates to:
  /// **'tickets'**
  String get ticketPluriel;

  /// No description provided for @valider.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get valider;

  /// No description provided for @enregistrement.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get enregistrement;

  /// No description provided for @validerLeTicket.
  ///
  /// In fr, this message translates to:
  /// **'Valider le ticket'**
  String get validerLeTicket;

  /// No description provided for @validerTickets.
  ///
  /// In fr, this message translates to:
  /// **'Valider {count} tickets'**
  String validerTickets(int count);

  /// No description provided for @passageGratuit.
  ///
  /// In fr, this message translates to:
  /// **'Passage gratuit'**
  String get passageGratuit;

  /// No description provided for @ticketsVendusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tickets vendus'**
  String get ticketsVendusLabel;

  /// No description provided for @totalCollecte.
  ///
  /// In fr, this message translates to:
  /// **'Total collecté'**
  String get totalCollecte;

  /// No description provided for @idVoyageManquant.
  ///
  /// In fr, this message translates to:
  /// **'ID voyage manquant'**
  String get idVoyageManquant;

  /// No description provided for @inconnu.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get inconnu;

  /// No description provided for @ticketsVendusToast.
  ///
  /// In fr, this message translates to:
  /// **'{count} ticket(s) vendu(s) — {montant} millimes'**
  String ticketsVendusToast(int count, int montant);

  /// No description provided for @passagesGratuitsEnregistres.
  ///
  /// In fr, this message translates to:
  /// **'{count} passage(s) gratuit(s) enregistré(s)'**
  String passagesGratuitsEnregistres(int count);

  /// No description provided for @ticketErreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String ticketErreur(String message);

  /// No description provided for @pourcentageApplique.
  ///
  /// In fr, this message translates to:
  /// **'−{pct}% appliqué'**
  String pourcentageApplique(int pct);

  /// No description provided for @institutionAgence.
  ///
  /// In fr, this message translates to:
  /// **'Institution / Agence'**
  String get institutionAgence;

  /// No description provided for @typeSpecial.
  ///
  /// In fr, this message translates to:
  /// **'Type spécial'**
  String get typeSpecial;

  /// No description provided for @nombreDePersonnes.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de personnes'**
  String get nombreDePersonnes;

  /// No description provided for @personne.
  ///
  /// In fr, this message translates to:
  /// **'personne'**
  String get personne;

  /// No description provided for @personnes.
  ///
  /// In fr, this message translates to:
  /// **'personnes'**
  String get personnes;

  /// No description provided for @enregistrerLePassage.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le passage'**
  String get enregistrerLePassage;

  /// No description provided for @enregistrementEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get enregistrementEnCours;

  /// No description provided for @passagesSession.
  ///
  /// In fr, this message translates to:
  /// **'{count} passage(s) enregistré(s) cette session'**
  String passagesSession(int count);

  /// No description provided for @passagesToast.
  ///
  /// In fr, this message translates to:
  /// **'{count} passage(s) enregistré(s)'**
  String passagesToast(int count);

  /// No description provided for @erreurInconnue.
  ///
  /// In fr, this message translates to:
  /// **'inconnue'**
  String get erreurInconnue;

  /// No description provided for @passagesGratuitsSpeciaux.
  ///
  /// In fr, this message translates to:
  /// **'Passages Gratuits & Spéciaux'**
  String get passagesGratuitsSpeciaux;

  /// No description provided for @resumePassage.
  ///
  /// In fr, this message translates to:
  /// **'{count} personne(s) · {typeTarif}'**
  String resumePassage(int count, String typeTarif);

  /// No description provided for @erreurPassage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String erreurPassage(String message);

  /// No description provided for @categorieArmeeNationale.
  ///
  /// In fr, this message translates to:
  /// **'Armée nationale'**
  String get categorieArmeeNationale;

  /// No description provided for @categorieGardeNationale.
  ///
  /// In fr, this message translates to:
  /// **'Garde nationale'**
  String get categorieGardeNationale;

  /// No description provided for @categoriePoliceNationale.
  ///
  /// In fr, this message translates to:
  /// **'Police nationale'**
  String get categoriePoliceNationale;

  /// No description provided for @categorieDouane.
  ///
  /// In fr, this message translates to:
  /// **'Douane'**
  String get categorieDouane;

  /// No description provided for @categorieMinistere.
  ///
  /// In fr, this message translates to:
  /// **'Ministère'**
  String get categorieMinistere;

  /// No description provided for @categorieMunicipalite.
  ///
  /// In fr, this message translates to:
  /// **'Municipalité'**
  String get categorieMunicipalite;

  /// No description provided for @categorieEtablissementScolaire.
  ///
  /// In fr, this message translates to:
  /// **'Établissement scolaire'**
  String get categorieEtablissementScolaire;

  /// No description provided for @categorieAutreInstitution.
  ///
  /// In fr, this message translates to:
  /// **'Autre institution'**
  String get categorieAutreInstitution;

  /// No description provided for @categorieAbonnement.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get categorieAbonnement;

  /// No description provided for @categorieAgent.
  ///
  /// In fr, this message translates to:
  /// **'Agent'**
  String get categorieAgent;

  /// No description provided for @historiqueVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Historique du voyage'**
  String get historiqueVoyage;

  /// No description provided for @tickets.
  ///
  /// In fr, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @finance.
  ///
  /// In fr, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @liste.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get liste;

  /// No description provided for @parSegment.
  ///
  /// In fr, this message translates to:
  /// **'Par segment'**
  String get parSegment;

  /// No description provided for @apercu.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get apercu;

  /// No description provided for @parTarif.
  ///
  /// In fr, this message translates to:
  /// **'Par tarif'**
  String get parTarif;

  /// No description provided for @bilan.
  ///
  /// In fr, this message translates to:
  /// **'Bilan'**
  String get bilan;

  /// No description provided for @aucunTicketAujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ticket aujourd\'hui'**
  String get aucunTicketAujourdhui;

  /// No description provided for @ticketsAujourdhuiApparaitront.
  ///
  /// In fr, this message translates to:
  /// **'Les tickets d\'aujourd\'hui apparaîtront ici'**
  String get ticketsAujourdhuiApparaitront;

  /// No description provided for @aucunSegmentDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Aucun segment disponible'**
  String get aucunSegmentDisponible;

  /// No description provided for @segmentInfoIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Les informations de segment ne sont pas disponibles'**
  String get segmentInfoIndisponible;

  /// No description provided for @aucunTarif.
  ///
  /// In fr, this message translates to:
  /// **'Aucun tarif'**
  String get aucunTarif;

  /// No description provided for @donneesApparaitrontIci.
  ///
  /// In fr, this message translates to:
  /// **'Les données apparaîtront ici'**
  String get donneesApparaitrontIci;

  /// No description provided for @recetteTotale.
  ///
  /// In fr, this message translates to:
  /// **'Recette totale'**
  String get recetteTotale;

  /// No description provided for @ticketsVendus.
  ///
  /// In fr, this message translates to:
  /// **'Tickets vendus'**
  String get ticketsVendus;

  /// No description provided for @aujourdhui.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get aujourdhui;

  /// No description provided for @prixMoyen.
  ///
  /// In fr, this message translates to:
  /// **'Prix moyen'**
  String get prixMoyen;

  /// No description provided for @ticketPayant.
  ///
  /// In fr, this message translates to:
  /// **'ticket payant'**
  String get ticketPayant;

  /// No description provided for @repartitionRecettes.
  ///
  /// In fr, this message translates to:
  /// **'Répartition des recettes'**
  String get repartitionRecettes;

  /// No description provided for @recetteParTarif.
  ///
  /// In fr, this message translates to:
  /// **'Recette par tarif'**
  String get recetteParTarif;

  /// No description provided for @detailFinancierParTarif.
  ///
  /// In fr, this message translates to:
  /// **'Détail financier par tarif'**
  String get detailFinancierParTarif;

  /// No description provided for @recetteTotaleVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Recette totale du voyage — aujourd\'hui'**
  String get recetteTotaleVoyage;

  /// No description provided for @equivalentDT.
  ///
  /// In fr, this message translates to:
  /// **'≈ {dt} DT'**
  String equivalentDT(String dt);

  /// No description provided for @ticketsPayants.
  ///
  /// In fr, this message translates to:
  /// **'Tickets payants'**
  String get ticketsPayants;

  /// No description provided for @totalVoyageurs.
  ///
  /// In fr, this message translates to:
  /// **'Total voyageurs'**
  String get totalVoyageurs;

  /// No description provided for @prixMoyenPayants.
  ///
  /// In fr, this message translates to:
  /// **'Prix moyen (payants)'**
  String get prixMoyenPayants;

  /// No description provided for @analyseGratuites.
  ///
  /// In fr, this message translates to:
  /// **'Analyse des gratuités'**
  String get analyseGratuites;

  /// No description provided for @manqueAGagnerEstime.
  ///
  /// In fr, this message translates to:
  /// **'Manque à gagner estimé'**
  String get manqueAGagnerEstime;

  /// No description provided for @tauxGratuite.
  ///
  /// In fr, this message translates to:
  /// **'Taux de gratuité'**
  String get tauxGratuite;

  /// No description provided for @payants.
  ///
  /// In fr, this message translates to:
  /// **'Payants'**
  String get payants;

  /// No description provided for @typesTarifUtilises.
  ///
  /// In fr, this message translates to:
  /// **'Types de tarif utilisés'**
  String get typesTarifUtilises;

  /// No description provided for @segmentsPluralLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} segment(s)'**
  String segmentsPluralLabel(int count);

  /// No description provided for @recetteParSegment.
  ///
  /// In fr, this message translates to:
  /// **'Recette par segment'**
  String get recetteParSegment;

  /// No description provided for @segmentLePlusRentable.
  ///
  /// In fr, this message translates to:
  /// **'Segment le + rentable : seg. {seg}'**
  String segmentLePlusRentable(String seg);

  /// No description provided for @nonClasse.
  ///
  /// In fr, this message translates to:
  /// **'Non classé'**
  String get nonClasse;

  /// No description provided for @enAttenteSyncLabel.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get enAttenteSyncLabel;

  /// No description provided for @echecSyncLabel.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get echecSyncLabel;

  /// No description provided for @prixUnitaireParTicket.
  ///
  /// In fr, this message translates to:
  /// **'{prix} ms/ticket'**
  String prixUnitaireParTicket(int prix);

  /// No description provided for @segLabel.
  ///
  /// In fr, this message translates to:
  /// **'Segment {seg}'**
  String segLabel(String seg);

  /// No description provided for @ticketsAujourdhuiCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} ticket(s) aujourd\'hui'**
  String ticketsAujourdhuiCount(int count);

  /// No description provided for @ticketsCountAvecSync.
  ///
  /// In fr, this message translates to:
  /// **'{count} ticket(s) aujourd\'hui · {pending} en attente · {failed} échoué(s)'**
  String ticketsCountAvecSync(int count, int pending, int failed);

  /// No description provided for @horsLigneAucunTicketLocal.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne — aucun ticket local aujourd\'hui'**
  String get horsLigneAucunTicketLocal;

  /// No description provided for @horsLigneTicketsEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne — {count} ticket(s) en attente aujourd\'hui'**
  String horsLigneTicketsEnAttente(int count);

  /// No description provided for @horsLigneTicketsCache.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne — {count} ticket(s) en cache (aujourd\'hui)'**
  String horsLigneTicketsCache(int count);

  /// No description provided for @idVoyageManquantError.
  ///
  /// In fr, this message translates to:
  /// **'ID du voyage manquant'**
  String get idVoyageManquantError;

  /// No description provided for @msRecette.
  ///
  /// In fr, this message translates to:
  /// **'ms recette'**
  String get msRecette;

  /// No description provided for @prixUnitaireMs.
  ///
  /// In fr, this message translates to:
  /// **'prix unitaire (ms)'**
  String get prixUnitaireMs;

  /// No description provided for @journauxSyncTitle.
  ///
  /// In fr, this message translates to:
  /// **'Journaux de synchronisation'**
  String get journauxSyncTitle;

  /// No description provided for @reseauOperationnel.
  ///
  /// In fr, this message translates to:
  /// **'Réseau opérationnel'**
  String get reseauOperationnel;

  /// No description provided for @requetesEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'{count} requête(s) en attente'**
  String requetesEnAttente(int count);

  /// No description provided for @kpiOk.
  ///
  /// In fr, this message translates to:
  /// **'200 OK'**
  String get kpiOk;

  /// No description provided for @kpiErreur.
  ///
  /// In fr, this message translates to:
  /// **'5xx Erreur'**
  String get kpiErreur;

  /// No description provided for @kpiEnFile.
  ///
  /// In fr, this message translates to:
  /// **'En file'**
  String get kpiEnFile;

  /// No description provided for @kpiTauxReussite.
  ///
  /// In fr, this message translates to:
  /// **'Taux réussite'**
  String get kpiTauxReussite;

  /// No description provided for @syncResultat.
  ///
  /// In fr, this message translates to:
  /// **'✓ {synced} synchronisés   ✗ {failed} échoués'**
  String syncResultat(int synced, int failed);

  /// No description provided for @tabFileAttente.
  ///
  /// In fr, this message translates to:
  /// **'File d\'attente'**
  String get tabFileAttente;

  /// No description provided for @tabRequetesHttp.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes HTTP'**
  String get tabRequetesHttp;

  /// No description provided for @tabConsole.
  ///
  /// In fr, this message translates to:
  /// **'Console'**
  String get tabConsole;

  /// No description provided for @fileAttenteVide.
  ///
  /// In fr, this message translates to:
  /// **'File d\'attente vide'**
  String get fileAttenteVide;

  /// No description provided for @tousTicketsSynchronises.
  ///
  /// In fr, this message translates to:
  /// **'Tous les tickets sont synchronisés'**
  String get tousTicketsSynchronises;

  /// No description provided for @aucuneRequete.
  ///
  /// In fr, this message translates to:
  /// **'Aucune requête enregistrée'**
  String get aucuneRequete;

  /// No description provided for @syncConsoleTitle.
  ///
  /// In fr, this message translates to:
  /// **'sync_log — {count} entrées'**
  String syncConsoleTitle(int count);

  /// No description provided for @aucunLogDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Aucun log disponible'**
  String get aucunLogDisponible;

  /// No description provided for @ticketsLocaux.
  ///
  /// In fr, this message translates to:
  /// **'Tickets locaux — {count} entrées'**
  String ticketsLocaux(int count);

  /// No description provided for @aucunTicketLocal.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ticket local'**
  String get aucunTicketLocal;

  /// No description provided for @retryLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count}× retry'**
  String retryLabel(int count);

  /// No description provided for @statusSynced.
  ///
  /// In fr, this message translates to:
  /// **'synced'**
  String get statusSynced;

  /// No description provided for @statusFailed.
  ///
  /// In fr, this message translates to:
  /// **'failed'**
  String get statusFailed;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'pending'**
  String get statusPending;

  /// No description provided for @finDuVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Fin du Voyage'**
  String get finDuVoyage;

  /// No description provided for @voyageEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Voyage en cours'**
  String get voyageEnCours;

  /// No description provided for @attentionTitre.
  ///
  /// In fr, this message translates to:
  /// **'Attention'**
  String get attentionTitre;

  /// No description provided for @clotureIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible'**
  String get clotureIrreversible;

  /// No description provided for @clotureAucuneVente.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente ne sera possible après clôture'**
  String get clotureAucuneVente;

  /// No description provided for @clotureVoyageMarque.
  ///
  /// In fr, this message translates to:
  /// **'Le voyage sera marqué comme terminé'**
  String get clotureVoyageMarque;

  /// No description provided for @confirmerCloture.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la clôture'**
  String get confirmerCloture;

  /// No description provided for @clotureEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Clôture en cours...'**
  String get clotureEnCours;

  /// No description provided for @voyageCloture.
  ///
  /// In fr, this message translates to:
  /// **'Voyage clôturé !'**
  String get voyageCloture;

  /// No description provided for @retourEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Retour en cours...'**
  String get retourEnCours;

  /// No description provided for @erreurInattendue.
  ///
  /// In fr, this message translates to:
  /// **'Erreur inattendue'**
  String get erreurInattendue;

  /// No description provided for @horsLigneCloturePending.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — clôture enregistrée, sera envoyée à la reconnexion'**
  String get horsLigneCloturePending;

  /// No description provided for @scanReadMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de lecture'**
  String get scanReadMode;

  /// No description provided for @scanModeNfc.
  ///
  /// In fr, this message translates to:
  /// **'NFC'**
  String get scanModeNfc;

  /// No description provided for @scanNfcSublabel.
  ///
  /// In fr, this message translates to:
  /// **'Approcher la carte'**
  String get scanNfcSublabel;

  /// No description provided for @scanModeQr.
  ///
  /// In fr, this message translates to:
  /// **'Code-barres'**
  String get scanModeQr;

  /// No description provided for @scanQrSublabel.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le QR / code'**
  String get scanQrSublabel;

  /// No description provided for @scanNfcUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'NFC non disponible sur cet appareil'**
  String get scanNfcUnavailable;

  /// No description provided for @scanNfcApproach.
  ///
  /// In fr, this message translates to:
  /// **'Approchez votre carte de transport'**
  String get scanNfcApproach;

  /// No description provided for @scanNfcUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Carte NFC illisible ou invalide'**
  String get scanNfcUnreadable;

  /// No description provided for @scanNfcReadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture'**
  String get scanNfcReadError;

  /// No description provided for @scanNfcError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur NFC : {error}'**
  String scanNfcError(String error);

  /// No description provided for @scanNfcSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Approchez la carte NFC'**
  String get scanNfcSheetTitle;

  /// No description provided for @scanNfcSheetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Maintenez la carte contre\nle dos de votre téléphone'**
  String get scanNfcSheetSubtitle;

  /// No description provided for @scanCameraTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le code-barres / QR'**
  String get scanCameraTitle;

  /// No description provided for @scanCameraHint.
  ///
  /// In fr, this message translates to:
  /// **'Centrez le code dans le cadre'**
  String get scanCameraHint;

  /// No description provided for @scanUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get scanUnknown;

  /// No description provided for @scanIncompleteData.
  ///
  /// In fr, this message translates to:
  /// **'Données du titre incomplètes (id, type ou expire manquant)'**
  String get scanIncompleteData;

  /// No description provided for @scanCardNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Carte non reconnue\n{cardId}'**
  String scanCardNotFound(String cardId);

  /// No description provided for @scanLookupError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la recherche : {error}'**
  String scanLookupError(String error);

  /// No description provided for @scanPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Scan'**
  String get scanPrefix;

  /// No description provided for @scanValidatedToast.
  ///
  /// In fr, this message translates to:
  /// **'Titre validé et enregistré ✓'**
  String get scanValidatedToast;

  /// No description provided for @scanSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String scanSaveError(String error);

  /// No description provided for @scanSessionCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} titre(s) validé(s) cette session'**
  String scanSessionCount(int count);

  /// No description provided for @scanFieldSubscriptionType.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'abonnement'**
  String get scanFieldSubscriptionType;

  /// No description provided for @scanFieldOrganisme.
  ///
  /// In fr, this message translates to:
  /// **'Organisme'**
  String get scanFieldOrganisme;

  /// No description provided for @scanFieldAuthorisedLine.
  ///
  /// In fr, this message translates to:
  /// **'Ligne autorisée'**
  String get scanFieldAuthorisedLine;

  /// No description provided for @scanFieldExpiry.
  ///
  /// In fr, this message translates to:
  /// **'Expire le'**
  String get scanFieldExpiry;

  /// No description provided for @scanFieldStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get scanFieldStatus;

  /// No description provided for @scanStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get scanStatusExpired;

  /// No description provided for @scanStatusValid.
  ///
  /// In fr, this message translates to:
  /// **'Valide'**
  String get scanStatusValid;

  /// No description provided for @scanExpiredWarning.
  ///
  /// In fr, this message translates to:
  /// **'Ce titre est expiré et ne peut pas être validé.'**
  String get scanExpiredWarning;

  /// No description provided for @scanSaving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get scanSaving;

  /// No description provided for @scanBtnExpired.
  ///
  /// In fr, this message translates to:
  /// **'Titre expiré'**
  String get scanBtnExpired;

  /// No description provided for @scanBtnValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider & Enregistrer'**
  String get scanBtnValidate;

  /// No description provided for @scanIdleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prêt à scanner'**
  String get scanIdleTitle;

  /// No description provided for @scanIdleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez NFC ou Code-barres\npour lancer la lecture'**
  String get scanIdleSubtitle;

  /// No description provided for @scanSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche du titre…'**
  String get scanSearching;

  /// No description provided for @scanInvalidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre invalide'**
  String get scanInvalidTitle;

  /// No description provided for @scanErrorSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce titre de transport ne peut pas être accepté.'**
  String get scanErrorSubtitle;

  /// No description provided for @scanTitreDetecte.
  ///
  /// In fr, this message translates to:
  /// **'Titre détecté'**
  String get scanTitreDetecte;

  /// No description provided for @scanAssignInstruction.
  ///
  /// In fr, this message translates to:
  /// **'Complétez les informations avant de valider'**
  String get scanAssignInstruction;

  /// No description provided for @scanAssignMissing.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner la ligne, le type et le trajet'**
  String get scanAssignMissing;

  /// No description provided for @scanFieldLigne.
  ///
  /// In fr, this message translates to:
  /// **'Ligne'**
  String get scanFieldLigne;

  /// No description provided for @scanFieldTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Trajet'**
  String get scanFieldTrajet;

  /// No description provided for @scanSelectLigne.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une ligne'**
  String get scanSelectLigne;

  /// No description provided for @scanSelectType.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un type'**
  String get scanSelectType;

  /// No description provided for @scanSelectTrajet.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un trajet'**
  String get scanSelectTrajet;

  /// No description provided for @scanValidatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre validé'**
  String get scanValidatedTitle;

  /// No description provided for @scanNextTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un autre titre'**
  String get scanNextTitle;

  /// No description provided for @scanNfcDetectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Carte NFC Détectée !'**
  String get scanNfcDetectedTitle;

  /// No description provided for @scanQrDetectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'QR Code Détecté !'**
  String get scanQrDetectedTitle;

  /// No description provided for @scanDetectedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de transport lu avec succès'**
  String get scanDetectedSubtitle;

  /// No description provided for @scanDetectedInfo.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez compléter les informations ci-dessous avant de valider.'**
  String get scanDetectedInfo;

  /// No description provided for @scanBtnAssign.
  ///
  /// In fr, this message translates to:
  /// **'Compléter les infos'**
  String get scanBtnAssign;

  /// No description provided for @scanOfflineCacheUsed.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne – données chargées depuis le cache local'**
  String get scanOfflineCacheUsed;

  /// No description provided for @scanSavedOfflineToast.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré localement, synchronisation à la reconnexion'**
  String get scanSavedOfflineToast;

  /// No description provided for @scanAlreadyValidated.
  ///
  /// In fr, this message translates to:
  /// **'Déjà validé aujourd\'hui ({nom})'**
  String scanAlreadyValidated(String nom);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
