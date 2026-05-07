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

  @override
  String get institutionAgence => 'المؤسسة / الوكالة';

  @override
  String get typeSpecial => 'نوع خاص';

  @override
  String get nombreDePersonnes => 'عدد الأشخاص';

  @override
  String get personne => 'شخص';

  @override
  String get personnes => 'أشخاص';

  @override
  String get enregistrerLePassage => 'تسجيل العبور';

  @override
  String get enregistrementEnCours => 'جارٍ التسجيل...';

  @override
  String passagesSession(int count) {
    return 'تم تسجيل $count عبور(ات) في هذه الجلسة';
  }

  @override
  String passagesToast(int count) {
    return 'تم تسجيل $count عبور(ات)';
  }

  @override
  String get erreurInconnue => 'غير معروف';

  @override
  String get passagesGratuitsSpeciaux => 'العبورات المجانية والخاصة';

  @override
  String resumePassage(int count, String typeTarif) {
    return '$count شخص(أشخاص) · $typeTarif';
  }

  @override
  String erreurPassage(String message) {
    return 'خطأ: $message';
  }

  @override
  String get categorieArmeeNationale => 'الجيش الوطني';

  @override
  String get categorieGardeNationale => 'الحرس الوطني';

  @override
  String get categoriePoliceNationale => 'الأمن الوطني';

  @override
  String get categorieDouane => 'الديوانة';

  @override
  String get categorieMinistere => 'وزارة';

  @override
  String get categorieMunicipalite => 'بلدية';

  @override
  String get categorieEtablissementScolaire => 'مؤسسة تعليمية';

  @override
  String get categorieAutreInstitution => 'مؤسسة أخرى';

  @override
  String get categorieAbonnement => 'اشتراك';

  @override
  String get categorieAgent => 'عون';

  @override
  String get historiqueVoyage => 'سجل الرحلة';

  @override
  String get tickets => 'التذاكر';

  @override
  String get finance => 'المالية';

  @override
  String get liste => 'القائمة';

  @override
  String get parSegment => 'حسب القطعة';

  @override
  String get apercu => 'نظرة عامة';

  @override
  String get parTarif => 'حسب التعريفة';

  @override
  String get bilan => 'الملخص';

  @override
  String get aucunTicketAujourdhui => 'لا توجد تذاكر اليوم';

  @override
  String get ticketsAujourdhuiApparaitront => 'ستظهر تذاكر اليوم هنا';

  @override
  String get aucunSegmentDisponible => 'لا توجد قطاعات متاحة';

  @override
  String get segmentInfoIndisponible => 'معلومات القطعة غير متاحة';

  @override
  String get aucunTarif => 'لا توجد تعريفة';

  @override
  String get donneesApparaitrontIci => 'ستظهر البيانات هنا';

  @override
  String get recetteTotale => 'إجمالي الإيرادات';

  @override
  String get ticketsVendus => 'التذاكر المباعة';

  @override
  String get aujourdhui => 'اليوم';

  @override
  String get prixMoyen => 'متوسط السعر';

  @override
  String get ticketPayant => 'تذكرة مدفوعة';

  @override
  String get repartitionRecettes => 'توزيع الإيرادات';

  @override
  String get recetteParTarif => 'الإيرادات حسب التعريفة';

  @override
  String get detailFinancierParTarif => 'التفاصيل المالية حسب التعريفة';

  @override
  String get recetteTotaleVoyage => 'إجمالي إيرادات الرحلة — اليوم';

  @override
  String equivalentDT(String dt) {
    return '≈ $dt د.ت';
  }

  @override
  String get ticketsPayants => 'التذاكر المدفوعة';

  @override
  String get totalVoyageurs => 'إجمالي المسافرين';

  @override
  String get prixMoyenPayants => 'متوسط السعر (مدفوع)';

  @override
  String get analyseGratuites => 'تحليل التذاكر المجانية';

  @override
  String get manqueAGagnerEstime => 'الخسارة المقدرة';

  @override
  String get tauxGratuite => 'نسبة المجانية';

  @override
  String get payants => 'مدفوعون';

  @override
  String get typesTarifUtilises => 'أنواع التعريفات المستخدمة';

  @override
  String segmentsPluralLabel(int count) {
    return '$count قطعة (قطاعات)';
  }

  @override
  String get recetteParSegment => 'الإيرادات حسب القطعة';

  @override
  String segmentLePlusRentable(String seg) {
    return 'أكثر القطاعات ربحًا: القطعة $seg';
  }

  @override
  String get nonClasse => 'غير مصنف';

  @override
  String get enAttenteSyncLabel => 'في انتظار المزامنة';

  @override
  String get echecSyncLabel => 'فشل المزامنة';

  @override
  String prixUnitaireParTicket(int prix) {
    return '$prix م/تذكرة';
  }

  @override
  String segLabel(String seg) {
    return 'قطعة $seg';
  }

  @override
  String ticketsAujourdhuiCount(int count) {
    return '$count تذكرة (تذاكر) اليوم';
  }

  @override
  String ticketsCountAvecSync(int count, int pending, int failed) {
    return '$count تذكرة (تذاكر) اليوم · $pending في الانتظار · $failed فشل';
  }

  @override
  String get horsLigneAucunTicketLocal =>
      'غير متصل — لا توجد تذاكر محلية اليوم';

  @override
  String horsLigneTicketsEnAttente(int count) {
    return 'غير متصل — $count تذكرة (تذاكر) في الانتظار اليوم';
  }

  @override
  String horsLigneTicketsCache(int count) {
    return 'غير متصل — $count تذكرة (تذاكر) مؤقتة (اليوم)';
  }

  @override
  String get idVoyageManquantError => 'معرّف الرحلة مفقود';

  @override
  String get msRecette => 'م إيرادات';

  @override
  String get prixUnitaireMs => 'سعر الوحدة (م)';

  @override
  String get journauxSyncTitle => 'سجلات المزامنة';

  @override
  String get reseauOperationnel => 'الشبكة تعمل';

  @override
  String requetesEnAttente(int count) {
    return '$count طلب (طلبات) في الانتظار';
  }

  @override
  String get kpiOk => '200 OK';

  @override
  String get kpiErreur => '5xx خطأ';

  @override
  String get kpiEnFile => 'في الانتظار';

  @override
  String get kpiTauxReussite => 'نسبة النجاح';

  @override
  String syncResultat(int synced, int failed) {
    return '✓ $synced تمت مزامنتها   ✗ $failed فشلت';
  }

  @override
  String get tabFileAttente => 'قائمة الانتظار';

  @override
  String get tabRequetesHttp => 'طلبات HTTP';

  @override
  String get tabConsole => 'وحدة التحكم';

  @override
  String get fileAttenteVide => 'قائمة الانتظار فارغة';

  @override
  String get tousTicketsSynchronises => 'جميع التذاكر متزامنة';

  @override
  String get aucuneRequete => 'لا توجد طلبات مسجّلة';

  @override
  String syncConsoleTitle(int count) {
    return 'sync_log — $count سجل';
  }

  @override
  String get aucunLogDisponible => 'لا توجد سجلات متاحة';

  @override
  String ticketsLocaux(int count) {
    return 'التذاكر المحلية — $count سجل';
  }

  @override
  String get aucunTicketLocal => 'لا توجد تذاكر محلية';

  @override
  String retryLabel(int count) {
    return '$count× إعادة محاولة';
  }

  @override
  String get statusSynced => 'متزامن';

  @override
  String get statusFailed => 'فشل';

  @override
  String get statusPending => 'في الانتظار';

  @override
  String get finDuVoyage => 'نهاية الرحلة';

  @override
  String get voyageEnCours => 'الرحلة الجارية';

  @override
  String get attentionTitre => 'تنبيه';

  @override
  String get clotureIrreversible => 'هذا الإجراء لا يمكن التراجع عنه';

  @override
  String get clotureAucuneVente => 'لن يكون البيع ممكناً بعد الإغلاق';

  @override
  String get clotureVoyageMarque => 'سيتم وضع علامة على الرحلة كمنتهية';

  @override
  String get confirmerCloture => 'تأكيد الإغلاق';

  @override
  String get clotureEnCours => 'جارٍ الإغلاق...';

  @override
  String get voyageCloture => 'تم إغلاق الرحلة !';

  @override
  String get retourEnCours => 'جارٍ العودة...';

  @override
  String get erreurInattendue => 'خطأ غير متوقع';

  @override
  String get horsLigneCloturePending =>
      'غير متصل — تم تسجيل الإغلاق، سيُرسل عند إعادة الاتصال';

  @override
  String get scanReadMode => 'وضع القراءة';

  @override
  String get scanModeNfc => 'NFC';

  @override
  String get scanNfcSublabel => 'أقرّب البطاقة';

  @override
  String get scanModeQr => 'باركود';

  @override
  String get scanQrSublabel => 'امسح رمز QR / الباركود';

  @override
  String get scanNfcUnavailable => 'NFC غير متوفر على هذا الجهاز';

  @override
  String get scanNfcApproach => 'أقرّب بطاقة النقل';

  @override
  String get scanNfcUnreadable => 'بطاقة NFC غير قابلة للقراءة أو غير صالحة';

  @override
  String get scanNfcReadError => 'خطأ في القراءة';

  @override
  String scanNfcError(String error) {
    return 'خطأ NFC: $error';
  }

  @override
  String get scanNfcSheetTitle => 'أقرّب بطاقة NFC';

  @override
  String get scanNfcSheetSubtitle => 'أمسك البطاقة بالقرب من\nظهر هاتفك';

  @override
  String get scanCameraTitle => 'مسح الباركود / رمز QR';

  @override
  String get scanCameraHint => 'ضع الرمز في منتصف الإطار';

  @override
  String get scanUnknown => 'غير معروف';

  @override
  String get scanIncompleteData =>
      'بيانات التذكرة غير مكتملة (id أو type أو expire مفقود)';

  @override
  String scanCardNotFound(String cardId) {
    return 'البطاقة غير معروفة\n$cardId';
  }

  @override
  String scanLookupError(String error) {
    return 'خطأ أثناء البحث: $error';
  }

  @override
  String get scanPrefix => 'مسح';

  @override
  String get scanValidatedToast => 'تم التحقق من التذكرة وحفظها ✓';

  @override
  String scanSaveError(String error) {
    return 'خطأ: $error';
  }

  @override
  String scanSessionCount(int count) {
    return 'تم التحقق من $count تذكرة (تذاكر) في هذه الجلسة';
  }

  @override
  String get scanFieldSubscriptionType => 'نوع الاشتراك';

  @override
  String get scanFieldOrganisme => 'الجهة';

  @override
  String get scanFieldAuthorisedLine => 'الخط المرخّص';

  @override
  String get scanFieldExpiry => 'تاريخ الانتهاء';

  @override
  String get scanFieldStatus => 'الحالة';

  @override
  String get scanStatusExpired => 'منتهي الصلاحية';

  @override
  String get scanStatusValid => 'صالح';

  @override
  String get scanExpiredWarning =>
      'هذه التذكرة منتهية الصلاحية ولا يمكن التحقق منها.';

  @override
  String get scanSaving => 'جارٍ الحفظ...';

  @override
  String get scanBtnExpired => 'التذكرة منتهية';

  @override
  String get scanBtnValidate => 'تحقق وحفظ';

  @override
  String get scanIdleTitle => 'جاهز للمسح';

  @override
  String get scanIdleSubtitle => 'اختر NFC أو الباركود\nلبدء القراءة';

  @override
  String get scanSearching => 'جارٍ البحث عن التذكرة…';

  @override
  String get scanInvalidTitle => 'تذكرة غير صالحة';

  @override
  String get scanErrorSubtitle => 'لا يمكن قبول هذه التذكرة.';

  @override
  String get scanTitreDetecte => 'تذكرة مكتشفة';

  @override
  String get scanAssignInstruction => 'أكمل المعلومات قبل التحقق';

  @override
  String get scanAssignMissing => 'يرجى اختيار الخط والنوع والرحلة';

  @override
  String get scanFieldLigne => 'الخط';

  @override
  String get scanFieldTrajet => 'الرحلة';

  @override
  String get scanSelectLigne => 'اختر خطًا';

  @override
  String get scanSelectType => 'اختر النوع';

  @override
  String get scanSelectTrajet => 'اختر الرحلة';

  @override
  String get scanValidatedTitle => 'تم التحقق';

  @override
  String get scanNextTitle => 'مسح تذكرة أخرى';

  @override
  String get scanNfcDetectedTitle => 'تم اكتشاف بطاقة NFC !';

  @override
  String get scanQrDetectedTitle => 'تم اكتشاف رمز QR !';

  @override
  String get scanDetectedSubtitle => 'تمت قراءة تذكرة النقل بنجاح';

  @override
  String get scanDetectedInfo => 'يرجى إكمال المعلومات أدناه قبل التحقق.';

  @override
  String get scanBtnAssign => 'إكمال المعلومات';

  @override
  String get scanOfflineCacheUsed =>
      'وضع غير متصل – البيانات محملة من الذاكرة المحلية';

  @override
  String get scanSavedOfflineToast =>
      'تم الحفظ محلياً، ستتم المزامنة عند استعادة الاتصال';

  @override
  String scanAlreadyValidated(String nom) {
    return 'تمت المصادقة اليوم بالفعل ($nom)';
  }

  @override
  String get scanTicketQrInvalid =>
      'رمز QR غير صالح (لم يتم العثور على id_ticket)';

  @override
  String scanTicketNotFound(int idTicket) {
    return 'التذكرة رقم #$idTicket غير موجودة';
  }

  @override
  String scanTicketLigneMismatch(String detail) {
    return 'الخط غير متوافق: $detail';
  }

  @override
  String get scanTicketAlreadyScanned => 'تم مسح هذه التذكرة مسبقاً';

  @override
  String get scanTicketValidatedToast => 'تم التحقق من التذكرة بنجاح ✓';

  @override
  String get scanModeTicketVendu => 'تذكرة مباعة';

  @override
  String get scanTicketVenduSublabel => 'مسح رمز تذكرة البيع';

  @override
  String get scanTicketVenduTitle => 'التحقق من التذكرة';

  @override
  String get scanFieldTarif => 'التعريفة';

  @override
  String get scanFieldQuantite => 'الكمية';

  @override
  String get scanFieldPrixUnitaire => 'سعر الوحدة';

  @override
  String get scanFieldMontantTotal => 'المبلغ الإجمالي';

  @override
  String get scanFieldDateVente => 'تاريخ البيع';

  @override
  String get scanFieldAgentVente => 'عون البيع';

  @override
  String get voyageCreeSucces => 'تم إنشاء الرحلة بنجاح';

  @override
  String get enAttenteSyncBadge => 'في انتظار المزامنة';

  @override
  String get spontane => 'عفوي';

  @override
  String get ajouterVoyage => 'إضافة رحلة';

  @override
  String get aucunVoyageNonProgrammeDesc => 'لا توجد رحلات غير مبرمجة لليوم';

  @override
  String get nouveauVoyage => 'رحلة جديدة';

  @override
  String voyageSpontaneAgence(int code) {
    return 'رحلة عفوية · الوكالة $code';
  }

  @override
  String get voyageSpontaneAgenceInconnue => 'رحلة عفوية · وكالة غير معروفة';

  @override
  String get ligneLabel => 'الخط *';

  @override
  String get dateHeureDepart => 'تاريخ ووقت الانطلاق';

  @override
  String get selectionnerLigne => 'اختر خطًا';

  @override
  String get creation => 'جارٍ الإنشاء...';

  @override
  String get creerVoyage => 'إنشاء الرحلة';

  @override
  String get codeAgenceIntrouvable =>
      'رمز الوكالة غير موجود. يرجى إعادة تسجيل الدخول.';

  @override
  String get horsLigneAucuneLigneCache => 'غير متصل — لا توجد خطوط محلية.';

  @override
  String get aucuneLigneAgence => 'لا توجد خطوط متاحة لوكالتك.';

  @override
  String get donneesLocales => 'بيانات محلية (غير متصل)';

  @override
  String donneesLocalesDate(String date) {
    return 'بيانات محلية · $date';
  }

  @override
  String get actualiser => 'تحديث';

  @override
  String get maintenant => 'الآن (افتراضي)';

  @override
  String get heurePersonnalisee => 'وقت مخصص';

  @override
  String get impossibleCreerVoyage => 'تعذّر إنشاء الرحلة. حاول مجددًا.';

  @override
  String get veuillerSelectionnerLigne => 'يرجى اختيار خط.';

  @override
  String get voyageSansIdentifiant => 'رحلة بدون معرّف';

  @override
  String get aucunHistoriqueDisponible => 'لا يوجد سجل متاح';

  @override
  String get voyageHorsLigneSyncMessage =>
      'رحلة غير متصلة — ستتم مزامنة التذاكر عند استعادة الاتصال.';

  @override
  String get voyageEnAttenteSync => 'غير متصل';

  @override
  String get syncDisponibleApres => 'متاح بعد المزامنة';

  @override
  String get horsLigneCloturePendingSync =>
      'الرحلة في انتظار المزامنة — الإغلاق غير متاح';

  @override
  String get horsLigneLabel => '⏳ غير متصل';

  @override
  String get scanStatusAlreadyScanned => 'تم المسح مسبقاً';

  @override
  String scanTicketAlreadyScannedAt(String dateTime) {
    return 'تم المسح بتاريخ $dateTime';
  }

  @override
  String get scanTicketAlreadyScannedBtn => 'تم المسح مسبقاً';
}
