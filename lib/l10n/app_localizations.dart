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
  /// **'Veuillez saisir votre matricule'**
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
  /// **'Veuillez saisir votre mot de passe'**
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
  /// **'Hors ligne — aucun compte local trouvé'**
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
  /// **'Clôturer toute la journée ?'**
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
  /// **'Hors ligne — aucune donnée disponible'**
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
  /// **'Rouvrir la journée ?'**
  String get reouvrirJourneeQuestion;

  /// No description provided for @actionReversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est réversible'**
  String get actionReversible;

  /// No description provided for @reouvrirTout.
  ///
  /// In fr, this message translates to:
  /// **'Tout rouvrir'**
  String get reouvrirTout;

  /// No description provided for @reouvrirCeVoyage.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir ce voyage ?'**
  String get reouvrirCeVoyage;

  /// No description provided for @reouvrirVoyageBody.
  ///
  /// In fr, this message translates to:
  /// **'Le voyage reviendra à l\'état actif et vous pourrez à nouveau vendre des billets.'**
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
  /// **'Ventes et historique'**
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
  /// **'Journaux de synchronisation'**
  String get journauxSync;

  /// No description provided for @journauxSyncEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'Journaux sync · {count} en attente'**
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
  /// **'Hors ligne et aucun cache disponible. Veuillez vous connecter à Internet.'**
  String get horsLignePasDeCacheErreur;

  /// No description provided for @horsLigneDonneesCache.
  ///
  /// In fr, this message translates to:
  /// **'Données chargées depuis le cache (mode hors ligne)'**
  String get horsLigneDonneesCache;

  /// No description provided for @horsLigneSynchronise.
  ///
  /// In fr, this message translates to:
  /// **'Ce billet sera synchronisé dès le retour en ligne.'**
  String get horsLigneSynchronise;

  /// No description provided for @horsLigneActionsSync.
  ///
  /// In fr, this message translates to:
  /// **'Les actions seront synchronisées à la reconnexion.'**
  String get horsLigneActionsSync;

  /// No description provided for @horsLigneTicketSauvegarde.
  ///
  /// In fr, this message translates to:
  /// **'Billet sauvegardé localement (hors ligne)'**
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
  /// **'Choisissez d\'abord la montée'**
  String get choisirDabordMontee;

  /// No description provided for @aucunArretDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Aucun arrêt disponible'**
  String get aucunArretDisponible;

  /// No description provided for @nombreDeTickets.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de billets'**
  String get nombreDeTickets;

  /// No description provided for @confirmerTicket.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le billet'**
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
  /// **'QR CODE DU BILLET'**
  String get qrCodeTicket;

  /// No description provided for @ticketSingulier.
  ///
  /// In fr, this message translates to:
  /// **'billet'**
  String get ticketSingulier;

  /// No description provided for @ticketPluriel.
  ///
  /// In fr, this message translates to:
  /// **'billets'**
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
  /// **'Valider le billet'**
  String get validerLeTicket;

  /// No description provided for @validerTickets.
  ///
  /// In fr, this message translates to:
  /// **'Valider {count} billets'**
  String validerTickets(int count);

  /// No description provided for @passageGratuit.
  ///
  /// In fr, this message translates to:
  /// **'Passage gratuit'**
  String get passageGratuit;

  /// No description provided for @ticketsVendusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Billets vendus'**
  String get ticketsVendusLabel;

  /// No description provided for @totalCollecte.
  ///
  /// In fr, this message translates to:
  /// **'Total collecté'**
  String get totalCollecte;

  /// No description provided for @idVoyageManquant.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant du voyage manquant'**
  String get idVoyageManquant;

  /// No description provided for @inconnu.
  ///
  /// In fr, this message translates to:
  /// **'inconnu'**
  String get inconnu;

  /// No description provided for @ticketsVendusToast.
  ///
  /// In fr, this message translates to:
  /// **'{count} billet(s) vendu(s) — {montant} millimes'**
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
