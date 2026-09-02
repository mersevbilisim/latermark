import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../../l10n/supported_locale.dart';
import '../notes/data/notes_database.dart';
import '../notes/domain/note_reminder.dart';
import '../notes/domain/reminder_action.dart';
import '../settings/domain/app_settings.dart';
import 'reminder_action_handler.dart';

/// Veritabanındaki hatırlatma niyetinden ayrı, işletim sisteminin teslimat
/// hakkı. `unknown` bir ret değildir; eklenti henüz hazır olmayabilir veya
/// geçici bir platform hatası yaşanmış olabilir.
enum ReminderPermissionState { unknown, granted, denied }

/// Kullanıcının açıkça istediği hatırlatmaları kurar.
///
/// Hatırlatma **not başına** ve **opt-in**: yalnızca kaydederken gün sayısı
/// verilmiş notlar için bildirim planlanır, kaydın oluşturulma anından o kadar
/// gün sonrasına, aynı saate.
///
/// Eskiden her nota otomatik kurulurdu ve zamanı "en son bakılan an"dan
/// sayılırdı. Yüzlerce kaydı olan biri bakmadığı her kare için bildirim
/// alıyordu — üstelik iOS aynı anda yalnızca **64** bekleyen bildirim tuttuğu
/// için fazlası sessizce düşüyordu. İstemek artık kullanıcının kararı.
class ReminderService {
  ReminderService({bool? supported}) : _supportedOverride = supported;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _noteTaps = StreamController<int>.broadcast();
  final _permission = ValueNotifier<ReminderPermissionState>(
    ReminderPermissionState.unknown,
  );
  final bool? _supportedOverride;

  static const _settingsChannel = MethodChannel('latermark/app_settings');
  static const _actionChannel = MethodChannel('latermark/reminder_actions');

  bool _ready = false;
  bool _disposed = false;
  Future<void>? _initialization;
  Future<ReminderPermissionState>? _permissionRead;
  Future<ReminderPermissionState>? _permissionRequest;
  int _permissionRevision = 0;
  int? _pendingNoteId;

  ValueListenable<ReminderPermissionState> get permission => _permission;

  /// Bildirim düğmelerinin hangi dille kurulduğu.
  ///
  /// Başlıklar `UNNotificationCategory` içinde **sabit metin** olarak
  /// yaşıyor; işletim sistemi onları bildirim çalarken çevirmiyor. Kullanıcı
  /// dili değiştirdiğinde kategori yeniden kurulmazsa düğmeler eski dilde
  /// kalırdı.
  String? _categoryLocale;

  /// v2, 64 kimliklik oluşum aralığını ve native süresiz tekrarları kullanır.
  /// Kanal kimliği Android'de aktif bir bildirimin eski (/8) ya da yeni (/64)
  /// kimlik şemasıyla çözülmesini de sağlar.
  /// v3 uygulamanın kendi sesini taşıyor.
  ///
  /// Kanal kimliği yükseltildi çünkü **Android kanal ayarlarını kanal ilk
  /// kurulduğunda dondurur**: var olan bir kanalın sesini değiştirmek hiçbir
  /// işe yaramaz, kullanıcı sistem ayarından elle değiştirene kadar eski ses
  /// çalmaya devam eder. Yeni ses ancak yeni bir kanalla duyulur.
  static const _channelId = 'latermark_reminders_v3';

  /// Yükseltmede silinen eski kanallar. Silinmezlerse sistem ayarlarında
  /// yan yana üç "Hatırlatmalar" satırı kalır.
  static const _retiredChannelIds = <String>[
    'latermark_reminders_v2',
    'latermark_reminders',
  ];

  /// Kimlik şeması v2'de değişmişti; v2 kanalındaki hâlâ açık bir bildirim
  /// yeni şemayla çözülür.
  static const _v2ChannelId = 'latermark_reminders_v2';
  static const _legacyChannelId = 'latermark_reminders';
  static const _legacyOccurrenceSpan = 8;

  /// Uygulamanın kendi bildirim sesi.
  ///
  /// iOS'ta dosya uygulama paketinde (`ios/Runner/`, Runner hedefine kayıtlı),
  /// Android'de `res/raw/` altında durur ve uzantısız adıyla anılır.
  static const _soundName = 'notification';
  static const _iosSoundFile = 'notification.wav';

  /// Tek atış ve tekrar ayrı düğme takımları kullanır.
  ///
  /// iOS'un periyodik tetikleyicisi, “ilk kez yarın/haftaya, sonra özel N gün
  /// arayla” sözünü ifade edemiyor. Tekrarlı bildirimde bu iki eylemi göstermek
  /// yanlış bir tarih vaat ederdi; orada yalnız bu turu tamamlama ve nota ait
  /// hatırlatmayı tamamen kapatma seçenekleri vardır.
  static const _onceCategoryId = 'latermark.reminder.once';
  static const _repeatCategoryId = 'latermark.reminder.repeat';

  bool get _supported =>
      _supportedOverride ?? (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Eklentinin hangi platform uygulamasını çözeceği.
  ///
  /// `Platform.isIOS` yerine bunu kullanmak şart:
  /// `resolvePlatformSpecificImplementation` dallanmasını
  /// [defaultTargetPlatform] üzerinden yapıyor. İkisi gerçek cihazda hep aynı
  /// şeyi söylüyor, ama ayrıştıkları yerde izin sorgusu var olmayan bir
  /// uygulamaya sorup sessizce "izin yok" cevabı üretir — ve o cevap bütün
  /// programı iptal eder.
  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Bildirim dokunuşlarını not kimliği olarak dinler.
  ///
  /// Soğuk açılış bilgisi widget ağacı kurulmadan gelebilir. Böyle bir ilk
  /// dokunuş kaybolmaz; ilk dinleyici bağlandığı anda bir kez teslim edilir.
  StreamSubscription<int> listenNoteTaps(void Function(int noteId) onTap) {
    final subscription = _noteTaps.stream.listen(onTap);
    final pending = _pendingNoteId;
    _pendingNoteId = null;
    if (pending != null) onTap(pending);
    return subscription;
  }

  Future<void> initialize() {
    if (_ready || _disposed || !_supported) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      await _configureTimeZone();

      // Düğme başlıkları kurulum anında sabitleniyor, ama bu ilk kurulum
      // ayarların Drift'ten gelmesini bekleyemez: soğuk açılışta hangi
      // bildirimin uygulamayı açtığını sormak için servis hemen hazır olmalı.
      // Bu yüzden burada telefonun dili kullanılıyor; kullanıcı ayarlardan
      // başka bir dil seçmişse ilk [sync] kategoriyi yeniden kuruyor.
      await _registerPlugin(await _deviceL10n());

      await _retireOldChannels();

      final launch = await _plugin.getNotificationAppLaunchDetails();
      _ready = true;
      if (launch?.didNotificationLaunchApp ?? false) {
        _emitPayload(launch?.notificationResponse?.payload);
      }
    } catch (_) {
      // Başlatma başarısızsa sonraki yaşam döngüsü/senkron çağrısı yeniden
      // deneyebilsin; tamamlanmamış Future kalıcı kilit olmasın.
      _initialization = null;
      rethrow;
    }
  }

