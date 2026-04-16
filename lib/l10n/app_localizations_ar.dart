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

  @override
  String get mesVoyages => 'رحلاتي';

  @override
  String get programmes => 'المبرمجة';

  @override
  String get nonProgrammes => 'غير المبرمجة';

  @override
  String get total => 'المجموع';

  @override
  String get clotures => 'المغلقة';

  @override
  String get enCours => 'جارية';

  @override
  String get actifs => 'نشطة';

  @override
  String get aucunVoyageProgramme => 'لا توجد رحلات مبرمجة';

  @override
  String get aucunVoyageNonProgramme => 'لا توجد رحلات غير مبرمجة';

  @override
  String get cloturerJournee => 'إغلاق اليوم';

  @override
  String get cloturerJourneeQuestion => 'إغلاق كل اليوم؟';

  @override
  String get annuler => 'إلغاء';

  @override
  String get confirmer => 'تأكيد';

  @override
  String get reouvrirJournee => 'إعادة فتح اليوم';

  @override
  String get exporterRapport => 'تصدير وإرسال التقرير';

  @override
  String get statutCloture => 'مغلق';

  @override
  String get statutEnAttente => 'في الانتظار';

  @override
  String get statutActif => 'نشط';

  @override
  String get horsLignePasDeDonnees => 'بدون اتصال — لا توجد بيانات متاحة';

  @override
  String get modeHorsLigne => 'وضع عدم الاتصال';

  @override
  String get tousDejaClotureToast => 'جميع الرحلات مغلقة بالفعل';

  @override
  String get echecCloture => 'فشل الإغلاق';

  @override
  String get aucunAReouvrirToast => 'لا توجد رحلات مغلقة لإعادة فتحها';

  @override
  String get reouvertureEnCours => 'جارٍ إعادة الفتح…';

  @override
  String get echecReouverture => 'فشل إعادة الفتح';

  @override
  String get voyageReouvertOffline => 'تمت إعادة فتح الرحلة (بدون اتصال)';

  @override
  String get voyageReouvert => 'تمت إعادة فتح الرحلة بنجاح';

  @override
  String get generationExcel => 'جارٍ إنشاء ملف Excel…';

  @override
  String get generationPdf => 'جارٍ إنشاء ملف PDF…';

  @override
  String get rapportEnvoye => 'تم إرسال التقرير بنجاح';

  @override
  String get terminerVoyageEnCoursToast => 'أنهِ الرحلة الجارية قبل المتابعة';

  @override
  String get cloturureEnCours => 'جارٍ الإغلاق…';

  @override
  String get envoiEnCours => 'جارٍ الإرسال…';

  @override
  String get appuyerReouvrirLabel => 'اضغط لإعادة الفتح';

  @override
  String get enAttenteVoyagePrecedent => 'في انتظار الرحلة السابقة';

  @override
  String get reessayer => 'إعادة المحاولة';

  @override
  String get envoyerRapport => 'إرسال التقرير';

  @override
  String get reouvrirJourneeQuestion => 'إعادة فتح اليوم؟';

  @override
  String get actionReversible => 'هذا الإجراء قابل للتراجع';

  @override
  String get reouvrirTout => 'إعادة فتح الكل';

  @override
  String get reouvrirCeVoyage => 'إعادة فتح هذه الرحلة؟';

  @override
  String get reouvrirVoyageBody =>
      'ستعود الرحلة إلى الحالة النشطة وستتمكن من بيع التذاكر مجدداً.';

  @override
  String get rouvrir => 'إعادة فتح';

  @override
  String journeeClotureOffline(int count) {
    return 'تم إغلاق $count رحلة (بدون اتصال)';
  }

  @override
  String journeeCloture(int count) {
    return 'تم إغلاق $count رحلة بنجاح';
  }

  @override
  String journeeReouverteOffline(int count) {
    return 'تمت إعادة فتح $count رحلة (بدون اتصال)';
  }

  @override
  String journeeReouverte(int count) {
    return 'تمت إعادة فتح $count رحلة بنجاح';
  }

  @override
  String erreurExport(String error) {
    return 'خطأ أثناء التصدير: $error';
  }

  @override
  String voyagesConfirmBody(int count, String date) {
    return 'أنت على وشك إغلاق $count رحلة ليوم $date.';
  }

  @override
  String envoyerRapportBody(String date) {
    return 'سيتم إرسال تقرير يوم $date عبر البريد الإلكتروني إلى:';
  }

  @override
  String reouvrirJourneeBody(int count, String date) {
    return 'ستقوم بإعادة فتح $count رحلة مغلقة ليوم $date.';
  }
}
