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
  String get matricule => 'الرقم الوظيفي';

  @override
  String get matriculeHint => 'أدخل رقمك الوظيفي';

  @override
  String get matriculeError => 'يرجى إدخال رقمك الوظيفي';

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
      'سجّل الدخول مرة واحدة وأنت متصل\nلتفعيل وضع عدم الاتصال';

  @override
  String bienvenue(String prenom, String nom) {
    return 'مرحباً $prenom $nom !';
  }

  @override
  String bienvenueOffline(String prenom) {
    return 'غير متصل — مرحباً $prenom !';
  }

  @override
  String get loginError => 'الرقم الوظيفي أو كلمة المرور غير صحيحة';

  @override
  String get matriculeInvalid => 'الرقم الوظيفي غير صالح';

  @override
  String get offlineNoAccount => 'غير متصل — لم يُعثر على حساب محلي';

  @override
  String get srtbFullName => 'الشركة الجهوية للنقل ببنزرت';

  @override
  String get mesVoyages => 'رحلاتي';

  @override
  String get programmes => 'مجدولة';

  @override
  String get nonProgrammes => 'غير مجدولة';

  @override
  String get total => 'المجموع';

  @override
  String get clotures => 'مغلقة';

  @override
  String get enCours => 'جارية';

  @override
  String get actifs => 'نشطة';

  @override
  String get aucunVoyageProgramme => 'لا توجد رحلات مجدولة';

  @override
  String get aucunVoyageNonProgramme => 'لا توجد رحلات غير مجدولة';

  @override
  String get cloturerJournee => 'إغلاق اليوم';

  @override
  String get cloturerJourneeQuestion => 'هل تريد إغلاق اليوم بأكمله؟';

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
  String get horsLignePasDeDonnees => 'غير متصل — لا توجد بيانات متاحة';

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
  String get voyageReouvertOffline => 'تمت إعادة فتح الرحلة (غير متصل)';

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
  String get reouvrirJourneeQuestion => 'هل تريد إعادة فتح اليوم؟';

  @override
  String get actionReversible => 'يمكن التراجع عن هذا الإجراء';

  @override
  String get reouvrirTout => 'إعادة فتح الكل';

  @override
  String get reouvrirCeVoyage => 'هل تريد إعادة فتح هذه الرحلة؟';

  @override
  String get reouvrirVoyageBody =>
      'ستعود الرحلة إلى الحالة النشطة وستتمكن من بيع التذاكر مجدداً.';

  @override
  String get rouvrir => 'إعادة الفتح';

  @override
  String journeeClotureOffline(int count) {
    return 'تم إغلاق $count رحلة (رحلات) (غير متصل)';
  }

  @override
  String journeeCloture(int count) {
    return 'تم إغلاق $count رحلة (رحلات) بنجاح';
  }

  @override
  String journeeReouverteOffline(int count) {
    return 'تمت إعادة فتح $count رحلة (رحلات) (غير متصل)';
  }

  @override
  String journeeReouverte(int count) {
    return 'تمت إعادة فتح $count رحلة (رحلات) بنجاح';
  }

  @override
  String erreurExport(String error) {
    return 'خطأ أثناء التصدير: $error';
  }

  @override
  String voyagesConfirmBody(int count, String date) {
    return 'أنت على وشك إغلاق $count رحلة (رحلات) بتاريخ $date.';
  }

  @override
  String envoyerRapportBody(String date) {
    return 'سيتم إرسال تقرير $date بالبريد الإلكتروني إلى:';
  }

  @override
  String reouvrirJourneeBody(int count, String date) {
    return 'ستقوم بإعادة فتح $count رحلة (رحلات) مغلقة بتاريخ $date.';
  }

  @override
  String get venteEtHistorique => 'المبيعات والسجل';

  @override
  String get billetterie => 'التذاكر';

  @override
  String get historique => 'السجل';

  @override
  String get journauxSync => 'سجلات المزامنة';

  @override
  String journauxSyncEnAttente(int count) {
    return 'سجلات المزامنة · $count في الانتظار';
  }

  @override
  String get clotureVoyage => 'إغلاق الرحلة';

  @override
  String get actif => 'نشط';

  @override
  String get srtbLetters => 'S R T B';

  @override
  String get horsLignePasDeCacheErreur =>
      'غير متصل ولا يوجد ذاكرة تخزين مؤقت. يرجى الاتصال بالإنترنت.';

  @override
  String get horsLigneDonneesCache =>
      'تم تحميل البيانات من الذاكرة المؤقتة (وضع عدم الاتصال)';

  @override
  String get horsLigneSynchronise =>
      'سيتم مزامنة هذه التذكرة عند العودة إلى الاتصال.';

  @override
  String get horsLigneActionsSync => 'ستتم مزامنة الإجراءات عند إعادة الاتصال.';

  @override
  String get horsLigneTicketSauvegarde => 'تم حفظ التذكرة محلياً (غير متصل)';

  @override
  String get typeDeTarif => 'نوع التعريفة';

  @override
  String get trajetLabel => 'المسار';

  @override
  String get pointDeMontee => 'نقطة الصعود';

  @override
  String get pointDeDescente => 'نقطة النزول';

  @override
  String get choisirArret => 'اختر محطة';

  @override
  String get choisirDabordMontee => 'اختر نقطة الصعود أولاً';

  @override
  String get aucunArretDisponible => 'لا توجد محطات متاحة';

  @override
  String get nombreDeTickets => 'عدد التذاكر';

  @override
  String get confirmerTicket => 'تأكيد التذكرة';

  @override
  String get monteeLabel => 'الصعود';

  @override
  String get descenteLabel => 'النزول';

  @override
  String get tarifLabel => 'التعريفة';

  @override
  String get quantiteLabel => 'الكمية';

  @override
  String get millimes => 'مليم';

  @override
  String get gratuit => 'مجاني';

  @override
  String get qrCodeTicket => 'رمز QR للتذكرة';

  @override
  String get ticketSingulier => 'تذكرة';

  @override
  String get ticketPluriel => 'تذاكر';

  @override
  String get valider => 'تحقق';

  @override
  String get enregistrement => 'جارٍ الحفظ…';

  @override
  String get validerLeTicket => 'تحقق من التذكرة';

  @override
  String validerTickets(int count) {
    return 'تحقق من $count تذاكر';
  }

  @override
  String get passageGratuit => 'مرور مجاني';

  @override
  String get ticketsVendusLabel => 'التذاكر المباعة';

  @override
  String get totalCollecte => 'إجمالي المحصّل';

  @override
  String get idVoyageManquant => 'معرّف الرحلة مفقود';

  @override
  String get inconnu => 'غير معروف';

  @override
  String ticketsVendusToast(int count, int montant) {
    return 'تم بيع $count تذكرة (تذاكر) — $montant مليم';
  }

  @override
  String passagesGratuitsEnregistres(int count) {
    return 'تم تسجيل $count مرور (مرورات) مجاني';
  }

  @override
  String ticketErreur(String message) {
    return 'خطأ: $message';
  }

  @override
  String pourcentageApplique(int pct) {
    return '−$pct% مطبّق';
  }
}
