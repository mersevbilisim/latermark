// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class L10nTr extends L10n {
  L10nTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get composeSaving => 'Kaydediliyor';

  @override
  String get actionCancel => 'Vazgeç';

  @override
  String get actionClose => 'Kapat';

  @override
  String get actionBack => 'Geri';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionEdit => 'Düzenle';

  @override
  String get actionMore => 'Daha fazla';

  @override
  String get openPhotoSemantic => 'Fotoğrafı tam ekran aç';

  @override
  String get actionRetry => 'Yeniden dene';

  @override
  String get actionGoBack => 'Geri dön';

  @override
  String get actionOpen => 'Aç';

  @override
  String get settingsAction => 'Ayarlar';

  @override
  String get shutterSemantic => 'Fotoğraf çek';

  @override
  String get searchHint => 'Ara';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonuç',
    );
    return '$_temp0';
  }

  @override
  String get searchEmpty => 'Eşleşen kayıt yok';

  @override
  String get searchCancel => 'Vazgeç';

  @override
  String get searchInPhoto => 'karede';

  @override
  String get notesTitle => 'Notlar';

  @override
  String get dateGroupToday => 'Bugün';

  @override
  String get dateGroupYesterday => 'Dün';

  @override
  String get dateGroupPastWeek => 'Son 7 gün';

  @override
  String get dateGroupPastMonth => 'Son 1 ay';

  @override
  String get dateGroupPastThreeMonths => 'Son 3 ay';

  @override
  String get dateGroupPastYear => 'Son 1 yıl';

  @override
  String get dateGroupOlder => '1 yıldan eski';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Notsuz kayıt';

  @override
  String get inviteTitle => 'Dokun ve çek';

  @override
  String get inviteBody =>
      'Fiş, park yeri, bir parça…\nFotoğrafla, iki kelime yaz, unut.';

  @override
  String get pickFromGallery => 'Galeriden seç';

  @override
  String get pickFromGallerySemantic => 'Galeriden fotoğraf seç';

  @override
  String get galleryPickerOpening => 'Fotoğraf seçici açılıyor';

  @override
  String get manifestoFirst => 'Sade';

  @override
  String get manifestoSecond => 'Cihazında';

  @override
  String get manifestoThird => 'Güvende';

  @override
  String get switchToLargeView => 'Büyük görünüme geç';

  @override
  String get switchToGridView => 'Izgara görünüme geç';

  @override
  String get toastPhotoPickFailed => 'Fotoğraf seçilemedi. Tekrar dene.';

  @override
  String get toastPendingPickFailed => 'Yarım kalan fotoğraf seçimi açılamadı.';

  @override
  String get toastSharedPhotoAdded => 'Paylaşılan fotoğraf eklendi.';

  @override
  String get toastSharedPhotoFailed =>
      'Paylaşılan fotoğraf eklenemedi. Tekrar denenecek.';

  @override
  String get toastDeleteFailed => 'Silinemedi. Tekrar dene.';

  @override
  String get toastSaveFailed => 'Kaydedilemedi. Tekrar dene.';

  @override
  String get toastEditFailed => 'Değişiklik kaydedilemedi.';

  @override
  String get toastPermissionDenied =>
      'Bildirim izni verilmedi. Hatırlatmalar kapalı kaldı.';

  @override
  String get deleteConfirmTitle => 'Bu kare silinsin mi?';

  @override
  String get deleteConfirmCaption => 'Fotoğraf ve not birlikte kalkacak.';

  @override
  String get holdToDelete => 'Silmek için basılı tut';

  @override
  String get holdStageAlmost => 'Neredeyse';

  @override
  String get holdStageRelease => 'Bırakma…';

  @override
  String get holdStageGone => 'Gitti';

  @override
  String get cameraNotFoundTitle => 'Kamera bulunamadı';

  @override
  String get cameraNotFoundBody => 'Bu cihazda kullanılabilir bir kamera yok.';

  @override
  String get cameraDeniedTitle => 'Kamera izni kapalı';

  @override
  String get cameraDeniedBody =>
      'Ayarlar › Latermark yolundan kamera erişimine izin verdiğinde buradan fotoğraf çekebilirsin.';

  @override
  String get cameraFailedTitle => 'Kamera açılamadı';

  @override
  String get cameraFailedBody => 'Beklenmedik bir hata oluştu.';

  @override
  String get switchLens => 'Objektifi değiştir';

  @override
  String flashSemantic(String state) {
    return 'Flaş: $state';
  }

  @override
  String get flashOff => 'kapalı';

  @override
  String get flashAuto => 'otomatik';

  @override
  String get flashOn => 'açık';

  @override
  String get composeHint => 'Bunu neden çektin?';

  @override
  String get composeReminderDescription =>
      'Bu kareyi seçtiğin gün yeniden karşına çıkarır.';

  @override
  String get composeLocationDescription =>
      'Bulunduğun yeri yalnızca bu kareyle ilişkilendirir.';

  @override
  String get composeLocationResolving => 'Konum alınıyor…';

  @override
  String get composeLocationReady => 'Konum bu kare için hazır.';

  @override
  String get composeLocationPermissionRequired => 'Konum izni gerekli.';

  @override
  String get composeAnotherPhoto => 'Başka fotoğraf';

  @override
  String get composeRetake => 'Yeniden';

  @override
  String get sourceGallery => 'GALERİ';

  @override
  String get sourceShared => 'PAYLAŞIM';

  @override
  String get reminderLabel => 'Hatırlat';

  @override
  String get addedLabel => 'Eklenme Tarihi';

  @override
  String get lastUpdatedLabel => 'Son Güncellenme';

  @override
  String get locationLabel => 'Konum';

  @override
  String get locationAddLabel => 'Konum ekle';

  @override
  String get locationBlocked =>
      'Konum bilgisinin eklenebilmesi izin vermenize bağlıdır. Karenin nerede çekildiğini iliştirmek için konum erişimine izin verin.';

  @override
  String get compassNorth => 'K';

  @override
  String get compassSouth => 'G';

  @override
  String get compassEast => 'D';

  @override
  String get compassWest => 'B';

  @override
  String get toastMapFailed => 'Harita açılamadı';

  @override
  String get reminderSuffixActive => 'gün sonra';

  @override
  String get reminderSuffixOff => 'gün — kapalı';

  @override
  String get reminderBlocked =>
      'Bildirimler kapalı. Kayıt yine de saklanır; izin verdiğinde hatırlatma çalışmaya başlar.';

  @override
  String get editNoteSemantic => 'Notu düzenle';

  @override
  String get editSheetHeader => 'NOTU DÜZENLE';

  @override
  String get retentionSelectorTitle => 'Otomatik Sil';

  @override
  String get retentionOffNotice =>
      'Otomatik silme kapalı — bu kare sen silmedikçe kalıcı.';

  @override
  String get retentionCustom => 'Özel';

  @override
  String get retentionCustomTitle => 'Özel süre';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hafta',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Saat';

  @override
  String get retentionUnitDays => 'Gün';

  @override
  String get retentionUnitWeeks => 'Hafta';

  @override
  String get retentionCustomDescription =>
      'Kayıt bu sürenin sonunda kendiliğinden silinir.';

  @override
  String get retentionOff => 'Kapalı';

  @override
  String get retentionThreeDays => '3 Gün';

  @override
  String get retentionOneWeek => '1 Hafta';

  @override
  String get retentionOffDescription => 'Kapalı';

  @override
  String get retentionThreeDaysDescription => '3 gün sonra silinir';

  @override
  String get retentionOneWeekDescription => '1 hafta sonra silinir';

  @override
  String get legalPrivacy => 'Gizlilik';

  @override
  String get legalTerms => 'Kullanım Koşulları';

  @override
  String get yourDataTitle => 'Latermark ve Verileriniz';

  @override
  String get yourDataSubtitle =>
      'Gizliliğinizi önemsiyor ve ona saygı duyuyoruz.';

  @override
  String get yourDataSafetyQuestion => 'Verilerim güvende mi?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark notlarınızı, fotoğraflarınızı ve konum etiketlerinizi tamamen cihazınızda işler. Siz paylaşmayı seçmedikçe içerikleriniz cihazınızdan çıkmaz; analiz, hata raporu veya kullanım istatistiği için de gönderilmez.';

  @override
  String get yourDataLocationQuestion => 'Konum izni neden istenir?';

  @override
  String get yourDataLocationAnswer =>
      'Yalnızca bir kareye çekildiği yeri eklemeyi seçtiğinizde tek seferlik konum istenir. Koordinat sadece o kayda eklenir; arka planda izleme yapılmaz. Harita düğmesine dokunmadıkça başka bir uygulamaya aktarılmaz.';

  @override
  String get yourDataPhotosQuestion => 'Fotoğraf erişimi nasıl kullanılır?';

  @override
  String get yourDataPhotosAnswer =>
      'Fotoğraf arşivinizden bir görsel seçmek istediğinizde kullanılır. Latermark yalnızca seçtiğiniz görseli kayda alır; bu işlem internet bağlantısı gerektirmez.';

  @override
  String get yourDataRemindersQuestion => 'Bildirimler nasıl çalışır?';

  @override
  String get yourDataRemindersAnswer =>
      'Hatırlatmalar cihazınızda planlanır ve cihazınız tarafından gösterilir. Dışarıdaki bir sunucu onları göndermez veya tetiklemez.';

  @override
  String get yourDataDeletionQuestion => 'Uygulamayı silersem ne olur?';

  @override
  String get yourDataDeletionAnswer =>
      'Latermark içinde saklanan notlar, uygulamaya alınan görseller ve konum etiketleri kalıcı olarak silinir. Fotoğraf arşiviniz ve diğer uygulamalardaki veriler etkilenmez.';

  @override
  String get legalOpenFailed => 'Bağlantı açılamadı.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get sectionAppearance => 'Görünüm';

  @override
  String get sectionReminder => 'Hatırlatma';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeDescription =>
      'Sistem görünümünü izle veya tercihini sabitle.';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Aydınlık';

  @override
  String get themeDark => 'Karanlık';

  @override
  String get appColorTitle => 'Uygulama rengi';

  @override
  String get appColorDescription =>
      'Latermark\'ın kontrollerde ve vurgularda kullanacağı rengi seç.';

  @override
  String get accentOrange => 'Turuncu';

  @override
  String get accentBlue => 'Mavi';

  @override
  String get accentViolet => 'Mor';

  @override
  String get accentPink => 'Pembe';

  @override
  String get accentGreen => 'Yeşil';

  @override
  String get accentGold => 'Altın';

  @override
  String get retentionTitle => 'Otomatik sil';

  @override
  String get retentionDescription =>
      'Yeni kayıtlar bu süreyle açılır. Her kaydın süresini kendi ekranından değiştirebilirsin.';

  @override
  String get feedTitle => 'Akış';

  @override
  String get feedDescription =>
      'Kareler büyük dursun ya da ızgarada daha çok kayıt görünsün.';

  @override
  String get densityLarge => 'Büyük';

  @override
  String get densityGrid => 'Izgara';

  @override
  String get languageTitle => 'Dil';

  @override
  String get languageDescription =>
      'Uygulama telefonunun dilini izler. Başka bir dil de seçebilirsin.';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get remindersTitle => 'Hatırlatmalar';

  @override
  String get remindersDescription =>
      'Yalnızca kaydederken süre verdiğin notlar için bildirim gönderilir. Diğerleri sessiz kalır.';

  @override
  String get remindersBlockedDescription =>
      'Bildirimler sistem ayarlarında kapalı. İzin verdiğinde hatırlatmalar yeniden çalışır.';

  @override
  String get openSystemSettings => 'Sistem ayarlarını aç';

  @override
  String get openSettingsShort => 'Ayarları aç';

  @override
  String versionMark(String version, String build) {
    return 'Sürüm $version ($build)';
  }

  @override
  String get dayToday => 'Bugün';

  @override
  String get dayYesterday => 'Dün';

  @override
  String get relativeJustNow => 'az önce';

  @override
  String relativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dk',
    );
    return '$_temp0';
  }

  @override
  String relativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sa',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'dün';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'şimdi';

  @override
  String remainingShortDays(int count) {
    return '${count}g';
  }

  @override
  String remainingShortHours(int count) {
    return '${count}sa';
  }

  @override
  String remainingShortMinutes(int count) {
    return '${count}dk';
  }

  @override
  String get remainingShortLessThanMinute => '<1dk';

  @override
  String get remainingSoon => 'Birazdan silinecek';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün',
    );
    return '$_temp0 sonra silinecek';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours saat',
    );
    return '$_temp0 $_temp1 sonra silinecek';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours saat',
    );
    return '$_temp0 sonra silinecek';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours saat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes dakika',
    );
    return '$_temp0 $_temp1 sonra silinecek';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes dakika',
    );
    return '$_temp0 sonra silinecek';
  }

  @override
  String get paywallLimitTitle => '10 karen dolu';

  @override
  String paywallLimitBody(int limit) {
    return 'Ücretsiz katmanda aynı anda $limit kare tutulur. Pro ile sınır kalkar — ya da bir kare silip devam edebilirsin.';
  }

  @override
  String get paywallLimitDelete => 'Bir kareyi sil';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Bazı kareler kalmalı.';

  @override
  String get paywallSubtitle =>
      'Latermark unutmak için tasarlandı. Pro, unutulmasını istemediklerin için.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Şu an $count karen var.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Sınırsız kayıt';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'Ücretsizde $limit kare tutulur.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Süreyi kendin belirle';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      '3 gün ve 1 hafta dışında istediğin süre.';

  @override
  String get paywallFeatureReminders => 'Hatırlatmalar';

  @override
  String get paywallFeatureRemindersDetail =>
      'Unutmak istemediklerin için bildirim.';

  @override
  String get paywallFeatureWidget => 'Ana ekran widget\'ı';

  @override
  String get paywallFeatureWidgetDetail =>
      'Son karen kilit ekranında bir bakışta.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Tek seferlik ödeme';

  @override
  String get paywallNoSubscription => 'Abonelik yok. Bir kez öde, hep senin.';

  @override
  String get paywallOwned => 'Latermark Pro senin.';

  @override
  String get paywallFeatureNoSubscription => 'Aboneliğe gerek yok';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'Çoğu uygulama bunu her ay satar. Bu bir kez.';

  @override
  String get paywallCta => 'Pro\'ya geç';

  @override
  String get paywallRestore => 'Satın alımları geri yükle';

  @override
  String get paywallClose => 'Kapat';

  @override
  String get paywallLifeFree => 'Ücretsiz';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Hatırlatma';

  @override
  String get notificationTitleNoBody => 'Bir kare bekliyor';

  @override
  String get notificationBodyNoBody => 'Bu kareyi hatırlatmamı istemiştin.';

  @override
  String get notificationChannelName => 'Hatırlatmalar';

  @override
  String get notificationChannelDescription =>
      'Süre verdiğin kayıtları hatırlatır.';

  @override
  String get actionOK => 'Tamam';

  @override
  String get widgetDescription => 'Son kareni ve notunu gösterir.';

  @override
  String get widgetEmptySubtitle => 'İlk notun burada görünecek';

  @override
  String get widgetPhotoDescription => 'Son karenin fotoğrafı';

  @override
  String get widgetLeaveTrace => 'Yeni bir iz bırak';

  @override
  String get widgetOpenApp => 'Latermark\'ı aç';

  @override
  String get widgetCreateNote => 'Yeni not oluştur';

  @override
  String get widgetLeaveFirstTrace => 'İlk izini bırak';

  @override
  String get widgetProRequired => 'Widget, Latermark Pro ile açılır.';

  @override
  String get widgetPreviewNote => 'Muhasebeye göndereceğim';

  @override
  String get widgetPreviewDay => 'BUGÜN';

  @override
  String get shareComposeHint => 'Bu fotoğrafı neden saklıyorsun?';

  @override
  String get shareErrorTitle => 'Fotoğraf eklenemedi';

  @override
  String get shareErrorBody =>
      'Latermark\'a aktarım tamamlanamadı. Lütfen tekrar dene.';

  @override
  String get cameraUsageDescription =>
      'Fotoğraf çekip notlarına ekleyebilmek için kamera erişimi gerekir.';

  @override
  String get photoLibraryUsageDescription =>
      'Galerinden seçtiğin fotoğrafları notlarına ekleyebilmek için fotoğraf erişimi gerekir.';

  @override
  String get actionShare => 'Paylaş';

  @override
  String get shareNoteSemantic => 'Fotoğrafı ve notu paylaş';
}
