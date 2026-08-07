import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/home_widget/home_widget_bridge.dart';
import '../features/notes/data/notes_database.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/data/ocr_service.dart';
import '../features/paywall/data/purchase_service.dart';
import '../features/reminders/reminder_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../l10n/app_localizations.dart';

/// Uygulamanın çalışan parçalarını ağaca taşıyan kapsam.
///
/// Üç arka plan işini de o yönetir:
/// * "otomatik sil" sözünü tutan zamanlayıcı — açılışta, her öne gelişte ve
///   önplandayken dakikada bir süresi dolmuş notları temizler,
/// * ana ekran widget'ını besleyen köprü,
/// * "bir süredir bakmadın" hatırlatıcıları.
///
/// Bu iş için harici bir durum yönetimi paketine gerek yok.
class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.notes,
    required this.settings,
    required this.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
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
  final _reminders = ReminderService();
  final _purchases = PurchaseService();
  final _ocr = OcrService();
  bool _scanning = false;

  AppSettings _preferences = const AppSettings();
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<List<Note>>? _notesSub;
  List<Note> _notes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSweeping();
    _widgets = HomeWidgetBridge(widget.notes)..start();
    unawaited(_purchases.start());
    _purchases.unlocked.addListener(_cacheEntitlement);

    _settingsSub = widget.settings.watch().listen((value) {
      if (!mounted || value == _preferences) return;
      setState(() => _preferences = value);
      unawaited(_syncReminders(value));
    });

    // Hatırlatmalar not listesi her değiştiğinde baştan kurulur: yeni kayıt,
    // silme, düzenleme ve otomatik temizlik hepsi buradan geçiyor.
    _notesSub = widget.notes.watchNotes().listen((notes) {
      _notes = notes;
      unawaited(_syncReminders(_preferences));
      unawaited(_scanPending());
    });
  }

  /// Mağaza cevabı Drift'e yazılır — yalnızca **kesin** bir cevap geldiğinde.
  ///
  /// `null` (bilinmiyor) durumunda dokunulmaz: ağ yokken önbelleği sıfırlamak,
  /// parasını ödemiş kullanıcıyı çevrimdışıyken ücretsize düşürürdü.
  void _cacheEntitlement() {
    final value = _purchases.unlocked.value;
    if (value == null) return;
    if (value == _preferences.proUnlocked) return;
    unawaited(widget.settings.setProUnlocked(value));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _purchases.unlocked.removeListener(_cacheEntitlement);
    unawaited(_purchases.dispose());
    unawaited(_settingsSub?.cancel());
    unawaited(_notesSub?.cancel());
    unawaited(_widgets?.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startSweeping();
        // Kullanıcı sistem ayarlarından bildirim iznini değiştirmiş olabilir.
        // Uygulama döner dönmez programı gerçek izin durumuyla yeniden kur.
        unawaited(_syncReminders(_preferences));
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
  Future<void> _syncReminders(AppSettings settings) async {
    final locale = settings.locale.locale ?? _deviceLocale();
    final l10n = await L10n.delegate.load(locale);
    _widgets?.l10n = l10n;
    _widgets?.pro = settings.proUnlocked;
    await _reminders.sync(_notes, settings, l10n);
  }

  Locale _deviceLocale() {
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    for (final locale in L10n.supportedLocales) {
      if (locale.languageCode == device.languageCode &&
          locale.countryCode == device.countryCode) {
        return locale;
      }
    }
    for (final locale in L10n.supportedLocales) {
      if (locale.languageCode == device.languageCode) return locale;
    }
    return const Locale('en');
  }

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

        // Okunamadıysa hiçbir şey yazma: sütun `null` kalsın ki bir sonraki
        // taramada yeniden denensin. Boş dize yazmak, modelin henüz inmediği
        // ilk anı kalıcı bir "yazı yok" kararına çevirirdi.
        if (text == null) {
          debugPrint('[OCR] not=${note.id} okunamadi, sonra denenecek');
          continue;
        }

        await widget.notes.saveOcrText(note.id, text);

        // Geliştirme günlüğü: OCR görünmez bir alana yazdığı için sonucu
        // ekranda doğrulamanın başka yolu yok. Hem okunanı hem de veritabanına
        // yazılanı basıyoruz ki ikisi ayrışırsa fark edilsin.
        debugPrint(
          '[OCR] not=${note.id} sure=${elapsed}ms '
          'uzunluk=${text.length} dosya=${file.path}',
        );
        debugPrint('[OCR] okunan="$text"');

        final saved = await widget.notes.noteById(note.id);
        debugPrint('[OCR] dbye yazilan="${saved?.ocrText}"');
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
      reminders: _reminders,
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
    required this.reminders,
    required this.purchases,
    required this.preferences,
    required super.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final ReminderService reminders;
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

/// Mağaza servisine erişim.
extension PurchaseAccess on BuildContext {
  PurchaseService get purchases =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.purchases;
}