  /// Yerel bölge gerçekten çözüldü mü.
  ///
  /// UTC'ye düşmek sessiz ama pahalı bir hata: tek atışlı kayıt mutlak anla
  /// yine doğru kurulur, ama **tekrarlı** kayıt iki platformda da takvim
  /// bileşenleri kullanıyor ve saat/dakikayı yerel bölgeden okuyor.
  /// Bölge UTC kalırsa günlük hatırlatma, kullanıcının seçtiği saatte değil
  /// UTC farkı kadar kaymış bir saatte çalar.
  bool _timeZoneResolved = false;

  Future<void> _configureTimeZone() async {
    try {
      final identifier = await _actionChannel.invokeMethod<String>(
        'timeZoneIdentifier',
      );
      if (identifier == null) throw StateError('Saat dilimi bulunamadı.');
      tz.setLocalLocation(tz.getLocation(identifier));
      _timeZoneResolved = true;
      debugPrint('Yerel saat dilimi: $identifier');
    } on Object catch (error) {
      debugPrint('Yerel saat dilimi çözülemedi: $error');
      // Daha önce doğru bir bölge bulunduysa geçici kanal hatası onu UTC
      // ile ezmesin. Hiç çözülememiş soğuk açılışta güvenli taban UTC'dir.
      if (!_timeZoneResolved) tz.setLocalLocation(tz.UTC);
    }
  }

