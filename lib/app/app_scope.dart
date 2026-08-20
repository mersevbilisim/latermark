import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../features/home_widget/home_widget_bridge.dart';
import '../features/backup/data/backup_service.dart';
import '../features/notes/data/notes_database.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/presentation/import/shared_import.dart';
import '../features/notes/data/location_service.dart';
import '../features/notes/data/ocr_service.dart';
import '../features/paywall/data/purchase_service.dart';
import '../features/reminders/reminder_action_handler.dart';
import '../features/reminders/reminder_service.dart';
import '../features/review/review_prompt_service.dart';
import '../features/settings/data/settings_repository.dart';
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
    required this.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final BackupService? backups;
  final ReviewPromptService? reviewPrompts;

  /// Varsayılan olarak gerçek platform servisi kullanılır. Testler izin ve
  /// sabitleme yarışlarını deterministik bir servisle doğrulayabilir.
  final LocationService? location;
  final Widget child;

  static NotesRepository of(BuildContext context) => _scope(context).notes;

  static SettingsRepository settingsOf(BuildContext context) =>
      _scope(context).settings;

  /// Yürürlükteki tercihler. Değiştiğinde dinleyen widget yeniden kurulur.
  static AppSettings preferences(BuildContext context) =>
      _scope(context).preferences;

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

  Timer? _timer;
  HomeWidgetBridge? _widgets;
  SpotlightBridge? _spotlight;
  final _reminders = ReminderService();
  final _purchases = PurchaseService();
  final _ocr = OcrService();
  late final _location = widget.location ?? LocationService();
  bool _scanning = false;

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
    WidgetsBinding.instance.addObserver(this);
    _startSweeping();
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

    _settingsSub = widget.settings.watch().listen((value) {
      if (!mounted) return;
      _settingsLoaded = true;
      // Hak kapandığında native widget'ı, dil yüklemesini beklemeden kilitle.
      // İçerik temizliği HomeWidgetBridge'in kendi sıralı yayınında yapılır.
      _widgets?.pro = value.proUnlocked;
      _widgets?.accent = value.accent;
      unawaited(SharedImportBridge.setProUnlocked(value.proUnlocked));
      if (value != _preferences) setState(() => _preferences = value);
      // İlk DB yayını, mağazanın kesin cevabından sonra gelebilir. Notifier bu
      // sırada yeniden değişmeyeceği için yalnız listener'a güvenmek stale bir
      // cache'i yaşatırdı; her ayar yayını son kesin hakla uzlaştırılır.
      _cacheEntitlement();
      _syncRemindersWhenReady();
    });

    // Hatırlatmalar not listesi her değiştiğinde baştan kurulur: yeni kayıt,
    // silme, düzenleme ve otomatik temizlik hepsi buradan geçiyor.
    _notesSub = widget.notes.watchNotes().listen((notes) {
      _notes = notes;
      _notesLoaded = true;
      _syncRemindersWhenReady();
      unawaited(_scanPending());
    });
  }

  /// Açılışta ayarlar ve notlar iki ayrı Drift akışından gelir.
  ///
  /// Not akışı henüz ilk değerini vermeden boş `_notes` ile senkron yapmak,
  /// teslim edilmiş bütün bildirimleri "silinmiş nota ait" sanabilirdi. Her
  /// iki doğruluk kaynağı da hazır olduktan sonra başlamak bu yarışı kapatır;
  /// sonraki değişiklikler yine anında senkronlanır.
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
    // Kanal süreç ömrü boyunca tek; işleyici bırakılmazsa sökülmüş bir
    // kapsamın deposuna yazmaya çalışan bir kapan geride kalır.
    _reminderActionChannel.setMethodCallHandler(null);
    _purchases.unlocked.removeListener(_cacheEntitlement);
    unawaited(_purchases.dispose());
    unawaited(_settingsSub?.cancel());
    unawaited(_notesSub?.cancel());
    unawaited(_widgets?.dispose());
    unawaited(_spotlight?.dispose());
    unawaited(_reminders.dispose());
    widget.reviewPrompts?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startSweeping();
        // Uygulama arkadayken bir bildirim düğmesine basılmış olabilir; o
        // yazma bu bağlantının akışlarına ulaşmadı.
        widget.notes.reloadFromDisk();
        // Kullanıcı sistem ayarlarından bildirim iznini değiştirmiş olabilir.
        // Uygulama döner dönmez programı gerçek izin durumuyla yeniden kur.
        _syncRemindersWhenReady();
        // Kullanıcı mağazadan iade almış olabilir; her dönüşte yeniden sor.
        unawaited(_purchases.refreshEntitlement());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _timer?.cancel();
        _timer = null;
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
    _widgets?.l10n = l10n;
    _spotlight?.l10n = l10n;
    // Bildirime iliştirilecek kareyi depo çözüyor; servis depoyu tanımıyor.
    _reminders.photoOf = widget.notes.imageOf;
    await _reminders.sync(notes, settings, l10n);
  }

  Locale _deviceLocale() =>
      resolveSupportedLocale(WidgetsBinding.instance.platformDispatcher.locale);

  /// Taranmamış kareleri arkada okur.
  ///
  /// Kaydetme akışına hiç dokunmuyor: kullanıcı notunu yazıp çıkıyor, tarama
  /// liste her değiştiğinde birer birer ilerliyor. Eski kayıtlar da böylece
  /// kullanıcıdan bir şey istemeden indeksleniyor.
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
    unawaited(widget.notes.purgeExpired());
    _timer = Timer.periodic(
      _sweepInterval,
      (_) => unawaited(widget.notes.purgeExpired()),
    );
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

  @override
  bool updateShouldNotify(_RepositoryScope old) =>
      old.notes != notes ||
      old.settings != settings ||
      old.preferences != preferences;
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
