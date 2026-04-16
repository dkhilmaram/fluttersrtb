// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'SRTB';

  @override
  String get connexion => 'تسجيل الدخول';

  @override
  String get matricule => 'رقم التسجيل';

  @override
  String get matriculeHint => 'أدخل رقم التسجيل';

  @override
  String get matriculeError => 'يرجى إدخال رقم التسجيل';

  @override
  String get motDePasse => 'كلمة المرور';

  @override
  String get motDePasseHint => 'أدخل كلمة المرور';

  @override
  String get motDePasseError => 'يرجى إدخال كلمة المرور';

  @override
  String get seConnecter => 'تسجيل الدخول';

  @override
  String get offlineHint =>
      'سجّل دخولك مرة واحدة عبر الإنترنت\nلتفعيل وضع عدم الاتصال';

  @override
  String bienvenue(String prenom, String nom) {
    return 'مرحباً $prenom $nom !';
  }

  @override
  String bienvenueOffline(String prenom) {
    return 'بدون اتصال — مرحباً $prenom !';
  }

  @override
  String get loginError => 'رقم التسجيل أو كلمة المرور غير صحيحة';

  @override
  String get matriculeInvalid => 'رقم التسجيل غير صالح';

  @override
  String get offlineNoAccount => 'بدون اتصال — لم يتم العثور على حساب محلي';

  @override
  String get srtbFullName => 'الشركة الجهوية للنقل ببنزرت';
}