  /// Eklentiyi kurar ve bildirim düğmelerini o dilde kaydeder.
  ///
  /// İkinci kez çağrılması güvenli ve bilinçli: kategori kaydının **tek**
  /// yolu `initialize`. iOS tarafında izin bayraklarının üçü de kapalı
  /// olduğu için yeniden çağrı bir izin istemi doğurmuyor, yalnızca
  /// `setNotificationCategories` yeniden koşuyor.
  Future<void> _registerPlugin(L10n l10n) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // İzin, kullanıcı ayarı açtığında açıkça istenir; açılışta değil.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [_onceCategory(l10n), _repeatCategory(l10n)],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        _emitPayload(response.payload);
      },
      // Düğmeler uygulamayı **açmadan** iş yapıyor; işletim sistemi cevabı
      // ayrı, başsız bir Flutter motoruna teslim ediyor. Giriş noktası
      // derleyici tarafından budanmasın diye `vm:entry-point` taşıyor.
      onDidReceiveBackgroundNotificationResponse:
          handleReminderActionInBackground,
    );
    _categoryLocale = l10n.localeName;
  }

  /// Tek atışlı bildirimin dört düğmesi.
  ///
  /// Hiçbiri `foreground` değil: eylemlerin bütün değeri uygulamayı açmadan
  /// iş bitirmesinde. `foreground` verilseydi iOS her dokunuşta uygulamayı
  /// öne getirirdi ve düğmelerin varlık sebebi kalmazdı.
  static DarwinNotificationCategory _onceCategory(L10n l10n) =>
      DarwinNotificationCategory(
        _onceCategoryId,
        actions: [
          DarwinNotificationAction.plain(
            ReminderAction.done.id,
            l10n.reminderActionDone,
          ),
          DarwinNotificationAction.plain(
            ReminderAction.tomorrow.id,
            l10n.reminderActionTomorrow,
          ),
          DarwinNotificationAction.plain(
            ReminderAction.nextWeek.id,
            l10n.reminderActionNextWeek,
          ),
          _turnOffAction(l10n),
        ],
      );

  /// Tekrarlı bildirimin desteklenen iki dürüst eylemi.
  static DarwinNotificationCategory _repeatCategory(L10n l10n) =>
      DarwinNotificationCategory(
        _repeatCategoryId,
        actions: [
          DarwinNotificationAction.plain(
            ReminderAction.done.id,
            l10n.reminderActionDone,
          ),
          _turnOffAction(l10n),
        ],
      );

  static DarwinNotificationAction _turnOffAction(L10n l10n) =>
      DarwinNotificationAction.plain(
        ReminderAction.turnOff.id,
        l10n.reminderActionTurnOff,
        options: const {DarwinNotificationActionOption.destructive},
      );

  static Future<L10n> _deviceL10n() =>
      L10n.delegate.load(resolveSupportedLocale(_deviceLocale));

  static ui.Locale get _deviceLocale => ui.PlatformDispatcher.instance.locale;

  /// Yükseltmede geride kalan kanalları siler.
  ///
  /// Android kanal ayarlarını ilk kurulumda donduruyor, o yüzden ses
  /// değişince kanal kimliği de yükseliyor. Eskisi silinmezse kullanıcının
  /// bildirim ayarlarında yan yana birkaç "Hatırlatmalar" satırı kalır ve
  /// hangisinin çalıştığı belli olmaz.
  ///
  /// Sessizce geçilebilir bir iş: silinemezse yalnızca fazladan bir satır
  /// kalır, hatırlatmaların kendisi etkilenmez.
  Future<void> _retireOldChannels() async {
    if (!_isAndroid) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      for (final id in _retiredChannelIds) {
        await android.deleteNotificationChannel(channelId: id);
      }
    } on PlatformException catch (error) {
      debugPrint('Eski bildirim kanalı silinemedi: $error');
    }
  }

  void _emitPayload(String? payload) {
    final noteId = noteIdFromReminderPayload(payload);
    if (noteId == null || _disposed) return;
    if (_noteTaps.hasListener) {
      _noteTaps.add(noteId);
    } else {
      _pendingNoteId = noteId;
    }
  }

  /// Kullanıcı hatırlatıcıyı açtığında çağrılır.
  ///
  /// İzin verilirse `true` döner. Reddedilme veya geçici bilinmezlikte
  /// kullanıcı niyetini silip silmemek çağıranın kararıdır; servis yalnızca
  /// işletim sistemi sonucunu paylaşır.
  Future<bool> requestPermission() async {
    final state = await requestPermissionState();
    return state == ReminderPermissionState.granted;
  }

  Future<ReminderPermissionState> requestPermissionState() =>
      _requestPermissionState();

  /// İşletim sisteminin uygulamaya şu anda bildirim gönderebilme hakkı verip
  /// vermediğini okur. Kullanıcı izni daha sonra Ayarlar'dan kapatmış olabilir.
  Future<bool> hasPermission() async {
    final state = await refreshPermission();
    return state == ReminderPermissionState.granted;
  }

  /// İzni okur ve yalnız kesin `granted/denied` sonucunu paylaşılan duruma
  /// yazar. `null`, eksik eklenti ve geçici hatalar son kesin bilgiyi silmez.
  Future<ReminderPermissionState> refreshPermission() {
    if (_disposed || !_supported) {
      return Future.value(ReminderPermissionState.unknown);
    }
    final requesting = _permissionRequest;
    if (requesting != null) return requesting;
    final reading = _permissionRead;
    if (reading != null) return reading;

    late final Future<ReminderPermissionState> operation;
    operation = _readPermission().whenComplete(() {
      if (identical(_permissionRead, operation)) _permissionRead = null;
    });
    return _permissionRead = operation;
  }

  Future<ReminderPermissionState> _readPermission() async {
    final revision = ++_permissionRevision;
    ReminderPermissionState result;
    try {
      await initialize();
      result = _isIos
          ? await _readIosPermission()
          : _isAndroid
          ? await _readAndroidPermission()
          : ReminderPermissionState.unknown;
    } on MissingPluginException catch (error) {
      debugPrint('Bildirim izni okunamadı: $error');
      result = ReminderPermissionState.unknown;
    } on PlatformException catch (error) {
      debugPrint('Bildirim izni okunamadı: $error');
      result = ReminderPermissionState.unknown;
    } on Object catch (error) {
      debugPrint('Bildirim servisi izin sorgusuna hazırlanamadı: $error');
      result = ReminderPermissionState.unknown;
    }

    if (revision != _permissionRevision || _disposed) {
      return ReminderPermissionState.unknown;
    }
    _publishPermission(result);
    return result;
  }

  Future<ReminderPermissionState> _readIosPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return ReminderPermissionState.unknown;
    final options = await ios.checkPermissions();
    if (options == null) return ReminderPermissionState.unknown;
    return options.isEnabled || options.isProvisionalEnabled
        ? ReminderPermissionState.granted
        : ReminderPermissionState.denied;
  }

  Future<ReminderPermissionState> _readAndroidPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return ReminderPermissionState.unknown;

    final appEnabled = await android.areNotificationsEnabled();
    if (appEnabled == null) return ReminderPermissionState.unknown;
    if (!appEnabled) return ReminderPermissionState.denied;

    final channels = await android.getNotificationChannels();
    if (channels == null) return ReminderPermissionState.unknown;
    for (final channel in channels) {
      if (channel.id == _channelId && channel.importance == Importance.none) {
        return ReminderPermissionState.denied;
      }
    }
    return ReminderPermissionState.granted;
  }

  Future<ReminderPermissionState> _requestPermissionState() {
    if (_disposed || !_supported) {
      return Future.value(ReminderPermissionState.unknown);
    }
    final requesting = _permissionRequest;
    if (requesting != null) return requesting;
    // Başlamış salt-okunur çağrı native tarafta iptal edilemez; revision onu
    // geçersiz kılar. Pointer'ı bırakmak, kullanıcı cevabından sonraki sync'in
    // o eski Future'ı paylaşmasını önler.
    _permissionRead = null;

    late final Future<ReminderPermissionState> operation;
    operation = _performPermissionRequest().whenComplete(() {
      if (identical(_permissionRequest, operation)) _permissionRequest = null;
    });
    return _permissionRequest = operation;
  }

  Future<ReminderPermissionState> _performPermissionRequest() async {
    // Daha önce başlamış yavaş bir salt-okunur sorgu, kullanıcı cevabını
    // sonradan ezemez.
    final revision = ++_permissionRevision;
    ReminderPermissionState result;
    try {
      await initialize();
      if (_isIos) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
        result = granted == null
            ? ReminderPermissionState.unknown
            : granted
            ? ReminderPermissionState.granted
            : ReminderPermissionState.denied;
      } else if (_isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) {
          result = ReminderPermissionState.unknown;
        } else {
          final prompted = await android.requestNotificationsPermission();
          result = prompted == false
              ? ReminderPermissionState.denied
              : await _readAndroidPermission();
        }
      } else {
        result = ReminderPermissionState.unknown;
      }
    } on MissingPluginException catch (error) {
      debugPrint('Bildirim izni alınamadı: $error');
      result = ReminderPermissionState.unknown;
    } on PlatformException catch (error) {
      debugPrint('Bildirim izni alınamadı: $error');
      result = ReminderPermissionState.unknown;
    } on Object catch (error) {
      debugPrint('Bildirim servisi izin isteğine hazırlanamadı: $error');
      result = ReminderPermissionState.unknown;
    }

    if (revision != _permissionRevision || _disposed) {
      return ReminderPermissionState.unknown;
    }
    _publishPermission(result);
    return result;
  }

  void _publishPermission(ReminderPermissionState state) {
    if (state == ReminderPermissionState.unknown || _disposed) return;
    if (_permission.value != state) _permission.value = state;
  }

  /// Kullanıcı izni daha önce reddettiyse işletim sistemi istemi yeniden
  /// gösterilmez. Bu durumda uygulamanın sistem ayarlarını açar.
  Future<void> openSystemSettings() async {
    if (!_supported) return;
    try {
      await _settingsChannel.invokeMethod<bool>('openNotificationSettings');
    } on PlatformException catch (error) {
      debugPrint('Bildirim ayarları açılamadı: $error');
    }
  }

  /// Arayüzde gösterilecek sıradaki oluşum, native programla aynı hesaptan.
  DateTime? nextReminderAt(
    Note note,
    AppSettings settings, {
    required DateTime now,
  }) {
    return pendingReminderAt(
      remindAt: note.remindAt,
      cadence: ReminderCadence.fromCode(note.remindEveryDays),
      expiresAt: note.expiresAt,
      now: now,
    );
  }

  /// Debug Pro bölümündeki elle tetiklenen, tek seferlik güvenli bildirim.
  ///
  /// Gerçek reminder programına kayıt eklemez: `show` doğrudan tek bir
  /// teslimat yapar ve sabit `0` kimliği önceki test satırını değiştirir.
  /// [kDebugMode] derleme zamanı kapısı sayesinde release çağırıcısı yanlışlıkla
  /// bu metoda ulaşsa bile platforma tek çağrı gitmez.
  Future<bool> sendDebugTestNotification({
    required Note note,
    required L10n l10n,
    required bool debugProEnabled,
  }) async {
    if (!kDebugMode ||
        !debugProEnabled ||
        !_supported ||
        note.id <= 0 ||
        note.remindAt == null) {
      return false;
    }

    try {
      await initialize();
      if (await requestPermissionState() != ReminderPermissionState.granted) {
        return false;
      }

      const id = 0;
      final art = await _attachmentPath(photoOf?.call(note), id);

      final body = _body(note, l10n);

      Future<void> show(String? attachment) => _plugin.show(
        id: id,
        title: _title,
        body: body,
        payload: 'note/${note.id}',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.notificationChannelName,
            channelDescription: l10n.notificationChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            autoCancel: true,
            sound: const RawResourceAndroidNotificationSound(_soundName),
            styleInformation: _androidStyle(attachment, body),
          ),
          iOS: DarwinNotificationDetails(
            sound: _iosSoundFile,
            attachments: attachment == null
                ? null
                : [DarwinNotificationAttachment(attachment)],
          ),
        ),
      );

      try {
        await show(art);
      } on PlatformException {
        if (art == null) rethrow;
        // Görsel eki reddedilirse test bildiriminin metni yine de ulaşsın.
        await show(null);
      }
      return true;
    } on Object catch (error) {
      debugPrint('Debug test bildirimi gönderilemedi: $error');
      return false;
    }
  }

  /// Veritabanındaki isteklerle işletim sistemindeki programı uzlaştırır.
  ///
  /// Aynı kalan native tekrar iptal edilip yeniden kurulmaz; uygulamayı açmak
  /// "30 gün" sayacını başa saramaz. Silinen, kapatılan veya aralığı değişen
  /// kayıtlar kaldırılır ve yalnızca yeni program eklenir.
  /// Bildirime iliştirilecek karenin dosyası.
  ///
  /// Servis depoyu tanımıyor; çözücüyü çağıran veriyor.
  File Function(Note note)? photoOf;

  /// Bildirime iliştirilen karelerin kopyaları.
  ///
  /// Geçici dizinde **duramaz**. Android bildirimi kurulum anında değil,
  /// alarm çaldığı anda `NotificationDetails` JSON'undan kuruyor ve dosyayı
  /// *o an* okuyor — yani kopyanın günlerce yaşaması gerekiyor. Geçici dizini
  /// ise sistem istediği anda boşaltabilir.
  static const _attachmentDirName = 'reminder_art';

  Directory? _artDir;

  Future<void> sync(List<Note> notes, AppSettings settings, L10n l10n) async {
    if (!_supported) return;
    await initialize();
    // Bölge yalnız `initialize` içinde çözülüyordu ve `initialize` ömürde bir
    // kez koşuyor: soğuk açılışta native kanal bir kare geç hazır olduysa
    // uygulama **süreç boyunca** UTC'de kalıyor, o oturumda kurulan her
    // tekrarlı hatırlatma yanlış saate düşüyordu. Kod bunun "sonraki sync'te
    // yeniden denenir" olduğunu varsayıyordu; denenmiyordu.
    // Kullanıcı seyahatte veya sistem ayarından bölgeyi değiştirmiş
    // olabilir. Uygulama her öne dönüşte sync yaptığı için burada yeniden
    // okumak günlük/haftalık duvar saatini eski bölgeye kilitlemez.
    await _configureTimeZone();
    await _syncCategoryLanguage(l10n);

    try {
      if (!settings.proUnlocked || !settings.reminderEnabled) {
        await _plugin.cancelAll();
        // Program tümden kalktığına göre bildirime iliştirilen kareler de
        // sahipsiz kaldı. Süpürme normalde aşağıda, hedef küme belliyken
        // yapılıyor; bu erken dönüşte atlanırsa kopyalar diskte kalıyordu ve
        // onları toplayan başka bir yol yok (`sweepOrphanFiles` yalnız notun
        // kendi fotoğraf deposuna bakıyor).
        await _sweepAttachments(const {});
        return;
      }

      final now = tz.TZDateTime.now(tz.UTC);
      final byId = {for (final note in notes) note.id: note};
      final requests = [
        for (final note in notes)
          if (note.remindAt case final remindAt?)
            ReminderRequest(
              noteId: note.id,
              remindAt: remindAt,
              cadence: ReminderCadence.fromCode(note.remindEveryDays),
              expiresAt: note.expiresAt,
            ),
      ];
      final schedule = reminderSchedule(
        requests: requests,
        now: now,
        maxPerNote: _isIos
            ? kRollingReminderWindowPerNote
            : kPendingReminderBudget,
      );

      final desired = <int, _DesiredReminder>{};
      final photos = <int, File?>{};
      final attachmentFingerprints = <int, String>{};
      final firstOccurrenceByNote = <int, int>{};
      for (final reminder in schedule) {
        firstOccurrenceByNote.putIfAbsent(
          reminder.noteId,
          () => reminder.notificationId,
        );
      }
      for (final reminder in schedule) {
        final note = byId[reminder.noteId];
        if (note == null) continue;
        // Bütçeli tek-atış dizisinde aynı 1024 px kareyi her oluşum için kopyalamak
        // hem iOS attachment kotasını hem belleği gereksiz tüketir. En yakın
        // oluşum görselli kurulur; o teslim edilip sonraki sync çalıştığında
        // sıradaki oluşum güvenle (mutlak tarihi değişmeden) görselleşir.
        final shouldAttach =
            firstOccurrenceByNote[note.id] == reminder.notificationId;
        final photo = shouldAttach
            ? photos.containsKey(note.id)
                  ? photos[note.id]
                  : photos[note.id] = photoOf?.call(note)
            : null;
        final attachmentFingerprint = shouldAttach
            ? attachmentFingerprints[note.id] ??= await _attachmentFingerprint(
                photo,
              )
            : _missingAttachmentFingerprint;
        desired[reminder.notificationId] = _DesiredReminder(
          reminder: reminder,
          note: note,
          payload: _payload(
            reminder,
            note,
            attachmentFingerprint: attachmentFingerprint,
          ),
          photo: photo,
        );
      }

      // Geçici bir platform hatasını "izin yok" diye yorumlayıp mevcut
      // alarmı silmek geri dönüşsüzdür: yenisi aynı turda kurulamaz. Kesin
      // bir OS cevabı gelmeden bekleyen/teslim edilmiş duruma dokunma.
      final permission = await refreshPermission();
      if (permission == ReminderPermissionState.unknown) return;

      // Hatırlatması kapatılan ve silinen notların tepsiye ulaşmış satırları
      // da gider. Tek atışını teslim etmiş, hâlâ açık bir not korunur.
      await _removeObsoleteDeliveredNotifications(notes);

      final existing = <int>{};
      final stale = <int>[];
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        // Başka bir bildirim türü ileride aynı eklentiyi kullanırsa ona
        // dokunma. Eski `note/<id>` payload'ları ise bir kereliğine v2'ye
        // dönüştürülmek üzere iptal edilir.
        if (noteIdFromReminderPayload(request.payload) == null) continue;

        final target = desired[request.id];
        if (target != null && target.payload == request.payload) {
          existing.add(request.id);
          continue;
        }

        // Sistem izni kapalıyken artık istekleri temizlemek güvenli, fakat
        // hâlâ istenen bir alarmı değiştirmek değil: yeni sürüm/fotoğraf
        // payload'ı OS izni geri gelene kadar eskisinin yerini alamaz.
        if (target != null && permission == ReminderPermissionState.denied) {
          continue;
        }
        stale.add(request.id);
      }

      // Önceki 60'lık exact pencereyi yeni küçük programa geçirirken
      // main isolate üzerinden 60 ayrı cancel çağrısı da Simulator'ı uzun
      // süre meşgul edebilir. Bu uygulamada eklentinin bütün bekleyen kayıtları
      // Latermark reminder'larıdır; büyük iOS migrasyonunu tek native toplu
      // çağrıyla temizleyip güncel hedefi yeniden kurmak güvenlidir. Teslim
      // edilmiş tepsi satırları bu API'den etkilenmez.
      final useBulkMigrationCancel =
          _isIos &&
          permission == ReminderPermissionState.granted &&
          stale.length > kRollingReminderWindowPerNote;
      if (useBulkMigrationCancel) {
        await _plugin.cancelAllPendingNotifications();
        existing.clear();
      } else {
        for (final id in stale) {
          await _plugin.cancel(id: id);
        }
      }

      // İzin kapalıyken yalnız eski/hayalet kayıtlar yukarıda temizlenir.
      // Kullanıcı sistem ayarından dönünce mismatch kayıtlar güvenle yenilenir.
      if (permission == ReminderPermissionState.denied) return;

      await _sweepAttachments(desired.keys.toSet());

      var installed = 0;
      for (final entry in desired.entries) {
        if (existing.contains(entry.key)) continue;
        try {
          await _schedule(entry.value, l10n);
          installed++;
        } on PlatformException catch (error) {
          // Tek bir bozuk native kayıt, aynı senkrondaki diğer notların
          // programını kesmemeli. `_schedule` kare reddini zaten karesiz
          // yeniden dener; ikinci hata kaydın kendisine aittir.
          debugPrint(
            'Hatırlatma kurulamadı (${entry.value.reminder.notificationId}): '
            '$error',
          );
        }
      }

      // Programın **kararını** görünür kılan tek satır.
      //
      // Bu yol sessiz başarısızlığa çok müsait: izin okuması kesin cevap
      // vermezse, bütçe boş dönerse ya da kayıt zaten kurulu sayılırsa hiçbir
      // şey olmuyor ve hiçbir yerde iz kalmıyordu. Satır yalnız debug
      // derlemesinde çalışıyor; `assert` gövdesi release'de tamamen düşüyor.
      assert(() {
        debugPrint(
          'Hatırlatma senkronu: izin=${permission.name} '
          'bölge=${tz.local.name} istek=${requests.length} '
          'istenen=${desired.length} zaten=${existing.length} '
          'kurulan=$installed',
        );
        for (final request in requests) {
          debugPrint(
            '  kayıt#${request.noteId} an=${request.remindAt.toIso8601String()} '
            'ritim=${request.cadence.name} son=${request.expiresAt}',
          );
        }
        for (final value in desired.values) {
          debugPrint(
            '  kurulacak#${value.reminder.notificationId} '
            'an=${value.reminder.at.toIso8601String()} '
            'ritim=${value.reminder.repeat?.name}',
          );
        }
        return true;
      }());
    } on PlatformException catch (error) {
      // İzin yoksa veya tam zamanlı alarm hakkı verilmemişse sessizce geç.
      debugPrint('Hatırlatmalar kurulamadı: $error');
    }
  }

  /// Bildirime iliştirilecek karenin hazırlanması.
  ///
  /// Her iki platforma da **küçültülmüş tek kullanımlık bir kopya** gidiyor,
  /// asıl kare değil. İki ayrı sebebi var:
  ///
  /// - iOS eki kendi deposuna **taşır**. Asıl kareyi verseydik not fotoğrafı
  ///   `PhotoStore`'dan kaybolurdu.
  /// - Android bildirimi sistem çiziyor ama bitmap'i *bizim sürecimizde*
  ///   `BitmapFactory.decodeFile` çözüyor — örnekleme yapmadan, tam
  ///   çözünürlükte. 12 MP'lik bir kare ≈ 48 MB'lık bir bitmap eder ve bu
  ///   ayırma her hatırlatma için döngü içinde tekrarlanır. Kilit ekranındaki
  ///   küçük önizleme için ödenecek bir bedel değil.
  ///
  /// Kopya, iOS onu aldığı anda yerinden kalkar. Alınamayan (kurulum hata
  /// verdiyse) artıklar bir sonraki [sync] süpürmesinde temizlenir.
  /// Apple'ın **üretilen** görsel eki için koyduğu 10 MB sınırı.
  ///
  /// Kaynak bu sınırla veya dosya uzantısıyla elenmez. Photos paylaşımı HEIC
  /// verebilir; kaynak 10 MB'tan büyük olsa bile aşağıda üretilen 1024 px PNG
  /// çok daha küçük olabilir. Native API'ye giden destekli çıktı ölçülür.
  static const _attachmentSizeLimit = 10 * 1024 * 1024;

  /// Kopyanın uzun kenarı. Kilit ekranındaki önizleme ile açılmış bildirimin
  /// geniş görseline fazlasıyla yeter; ötesi yalnızca bellek ve süre.
  static const _attachmentMaxEdge = 1024;

  Future<String?> _attachmentPath(File? photo, int notificationId) async {
    if (photo == null || !photo.existsSync()) return null;

    final dir = await _resolveArtDir();
    if (dir == null) return null;

    final copy = File('${dir.path}/$notificationId.png');
    ui.Codec? codec;
    ui.Image? image;
    try {
      // `instantiateImageCodecWithSize` buffer'ı codec oluşturulunca kapatır;
      // dönen codec'in yaşam döngüsü ise çağırana aittir.
      final buffer = await ui.ImmutableBuffer.fromFilePath(photo.path);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          if (width <= _attachmentMaxEdge && height <= _attachmentMaxEdge) {
            return ui.TargetImageSize(width: width, height: height);
          }
          final scale = _attachmentMaxEdge / (width > height ? width : height);
          return ui.TargetImageSize(
            width: (width * scale).round(),
            height: (height * scale).round(),
          );
        },
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (bytes.lengthInBytes > _attachmentSizeLimit) {
        if (copy.existsSync()) await copy.delete();
        return null;
      }

      await copy.writeAsBytes(bytes, flush: true);
      return copy.path;
    } on Object catch (error) {
      // Kare iliştirilemezse bildirim yine de gitmeli; görsel süs, taşıyıcı
      // bilgi değil. Çözme hatası da dosya hatası da aynı yere çıkar.
      debugPrint('Bildirim karesi hazırlanamadı: $error');
      if (copy.existsSync()) {
        try {
          await copy.delete();
        } on FileSystemException {
          // Hazırlama hatasını koru; bu yalnız yeniden üretilebilir bir kopya.
        }
      }
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// Kaynağın payload'a girecek kararlı kimliği.
  ///
  /// Dosya henüz yoksa `none` yazılır. Arka plan sıkıştırması dosyayı daha sonra
  /// değiştirdiğinde boyut/zaman kimliği de değişir; ilk turda karesiz kurulan
  /// native istek böylece sonraki [sync]'te aynı sanılıp korunmaz.
  Future<String> _attachmentFingerprint(File? photo) async {
    if (photo == null) return _missingAttachmentFingerprint;
    try {
      final stat = await photo.stat();
      if (stat.type != FileSystemEntityType.file) {
        return _missingAttachmentFingerprint;
      }
      return '${stat.size.toRadixString(36)}-'
          '${stat.modified.microsecondsSinceEpoch.toRadixString(36)}';
    } on FileSystemException {
      return _missingAttachmentFingerprint;
    }
  }

  /// Kopyaların yaşadığı kalıcı dizin. Çözülemezse kare iliştirilmez.
  Future<Directory?> _resolveArtDir() async {
    if (_artDir != null) return _artDir;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$_attachmentDirName');
      if (!dir.existsSync()) await dir.create(recursive: true);
      return _artDir = dir;
    } on Object catch (error) {
      debugPrint('Bildirim karesi dizini açılamadı: $error');
      return null;
    }
  }

  /// Artık hiçbir bekleyen bildirimin ihtiyaç duymadığı kopyaları siler.
  ///
  /// Dosyayı "kurulunca işi bitti" diye silmek yanlış olurdu: Android onu
  /// alarm çaldığı anda okuyor. Ölçüt bu yüzden zaman değil, **hâlâ planda
  /// olup olmadığı** — adı, ait olduğu bildirim kimliği.
  Future<void> _sweepAttachments(Set<int> keep) async {
    final dir = await _resolveArtDir();
    if (dir == null) return;
    try {
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final id = int.tryParse(name.split('.').first);
        if (id != null && keep.contains(id)) continue;
        await entity.delete();
      }
    } on FileSystemException catch (error) {
      debugPrint('Bildirim kareleri süpürülemedi: $error');
    }
  }

  Future<void> _schedule(_DesiredReminder desired, L10n l10n) async {
    final art = await _attachmentPath(
      desired.photo,
      desired.reminder.notificationId,
    );
    if (art == null) {
      await _installReminder(desired, l10n, art: null);
      return;
    }

    try {
      await _installReminder(desired, l10n, art: art);
    } on PlatformException catch (error) {
      // `UNNotificationAttachment` dosyayı doğrularken hata döndürebilir.
      // Kare taşıyıcı bilgi değil: aynı isteği karesiz yeniden kur ve sonraki
      // hatırlatmaların bu tek görsel yüzünden sırada kalmasına izin verme.
      debugPrint(
        'Bildirim karesi native tarafta reddedildi '
        '(${desired.reminder.notificationId}): $error',
      );
      final rejectedCopy = File(art);
      if (rejectedCopy.existsSync()) {
        try {
          await rejectedCopy.delete();
        } on FileSystemException {
          // Kopya yeniden üretilebilir; karesiz retry bunun yüzünden durmamalı.
        }
      }
      await _installReminder(desired, l10n, art: null);
    }
  }

  Future<void> _installReminder(
    _DesiredReminder desired,
    L10n l10n, {
    required String? art,
  }) async {
    final reminder = desired.reminder;
    final note = desired.note;
    final body = _body(note, l10n);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        sound: const RawResourceAndroidNotificationSound(_soundName),
        styleInformation: _androidStyle(art, body),
      ),
      iOS: DarwinNotificationDetails(
        sound: _iosSoundFile,
        // Düğmeleri bildirime bağlayan tek bağ. Android'e karşılığı
        // verilmiyor: oradaki davranış olduğu gibi korunuyor.
        categoryIdentifier: note.remindEveryDays > 0
            ? _repeatCategoryId
            : _onceCategoryId,
        attachments: art == null ? null : [DarwinNotificationAttachment(art)],
      ),
    );

    final repeat = reminder.repeat;
    if (repeat != null) {
      // Günlük/haftalık ile native olarak güvenli normal aylık/yıllık
      // ritimler buraya gelir. 29/30/31 aylık ve 29 Şubat yıllık bileşen
      // eşleşmesi olmayan tarihi atlar; onlar "son geçerli gün" kuralını
      // koruyan kesin tarihlerdir.
      // Scheduler ayrıca ilk native eşleşmenin saklanan ilk halkayla aynı
      // olduğunu doğrulamıştır; bu kayıt kullanıcının seçiminden önce
      // çalmaz.
      final matching = switch (repeat) {
        ReminderCadence.once => null,
        ReminderCadence.daily => DateTimeComponents.time,
        ReminderCadence.weekly => DateTimeComponents.dayOfWeekAndTime,
        ReminderCadence.monthly => DateTimeComponents.dayOfMonthAndTime,
        ReminderCadence.yearly => DateTimeComponents.dateAndTime,
      };
      if (matching != null) {
        await _plugin.zonedSchedule(
          id: reminder.notificationId,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          title: _title,
          // Yinelenen kayıt işletim sisteminde uzun süre bekliyor; not gövdesi
          // o arada değişebilir. Metin bu yüzden zamansız kalıyor, dokununca
          // açılan not her zaman veritabanındaki güncel hâlidir.
          body: l10n.notificationBodyNoBody,
          payload: desired.payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: details,
          matchDateTimeComponents: matching,
        );
        return;
      }
    }

    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
      title: _title,
      body: body,
      payload: desired.payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: details,
    );
  }

  /// İlgili notun sistem tepsisindeki teslim edilmiş bildirimlerini kaldırır.
  ///
  /// Önce aktif listeyi okumamız bilinçli: `cancel(id:)` bekleyen isteği de
  /// kaldırır. Kullanıcı hatırlatma tarihi gelmeden nota kendi kendine bakarsa
  /// gelecekte istediği hatırlatmayı yanlışlıkla iptal etmemeliyiz. Tekrarlayan
  /// bir notta bu ayrım daha da önemli: sıradaki oluşumlar bekliyor olacak ve
  /// notu bir kez açmak tekrarı bitirmemeli.
  ///
  /// Teslim edilmiş birden çok oluşum tepside birikmiş olabilir; hepsi kapanır.
  Future<void> dismissNote(int noteId) async {
    if (!_supported || _disposed || noteId <= 0) return;
    await initialize();

    try {
      final active = await _plugin.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id != null && _noteIdOf(notification) == noteId) {
          await _plugin.cancel(id: id);
        }
      }
    } on PlatformException catch (error) {
      debugPrint('Not bildirimi kapatılamadı: $error');
    }
  }

  /// Uygulama kapalıyken süresi dolup silinen bir nota ait teslim edilmiş
  /// bildirimi de geride bırakma. Geçerli notların okunmamış bildirimlerine
  /// dokunulmaz; onlar kullanıcı notu açana kadar tepside kalabilir.
  Future<void> _removeObsoleteDeliveredNotifications(List<Note> notes) async {
    final noteIds = {
      for (final note in notes)
        if (note.remindAt != null) note.id,
    };
    final active = await _plugin.getActiveNotifications();

    for (final notification in active) {
      final id = notification.id;
      final noteId = _noteIdOf(notification);
      if (id != null && noteId != null && !noteIds.contains(noteId)) {
        await _plugin.cancel(id: id);
      }
    }
  }

  /// Tepsideki bir bildirimin hangi nota ait olduğu.
  ///
  /// iOS payload'dan okur. Android'de payload aktif bildirim listesinde
  /// taşınmadığı için kimlik aralığından geri hesaplanır — bu yüzden
  /// [reminderNotificationId] ile üretilmemiş kimlikler (bu sürümden önce
  /// planlanmış, hâlâ tepside duran bir bildirim) bir kereliğine yanlış nota
  /// eşlenebilir. En kötü sonucu tepside fazladan bir satır kalması; dokunma
  /// yönlendirmesi payload üzerinden yürüdüğü için doğru notu açmaya devam
  /// eder ve bir sonraki temizlikte kendini toparlar.
  int? _noteIdOf(ActiveNotification notification) {
    if (!_isAndroid) {
      return noteIdFromReminderPayload(notification.payload);
    }
    final id = notification.id;
    if (id == null) return null;
    if (notification.channelId == _channelId ||
        notification.channelId == _v2ChannelId) {
      return noteIdFromNotificationId(id);
    }
    if (notification.channelId == _legacyChannelId) {
      return id ~/ _legacyOccurrenceSpan;
    }
    return null;
  }

  /// Kullanıcı dili değiştirdiyse düğmeleri yeni dille yeniden kurar.
  ///
  /// Yalnızca gerçekten değiştiğinde çalışır: kategori kaydı `initialize`
  /// üzerinden gittiği için her senkronda tekrarlamak boşuna iş olurdu.
  Future<void> _syncCategoryLanguage(L10n l10n) async {
    if (!_isIos || _categoryLocale == l10n.localeName) return;
    try {
      await _registerPlugin(l10n);
    } on PlatformException catch (error) {
      // Düğmeler eski dilde kalır; hatırlatmanın kendisi etkilenmez.
      debugPrint('Bildirim düğmeleri güncellenemedi: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancelAll();
    } on PlatformException {
      // Yoksay.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _permissionRevision++;
    _permissionRead = null;
    _permissionRequest = null;
    _pendingNoteId = null;
    await _noteTaps.close();
    _permission.dispose();
  }

  /// Bildirimin başlığı her zaman uygulamanın adı.
  ///
  /// Kilit ekranında satırın *kimden* geldiği başlıktan okunuyor; "Hatırlatma"
  /// gibi genel bir sözcük her uygulamada aynı görünüyordu. Notun kendi metni
  /// zaten gövdede.
  static const _title = 'Latermark Pro';

  static String _body(Note note, L10n l10n) =>
      note.body.isEmpty ? l10n.notificationBodyNoBody : note.body;

  /// Android bildiriminin genişletilmiş hâli.
  ///
  /// Karesi olan kayıtta kare gösteriliyor. Karesiz kayıtta eskiden biçem
  /// **hiç verilmiyordu**: bildirim tek satıra sıkışıyor ve kullanıcı onu
  /// genişletemiyordu — uzun bir hatırlatmanın yarısı okunmadan kalıyordu.
  /// Metni burada kırpmıyoruz; kapalı hâlde sistem kendi kırpar, açınca
  /// tamamı görünür. Karakter saymak, işletim sisteminin zaten gösterebileceği
  /// yazıyı elle atmak olurdu.
  static StyleInformation _androidStyle(String? art, String body) => art == null
      ? BigTextStyleInformation(body)
      : BigPictureStyleInformation(
          FilePathAndroidBitmap(art),
          // Katlanmış hâlde de kare görünsün: küçük ikon yerine fotoğrafın
          // kendisi duruyor.
          largeIcon: FilePathAndroidBitmap(art),
          hideExpandedLargeIcon: true,
        );
}

/// Kurulum şemasının sürümü.
///
/// Kanal kimliğiyle birlikte yükseliyor. Bekleyen bir bildirimin hangi kanalla
/// —dolayısıyla hangi sesle— kurulduğunu sonradan sorgulamanın yolu yok:
/// `pendingNotificationRequests()` yalnızca kimlik, başlık, gövde ve payload
/// veriyor. Sürümü payload'a yazmak, eski kurulumları tanınır kılıyor.
const _payloadVersion = 'v6';
const _legacyPayloadVersions = {'v2', 'v3', 'v4', 'v5'};

/// Ek parmak izi taşıyan payload sürümleri. v2/v3'te bu bölüm yoktu.
const _attachmentAwarePayloadVersions = {'v4', 'v5'};

/// Attachment fingerprint şemasının payload etiketi.
///
/// Dosya kimliği hesabı ileride değişirse bu etiket yükseltilerek aynı reminder
/// zamanını değiştirmeden native içerik bir kez güvenle yenilenebilir.
const _attachmentPayloadVersion = 'art1';
const _missingAttachmentFingerprint = 'none';

String _payload(
  ScheduledReminder reminder,
  Note note, {
  required String attachmentFingerprint,
}) {
  final String core;
  if (reminder.repeatsIndefinitely) {
    core =
        'note/${note.id}/$_payloadVersion/every/'
        '${note.remindEveryDays}/'
        '${reminder.at.toUtc().millisecondsSinceEpoch}';
  } else {
    core =
        'note/${note.id}/$_payloadVersion/at/'
        '${reminder.at.toUtc().millisecondsSinceEpoch}';
  }
  return '$core/$_attachmentPayloadVersion/$attachmentFingerprint';
}

final class _DesiredReminder {
  const _DesiredReminder({
    required this.reminder,
    required this.note,
    required this.payload,
    this.photo,
  });

  final ScheduledReminder reminder;
  final Note note;
  final String payload;

  /// Notun karesi. Depo çözücüsü verilmediyse (ör. testlerde) boş.
  final File? photo;
}

/// Bu servisin ürettiği legacy veya sürümlü `note/<pozitif kimlik>/...`
/// payload'ını not kimliğine çevirir.
int? noteIdFromReminderPayload(String? payload) {
  if (payload == null) return null;
  final segments = payload.split('/');
  if (segments.length < 2 || segments.first != 'note') return null;

  final noteId = int.tryParse(segments[1]);
  if (noteId == null || noteId <= 0) return null;
  if (segments.length == 2) return noteId;

  // Sürüm etiketi yalnızca şemayı değil, **yeniden kurulmayı** da tetikliyor:
  // `sync()` payload'ı aynı kalan kaydı yeniden kurmuyor, dolayısıyla etiketi
  // yükseltmek eski sürümden kalan bekleyen bildirimleri iptal edip yeni
  // kanal/ses ile yeniden kurdurmanın yolu. Okurken eskileri de kabul edilir:
  // tepside hâlâ v2/v3 ile duran bir satır dokununca yine doğru notu açmalı.
  final version = segments[2];
  final current = version == _payloadVersion;
  if (!current && !_legacyPayloadVersions.contains(version)) return null;

  final int coreLength;
  if (segments.length >= 5 &&
      segments[3] == 'at' &&
      int.tryParse(segments[4]) != null) {
    coreLength = 5;
  } else {
    final everyCadence =
        segments.length >= 6 &&
            (segments[3] == 'every' || segments[3] == 'every_minutes')
        ? int.tryParse(segments[4])
        : null;
    if (everyCadence == null ||
        everyCadence <= 0 ||
        int.tryParse(segments[5]) == null) {
      return null;
    }
    coreLength = 6;
  }

  if (!current) {
    // v2/v3 ek parmak izi taşımıyordu; v4 `art1` şemasını ilk kullanan
    // sürümdü. Sürüm yükseldiğinde tepside duran eski bildirimlerin
    // dokunma/eylem payload'ları okunmaya devam eder.
    if (!_attachmentAwarePayloadVersions.contains(version)) {
      return segments.length == coreLength ? noteId : null;
    }
  }
  final validAttachmentSuffix =
      segments.length == coreLength + 2 &&
      segments[coreLength] == _attachmentPayloadVersion &&
      _validAttachmentFingerprint(segments[coreLength + 1]);
  return validAttachmentSuffix ? noteId : null;
}

bool _validAttachmentFingerprint(String fingerprint) {
  if (fingerprint == _missingAttachmentFingerprint) return true;
  final parts = fingerprint.split('-');
  if (parts.length != 2) return false;
  final size = int.tryParse(parts[0], radix: 36);
  final modified = int.tryParse(parts[1], radix: 36);
  return size != null && size >= 0 && modified != null && modified >= 0;
}

/// Bir hatırlatma payload'ının temsil ettiği oluşum anı.
///
/// "Yarın aynı saatte" sözünü tutmak için gerekiyor: kullanıcı bildirime
/// saatler sonra cevap verebilir ve o durumda referans, dokunma anı değil
/// bildirimin çaldığı andır.
///
/// Tek atışta payload zaten anı taşıyor. Süresiz tekrarda tek bir an yok;
/// aralık ile dizinin başlangıcı var ve oradan **geçmişteki son oluşum**
/// hesaplanıyor. Okunamayan ya da sürümsüz eski payload'lar için `null` döner
/// ve arayan tarafta [now]'a düşülür.
DateTime? reminderFiredAt(String? payload, {required DateTime now}) {
  if (payload == null || noteIdFromReminderPayload(payload) == null) {
    return null;
  }

  final segments = payload.split('/');
  if (segments.length >= 5 && segments[3] == 'at') {
    final milliseconds = int.tryParse(segments[4]);
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: true,
          ).toLocal();
  }

  if (segments.length >= 6 && segments[3] == 'every_minutes') {
    final minutes = int.tryParse(segments[4]);
    final anchorMilliseconds = int.tryParse(segments[5]);
    if (minutes == null || minutes <= 0 || anchorMilliseconds == null) {
      return null;
    }

    final anchor = DateTime.fromMillisecondsSinceEpoch(
      anchorMilliseconds,
      isUtc: true,
    ).toLocal();
    final interval = Duration(minutes: minutes);
    final elapsedMicroseconds =
        now.toUtc().microsecondsSinceEpoch -
        anchor.toUtc().microsecondsSinceEpoch;
    if (elapsedMicroseconds < interval.inMicroseconds) return null;
    final step = elapsedMicroseconds ~/ interval.inMicroseconds;
    return anchor.add(interval * step);
  }

  if (segments.length >= 6 && segments[3] == 'every') {
    final days = int.tryParse(segments[4]);
    final baseMilliseconds = int.tryParse(segments[5]);
    if (days == null || days <= 0 || baseMilliseconds == null) return null;

    final base = DateTime.fromMillisecondsSinceEpoch(
      baseMilliseconds,
      isUtc: true,
    ).toLocal();
    if (now.isBefore(base)) return null;

    // v6'dan itibaren damga dizinin **ilk halkası**: kendisi de bir oluşum,
    // yani sıfırıncı adım geçerli. Daha eski payload'larda damga çıpaydı ve
    // çıpanın kendisi hiç çalmazdı; ilk oluşum bir aralık sonrasındaydı.
    final firstStep = segments[2] == _payloadVersion ? 0 : 1;

    // Döngüyle değil aritmetikle: bir yıl önce başlamış günlük bir tekrarda
    // yüzlerce adım atmanın anlamı yok.
    var step = (localDayNumber(now) - localDayNumber(base)) ~/ days;
    if (step < firstStep) return null;
    var occurrence = shiftLocalCalendarDays(base, days * step);
    if (occurrence.isAfter(now)) {
      step--;
      if (step < firstStep) return null;
      occurrence = shiftLocalCalendarDays(base, days * step);
    }
    return occurrence;
  }

  return null;
}
