import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../features/home_widget/home_widget_bridge.dart';
import '../features/backup/data/backup_service.dart';
import '../features/notes/data/notes_database.dart';
import '../features/paywall/domain/pro_limits.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/domain/retention.dart';
import '../features/notes/presentation/import/shared_import.dart';
import '../features/notes/data/location_service.dart';
import '../features/notes/data/ocr_service.dart';
import '../features/paywall/data/purchase_service.dart';
import '../features/reminders/reminder_action_handler.dart';
import '../features/reminders/reminder_service.dart';
import '../features/review/review_prompt_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_locale.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/spotlight/spotlight_bridge.dart';
import '../l10n/app_localizations.dart';
import '../l10n/supported_locale.dart';

/// Uygulamanın çalışan parçalarını ağaca taşıyan kapsam.
///
/// Arka plan işlerini o yönetir:
/// * "otomatik sil" sözünü tutan zamanlayıcı — açılışta, her öne gelişte ve
///   önplandayken dakikada bir süresi dolmuş notları temizler,
/// * ana ekran widget'ını besleyen köprü,
/// * kayıtları Spotlight'a taşıyan köprü,
/// * "bir süredir bakmadın" hatırlatıcıları.
///
/// Bu iş için harici bir durum yönetimi paketine gerek yok.
class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.notes,
    required this.settings,
    this.backups,
    this.reviewPrompts,
    this.location,
    this.reminders,
    this.countRecoverableFrames,
    this.onRepairArchive,
    required this.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final BackupService? backups;
  final ReviewPromptService? reviewPrompts;

  /// Varsayılan olarak gerçek platform servisi kullanılır. Testler izin ve
  /// sabitleme yarışlarını deterministik bir servisle doğrulayabilir.
  final LocationService? location;

  /// Widget/lifecycle testleri OS kanalı yerine deterministik bir izin
  /// servisi bağlayabilir. Verilmezse gerçek platform servisi kurulur.
  final ReminderService? reminders;

  /// Arşiv okunamadığında diskte kaç karenin kurtarılabileceği.
  final Future<int> Function()? countRecoverableFrames;

  /// Onarımı yürütür, kurtarılan kare sayısını döner.
  final Future<int> Function()? onRepairArchive;

  final Widget child;

  /// Arşiv okunamadığında ana ekranın kullandığı onarım yolu. Yığını
  /// tazelemek gerektiği için asıl sahibi kök widget.
  static ArchiveRepair? archiveRepair(BuildContext context) =>
      _scope(context).archiveRepair;

  static NotesRepository of(BuildContext context) => _scope(context).notes;

  static SettingsRepository settingsOf(BuildContext context) =>
      _scope(context).settings;

  /// Yürürlükteki tercihler. Değiştiğinde dinleyen widget yeniden kurulur.
  static AppSettings preferences(BuildContext context) =>
      _scope(context).preferences;

  /// İşletim sisteminin Latermark bildirimlerine verdiği güncel hak.
  /// Veritabanındaki [AppSettings.reminderEnabled] kullanıcı niyetidir;
  /// sistem hakkı ayrı tutulur ki Ayarlar'dan yeniden izin verildiğinde not
  /// seçimleri kaybolmadan çalışmaya devam etsin.
  static ReminderPermissionState reminderPermission(BuildContext context) =>
      _scope(context).reminderPermission;

  /// Kurulu ama henüz çalmamış hatırlatmaların kayıt kimlikleri.
  static Set<int> pendingReminderNoteIds(BuildContext context) =>
      _scope(context).pendingReminderNoteIds;

  /// Yeniden kurulumdan sonra da duran ücretsiz hatırlatma hak tabanı.
  static int freeReminderFloor(BuildContext context) =>
      _scope(context).freeReminderFloor;

  /// Not künyesinde gerçekten çalışan bir hatırlatma gösterilebilir mi?
  static bool remindersActive(BuildContext context) {
    final scope = _scope(context);
    return scope.preferences.proUnlocked &&
        scope.preferences.reminderEnabled &&
        scope.reminderPermission == ReminderPermissionState.granted;
  }

  /// Açık ekranlardaki “sonraki” anını canlı tutan, dar kapsamlı saat.
  static ValueListenable<DateTime> reminderClockOf(BuildContext context) =>
      _scope(context).reminderClock;

  static _RepositoryScope _scope(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RepositoryScope>();
    assert(scope != null, 'AppScope, widget ağacında bulunamadı.');
    return scope!;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> with WidgetsBindingObserver {
  static const _sweepInterval = Duration(minutes: 1);
  static const _reminderClockInterval = Duration(minutes: 1);

  Timer? _timer;
  Timer? _reminderClockTimer;
  Duration? _runningReminderClockInterval;
  final _reminderClock = ValueNotifier<DateTime>(DateTime.now());
  HomeWidgetBridge? _widgets;
  SpotlightBridge? _spotlight;
  late final ReminderService _reminders;
  final _purchases = PurchaseService();
  final _ocr = OcrService();
  late final _location = widget.location ?? LocationService();
  bool _scanning = false;

  /// Küçük kopya geri doldurmasının kapsadığı kayıt sayısı.
  ///
  /// Yeni kayıtların kopyası zaten kaydedilirken üretiliyor; bu geçiş yalnızca
  /// yükseltmeden gelen eski arşiv için. Tarama bittikten sonra her not
  /// yayınında yüzlerce dosya yoklamak boşuna olurdu, ama "bir kez koştu,
  /// bitti" demek de yanlış: **yedek geri yükleme bütün fotoğraf klasörünü
  /// değiştiriyor** ve küçük kopyalar o sırada gidiyor. Sayı değiştiğinde
  /// tarama kendiliğinden yeniden koşuyor.
  int? _thumbnailsCovered;
  bool _fillingThumbnails = false;

  AppSettings _preferences = const AppSettings();
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<List<Note>>? _notesSub;
  List<Note> _notes = const [];
  bool _settingsLoaded = false;
  bool _notesLoaded = false;
  Future<void> _syncQueue = Future<void>.value();
  int _syncRevision = 0;

  @override
  void initState() {
    super.initState();
    _reminders = widget.reminders ?? ReminderService();
    WidgetsBinding.instance.addObserver(this);
    _startSweeping();
    _startReminderClock();
    _reminders.permission.addListener(_onReminderPermissionChanged);
    unawaited(_reminders.refreshPermission());
    _widgets = HomeWidgetBridge(widget.notes)..start();
    _spotlight = SpotlightBridge(widget.notes);
    unawaited(_spotlight?.start());
    _listenForBackgroundWrites();
    unawaited(
      _purchases.start().onError((error, stackTrace) {
        // Mağaza katmanı uygulama yaşam döngüsünü bloke edemez. Özellikle
        // eklentinin bulunmadığı test/masaüstü ortamlarında purchaseStream
        // bağlantısı, servis içindeki sorgulardan önce hata verebilir.
        debugPrint('Satın alma servisi başlatılamadı: $error');
      }),
    );
    _purchases.unlocked.addListener(_cacheEntitlement);

    _settingsSub = widget.settings.watch().listen(
      (value) {
        if (!mounted) return;
        _settingsLoaded = true;
        // Hak kapandığında native widget'ı, dil yüklemesini beklemeden kilitle.
        // İçerik temizliği HomeWidgetBridge'in kendi sıralı yayınında yapılır.
        _widgets?.pro = value.proUnlocked;
        _widgets?.accent = value.accent.onPhotoFor(customHue: value.accentHue);
        // Widget metinlerini native taraf üretiyor ve bir uzantı yalnızca
        // sistem dilini görüyor; uygulama içi seçim ona ancak buradan ulaşır.
        _widgets?.locale = value.locale.locale ?? _deviceLocale();
        // Uzantılar veritabanını açamıyor; Siri konuşurken doğru şeyi
        // söyleyebilmesi için okuyabileceği tek yer bu ayna.
        unawaited(
          SharedImportBridge.setShareMirror(
            proUnlocked: value.proUnlocked,
            reminderEnabled: value.reminderEnabled,
            retentionMinutes:
                RetentionChoice(
                  value.defaultRetention,
                  customMinutes: value.defaultCustomMinutes,
                ).duration?.inMinutes ??
                0,
            // Kurulu ama çalmamış olanlar da düşülüyor: Siri'nin "hakkın var"
            // deyip uygulamanın sonra düşürmesi en kötü sıralama olurdu.
            //
            // Özellik kapalıyken `null` gidiyor, sıfır değil: uzantı için
            // "bilinmiyor" demek ve o hâlde sade Pro kapısına düşüyor. Sıfır
            // göndermek, hiç hakkı olmamış kullanıcıya "hakkın doldu"
            // dedirtirdi.
            freeRemindersLeft: !ProLimits.freeRemindersEnabled
                ? null
                : ProLimits.remainingReminders(
                    value.freeReminderNotes,
                    burnedFloor: widget.notes.freeReminderFloor,
                    inFlight: _pendingReminders
                        .where((id) => !value.freeReminderNotes.contains(id))
                        .length,
                  ),
          ),
        );
        if (value != _preferences) setState(() => _preferences = value);
        _startReminderClock();
        // İlk DB yayını, mağazanın kesin cevabından sonra gelebilir. Notifier bu
        // sırada yeniden değişmeyeceği için yalnız listener'a güvenmek stale bir
        // cache'i yaşatırdı; her ayar yayını son kesin hakla uzlaştırılır.
        _cacheEntitlement();
        _syncRemindersWhenReady();
      },
      onError: (Object error) {
        // Tercihler okunamazsa uygulama varsayılan tema ve dille açılmaya devam
        // ediyor. Yakalanmadan bırakılırsa hata bölgeye düşer ve hiçbir yerde iz
        // bırakmaz.
        debugPrint('Ayarlar akışı okunamadı: $error');
      },
    );

    // Hatırlatmalar not listesi her değiştiğinde baştan kurulur: yeni kayıt,
    // silme, düzenleme ve otomatik temizlik hepsi buradan geçiyor.
    _notesSub = widget.notes.watchNotes().listen(
      (notes) {
        _notes = notes;
        _notesLoaded = true;
        _refreshPendingReminders();
        _syncRemindersWhenReady();
        unawaited(_scanPending());
        unawaited(_fillThumbnails());
      },
      // Arşiv okunamıyorsa hatırlatma programına dokunulmuyor: elde doğru bir
      // liste yokken kurulu bildirimleri yeniden kurmak, okunamayan kayıtları
      // "silinmiş" sayıp hepsini iptal etmek olurdu. Kurulu program olduğu
      // gibi kalsın; kullanıcı hatasını ana ekranda görüyor.
      onError: (Object error) => debugPrint('Arşiv akışı okunamadı: $error'),
    );
  }

  /// Açılışta ayarlar ve notlar iki ayrı Drift akışından gelir.
  ///
  /// Not akışı henüz ilk değerini vermeden boş `_notes` ile senkron yapmak,
  /// teslim edilmiş bütün bildirimleri "silinmiş nota ait" sanabilirdi. Her
  /// iki doğruluk kaynağı da hazır olduktan sonra başlamak bu yarışı kapatır;
  /// sonraki değişiklikler yine anında senkronlanır.
  /// Kurulu ama henüz çalmamış hatırlatmalar.
  ///
  /// Ücretsiz katmanda kalan hak bunları da düşüyor: kullanıcıya "2 hakkın
  /// var" deyip ikincisini kurdurmamak olmaz.
  ///
  /// Not akışı bu ekranı yeniden **çizdirmiyordu** — dinleyici `_notes`'u
  /// sessizce değiştiriyor ve `build` bir daha koşmuyordu. Değeri doğrudan
  /// `build` içinde hesaplamak bu yüzden bayat sayı gösteriyordu; küme burada
  /// tutulup yalnızca gerçekten değiştiğinde çizim isteniyor.
  Set<int> _pendingReminders = const {};

  void _refreshPendingReminders() {
    final now = DateTime.now();
    final next = {
      for (final note in _notes)
        if (note.remindAt case final at?)
          if (at.isAfter(now)) note.id,
    };
    if (setEquals(next, _pendingReminders)) return;
    if (mounted) setState(() => _pendingReminders = next);
  }

  void _syncRemindersWhenReady() {
    if (!_settingsLoaded || !_notesLoaded) return;

    final revision = ++_syncRevision;
    final settings = _preferences;
    final notes = List<Note>.unmodifiable(_notes);

    // Drift'in not ve ayar akışları peş peşe yayın yapabilir. Senkronlar aynı
    // anda çalışırsa eski bir Pro karesi, daha yeni downgrade temizliğinden
    // sonra bildirimleri yeniden kurabilirdi. Kuyruk sıra garantisi verir;
    // henüz başlamamış eski kareler de revision ile atlanır.
    _syncQueue = _syncQueue.then((_) async {
      if (!mounted || revision != _syncRevision) return;
      try {
        await _syncReminders(notes, settings);
      } catch (error) {
        debugPrint('Arka plan senkronu tamamlanamadı: $error');
      }
    });
    unawaited(_syncQueue);
  }

  /// Bildirim düğmeleri uygulamayı açmadan veri yazıyor; o yazma **ayrı bir
  /// Flutter motorunda**, dolayısıyla ayrı bir SQLite bağlantısında oluyor.
  ///
  /// Drift'in akış geçersizleştirmesi süreç içi çalıştığı için o yazma açık
  /// duran uygulamanın kartlarına kendiliğinden yansımaz: kullanıcı bildirimi
  /// "Yarın"a ertelerken uygulama önde duruyorsa, kart hatırlatmanın eski
  /// tarihini göstermeye devam ederdi. Native taraf yazma bittiğinde haber
  /// veriyor ve sorgular yeniden koşuyor.
  static const _reminderActionChannel = MethodChannel(kReminderActionChannel);

  void _listenForBackgroundWrites() {
    _reminderActionChannel.setMethodCallHandler((call) async {
      if (call.method != 'reminderActionApplied' || !mounted) return;
      widget.notes.reloadFromDisk();
    });
  }

  /// Mağaza cevabı Drift'e yazılır — yalnızca **kesin** bir cevap geldiğinde.
  ///
  /// `null` (bilinmiyor) durumunda dokunulmaz: ağ yokken önbelleği sıfırlamak,
  /// parasını ödemiş kullanıcıyı çevrimdışıyken ücretsize düşürürdü.
  void _cacheEntitlement() {
    final value = _purchases.unlocked.value;
    if (value == null) return;
    // Satın alma cevabı ayar satırının ilk Drift yayınıyla yarışabilir.
    // Ayarlar henüz yüklenmediyse varsayılan `false` ile karşılaştırıp dönmek,
    // elle değiştirilmiş/stale bir `true` değerinin veritabanında kalmasına
    // yol açardı. Kesin mağaza sonucunu ilk yüklemeden önce daima yaz.
    if (_settingsLoaded && value == _preferences.proUnlocked) return;
    unawaited(widget.settings.setProUnlocked(value));
  }

  @override
  void dispose() {
    _syncRevision++;
    _timer?.cancel();
    _reminderClockTimer?.cancel();
    // Kanal süreç ömrü boyunca tek; işleyici bırakılmazsa sökülmüş bir
    // kapsamın deposuna yazmaya çalışan bir kapan geride kalır.
    _reminderActionChannel.setMethodCallHandler(null);
    _purchases.unlocked.removeListener(_cacheEntitlement);
    unawaited(_purchases.dispose());
    unawaited(_settingsSub?.cancel());
    unawaited(_notesSub?.cancel());
    unawaited(_widgets?.dispose());
    unawaited(_spotlight?.dispose());
    _reminders.permission.removeListener(_onReminderPermissionChanged);
    unawaited(_reminders.dispose());
    _reminderClock.dispose();
    widget.reviewPrompts?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Telefonun dili değişti.
  ///
  /// Arayüz `MaterialApp` üzerinden kendini yeniden çözümlüyor, ama widget
  /// ağacının dışında metin kuran her yer — bildirimler, Spotlight ve ana
  /// ekran widget'ı — kendi dil kopyasını taşıyor. Kullanıcı "Sistem"i
  /// seçtiyse bu kopyalar da tazelenmeli; açıkça bir dil seçtiyse sistemin
  /// değişmesi onları hiç ilgilendirmiyor.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_preferences.locale != AppLocale.system) return;
    _widgets?.locale = _deviceLocale();
    _syncRemindersWhenReady();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Saat dilimi ancak uygulama arkadayken değişebilir; okuma da yalnız
        // burada tazeleniyor.
        _reminders.invalidateTimeZone();
        _startSweeping();
        _startReminderClock(force: true);
        // Uygulama arkadayken bir bildirim düğmesine basılmış olabilir; o
        // yazma bu bağlantının akışlarına ulaşmadı.
        widget.notes.reloadFromDisk();
        // Kullanıcı sistem ayarlarından bildirim iznini değiştirmiş olabilir.
        // Uygulama döner dönmez programı gerçek izin durumuyla yeniden kur.
        _syncRemindersWhenReady();
        unawaited(_reminders.refreshPermission());
        // Kullanıcı mağazadan iade almış olabilir; her dönüşte yeniden sor.
        unawaited(_purchases.refreshEntitlement());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _timer?.cancel();
        _timer = null;
        _reminderClockTimer?.cancel();
        _reminderClockTimer = null;
        _runningReminderClockInterval = null;
    }
  }

  /// Bildirim metinleri widget ağacının dışında kuruluyor; bu yüzden [L10n]
  /// örneği yürürlükteki dil için elle yüklenir.
  ///
  /// Kullanıcı "Sistem" seçtiyse telefonun dili alınır ve desteklenmiyorsa
  /// İngilizce'ye düşülür — arayüzdeki çözümlemenin aynısı.
  Future<void> _syncReminders(List<Note> notes, AppSettings settings) async {
    final locale = settings.locale.locale ?? _deviceLocale();
    final l10n = await L10n.delegate.load(locale);
    // Widget köprüsüne buradan l10n geçilmiyor: zamana bağlı her metni native
    // taraf kendi üretiyor, köprü yalnızca ham anı ve dil etiketini gönderiyor
    // (bkz. ayarlar dinleyicisindeki `_widgets?.locale`).
    _spotlight?.l10n = l10n;
    // Bildirime iliştirilecek kareyi depo çözüyor; servis depoyu tanımıyor.
    _reminders.photoOf = widget.notes.imageOf;
    // Silinmeyen hak tabanı senkrondan **önce** okunuyor: kapı kararını
    // eksik bir tabanla vermesin.
    //
    // Pro'da çağrı **hiç yapılmıyor**. Deponun kendi Pro kontrolü de var ama
    // o bir veritabanı sorgusu; ayarlar zaten elimizdeyken onu her senkronda
    // ödemenin anlamı yok.
    if (!settings.proUnlocked) await widget.notes.loadFreeReminderFloor();
    await _reminders.sync(notes, settings, l10n);
    // Ücretsiz hak kurulumda değil **teslimde** yanıyor. Senkron her öne
    // dönüşte ve her kayıt değişiminde koştuğu için hesap da burada kapanıyor;
    // ayrı bir zamanlayıcı, uygulamanın zaten yaptığı işi tekrarlardı.
    //
    // İzin durumu senkronun kendi okumasından geliyor: bildirim gösterilmeden
    // hak yakılmaz.
    await widget.notes.settleFreeReminders(
      permissionGranted:
          _reminders.permission.value == ReminderPermissionState.granted,
    );
  }

  Locale _deviceLocale() =>
      resolveSupportedLocale(WidgetsBinding.instance.platformDispatcher.locale);

  /// Taranmamış kareleri arkada okur.
  ///
  /// Kaydetme akışına hiç dokunmuyor: kullanıcı notunu yazıp çıkıyor, tarama
  /// liste her değiştiğinde birer birer ilerliyor. Eski kayıtlar da böylece
  /// kullanıcıdan bir şey istemeden indeksleniyor.
  /// Küçük kopyası olmayan eski kayıtlar için kopyayı arkada üretir.
  ///
  /// Yükseltmeden gelen kullanıcının arşivinde tek bir kopya yok. Izgara o
  /// kayıtlar için tam kareyi çizmeye devam ediyor — yani hiçbir şey eksik
  /// görünmüyor, yalnızca o kadarı yavaş. Kopyalar üretildikçe akış
  /// kendiliğinden hızlanıyor.
  ///
  /// En yeniden başlanıyor: kullanıcının ilk göreceği kareler onlar.
  ///
  /// İki fren var ve ikisi de deneyimden geldi. **Açılışta hemen
  /// başlamıyor:** önbellek boşken görünen kareler zaten çözülüyor, üretimi
  /// aynı ana koymak ikisini yarıştırıp açılışta kareleri geç getiriyordu.
  /// **Kareler arasında nefes veriyor:** küçültme yerel tarafta arka plan
  /// kuyruğunda koşsa da aynı işlemciyi paylaşıyor; ardışık bin çağrıyı
  /// olabildiğince hızlı kuyruğa vermek kaydırmayı hissedilir biçimde
  /// bozuyordu.
  static const _thumbnailWarmup = Duration(seconds: 3);
  static const _thumbnailBreath = Duration(milliseconds: 8);

  Future<void> _fillThumbnails() async {
    if (_fillingThumbnails || !widget.notes.canThumbnail) return;
    final notes = List<Note>.unmodifiable(_notes);
    if (_thumbnailsCovered == notes.length) return;

    // Eksik yoksa beklemeye de gerek yok: tamamlanmış bir arşivde bu tarama
    // yalnızca dosya yoklamasından ibaret kalıyor.
    final missing = [
      for (final note in notes)
        if (!widget.notes.hasThumbnail(note)) note,
    ];
    if (missing.isEmpty) {
      _thumbnailsCovered = notes.length;
      return;
    }

    _fillingThumbnails = true;
    try {
      await Future<void>.delayed(_thumbnailWarmup);
      for (final note in missing) {
        if (!mounted) return;
        await widget.notes.ensureThumbnail(note);
        await Future<void>.delayed(_thumbnailBreath);
      }
      _thumbnailsCovered = notes.length;
    } catch (error) {
      // Bir sonraki oturumda yeniden denenir; ızgara bu arada tam kareyi
      // çizmeye devam ettiği için kullanıcı bir eksiklik görmüyor.
      debugPrint('Küçük kopyalar üretilemedi: $error');
    } finally {
      _fillingThumbnails = false;
    }
  }

  Future<void> _scanPending() async {
    if (_scanning || !_ocr.supported) return;
    _scanning = true;

    try {
      final pending = await widget.notes.unscanned();
      for (final note in pending) {
        if (!mounted) return;
        final file = widget.notes.imageOf(note);
        final started = DateTime.now();
        final text = await _ocr.read(file);
        final elapsed = DateTime.now().difference(started).inMilliseconds;

        // Okunamadıysa metin yazılmaz, yalnızca deneme sayacı artar: kayıt
        // sırada kalır ama sonsuza dek denenmez. Boş dize yazmak, modelin
        // henüz inmediği ilk anı kalıcı bir "yazı yok" kararına çevirirdi.
        await widget.notes.saveScan(note.id, text);
        // Tarama `notes` tablosuna dokunmuyor — dokunsaydı her okunan kare
        // bütün listeyi yeniden kurdururdu. Bu yüzden indeksin haberi
        // buradan gidiyor.
        _spotlight?.scanCompleted();

        // Günlüğe metnin kendisi değil ölçüsü giriyor: OCR görünmez bir alana
        // yazdığı için gözlemlenebilir kalması gerekiyor, ama sayfa dolusu
        // yazıyı her karede log'a basmak tek başına taramayı yavaşlatıyordu.
        debugPrint(
          '[OCR] not=${note.id} sure=${elapsed}ms '
          '${text == null ? 'okunamadi, sonra denenecek' : 'uzunluk=${text.length}'}',
        );
      }
    } catch (error) {
      debugPrint('Kareler taranamadı: $error');
    } finally {
      _scanning = false;
    }
  }

  void _startSweeping() {
    _timer?.cancel();
    unawaited(_purgeExpired());
    _timer = Timer.periodic(_sweepInterval, (_) => unawaited(_purgeExpired()));
  }

  /// Süresi dolan kayıtları temizler; başarısızlığı yutar.
  ///
  /// Bu bir **bakım** turu: arşiv o an okunamıyorsa yapılacak şey bir sonraki
  /// turu beklemek. Yakalanmayan hata bölgeye düşüyor, dakikada bir
  /// tekrarlanıyor ve gerçekten bakılması gereken hataları gürültüye
  /// gömüyordu.
  Future<void> _purgeExpired() async {
    try {
      await widget.notes.purgeExpired(
        reminderPermissionGranted:
            _reminders.permission.value == ReminderPermissionState.granted,
      );
    } on Object catch (error) {
      debugPrint('Süresi dolan kayıtlar temizlenemedi: $error');
    }
  }

  void _onReminderPermissionChanged() {
    if (mounted) setState(() {});
  }

  void _startReminderClock({bool force = false}) {
    const interval = _reminderClockInterval;
    if (!force &&
        _reminderClockTimer != null &&
        _runningReminderClockInterval == interval) {
      return;
    }

    _reminderClockTimer?.cancel();
    _runningReminderClockInterval = interval;
    _reminderClock.value = DateTime.now();
    _reminderClockTimer = Timer.periodic(interval, (_) {
      _reminderClock.value = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _RepositoryScope(
      notes: widget.notes,
      settings: widget.settings,
      backups: widget.backups,
      reviewPrompts: widget.reviewPrompts,
      reminders: _reminders,
      location: _location,
      purchases: _purchases,
      preferences: _preferences,
      pendingReminderNoteIds: _pendingReminders,
      freeReminderFloor: widget.notes.freeReminderFloor,
      reminderPermission: _reminders.permission.value,
      reminderClock: _reminderClock,
      archiveRepair:
          widget.onRepairArchive == null ||
              widget.countRecoverableFrames == null
          ? null
          : ArchiveRepair(
              count: widget.countRecoverableFrames!,
              repair: widget.onRepairArchive!,
            ),
      child: widget.child,
    );
  }
}

class _RepositoryScope extends InheritedWidget {
  const _RepositoryScope({
    required this.notes,
    required this.settings,
    required this.backups,
    required this.reviewPrompts,
    required this.reminders,
    required this.location,
    required this.purchases,
    required this.preferences,
    required this.pendingReminderNoteIds,
    required this.freeReminderFloor,
    required this.reminderPermission,
    required this.reminderClock,
    required this.archiveRepair,
    required super.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final BackupService? backups;
  final ReviewPromptService? reviewPrompts;
  final ReminderService reminders;
  final LocationService location;
  final PurchaseService purchases;
  final AppSettings preferences;

  /// Kurulu ama henüz çalmamış hatırlatmaların kayıt kimlikleri.
  final Set<int> pendingReminderNoteIds;

  /// Yeniden kurulumdan sonra da duran hak tabanı.
  final int freeReminderFloor;

  final ReminderPermissionState reminderPermission;
  final ArchiveRepair? archiveRepair;
  final ValueListenable<DateTime> reminderClock;

  @override
  bool updateShouldNotify(_RepositoryScope old) =>
      old.notes != notes ||
      old.settings != settings ||
      old.preferences != preferences ||
      old.reminderPermission != reminderPermission ||
      !setEquals(old.pendingReminderNoteIds, pendingReminderNoteIds) ||
      old.freeReminderFloor != freeReminderFloor ||
      old.archiveRepair != archiveRepair;
}

/// Okunamayan arşivin onarım yolu.
///
/// İki parça ayrılmaz: kaç kare kurtarılacağını **önce** söylemeden onarımı
/// başlatmak, kullanıcıdan sonucunu görmediği bir karar istemek olurdu.
final class ArchiveRepair {
  const ArchiveRepair({required this.count, required this.repair});

  /// Diskte kurtarılabilecek kare sayısı.
  final Future<int> Function() count;

  /// Onarımı yürütür; kurtarılan kare sayısını döner.
  final Future<int> Function() repair;
}

/// Bildirim izni istemek için servise erişim.
extension ReminderAccess on BuildContext {
  ReminderService get reminders =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.reminders;
}

extension BackupAccess on BuildContext {
  BackupService get backups {
    final service =
        dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.backups;
    assert(service != null, 'BackupService, AppScope içine bağlanmadı.');
    return service!;
  }
}

/// Başarılı yeni kayıtların ardından ölçülü değerlendirme isteği için erişim.
/// Test/önizleme ağaçlarında servis bağlanmayabilir; not kaydı bundan bağımsız
/// kalır.
extension ReviewPromptAccess on BuildContext {
  ReviewPromptService? get reviewPrompts =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()?.reviewPrompts;
}

/// Konum servisine erişim.
extension LocationAccess on BuildContext {
  LocationService get location =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.location;
}

/// Mağaza servisine erişim.
extension PurchaseAccess on BuildContext {
  PurchaseService get purchases =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.purchases;
}
