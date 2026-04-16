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
}
