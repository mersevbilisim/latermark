import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
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
  final bool? _supportedOverride;
  static const _settingsChannel = MethodChannel('latermark/app_settings');
  static const _actionChannel = MethodChannel('latermark/reminder_actions');

  bool _ready = false;
  bool _disposed = false;
  Future<void>? _initialization;
  int? _pendingNoteId;

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

  /// Hatırlatma bildirimlerinin düğme takımı.
  ///
  /// Tek kategori yetiyor: bütün hatırlatmalar aynı üç düğmeyi taşıyor.
  static const _categoryId = 'latermark.reminder';

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

  Future<void> _configureTimeZone() async {
    if (!_isIos) {
      // Bu görev Android programını değiştirmiyor; mevcut mutlak UTC davranışı
      // aynen korunuyor.
      tz.setLocalLocation(tz.UTC);
      return;
    }
    try {
      final identifier = await _actionChannel.invokeMethod<String>(
        'timeZoneIdentifier',
      );
      if (identifier == null) throw StateError('Saat dilimi bulunamadı.');
      tz.setLocalLocation(tz.getLocation(identifier));
    } on Object catch (error) {
      // Tek atışlı kayıt mutlak anla yine doğrudur. Sonraki lifecycle sync'i
      // bölgeyi yeniden çözmeyi dener.
      debugPrint('Yerel saat dilimi çözülemedi: $error');
      tz.setLocalLocation(tz.UTC);
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
          notificationCategories: [_category(l10n)],
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

  /// Bildirimin üç düğmesi.
  ///
  /// Hiçbiri `foreground` değil: üçünün de bütün değeri uygulamayı açmadan
  /// iş bitirmesinde. `foreground` verilseydi iOS her dokunuşta uygulamayı
  /// öne getirirdi ve düğmelerin varlık sebebi kalmazdı.
  static DarwinNotificationCategory _category(L10n l10n) =>
      DarwinNotificationCategory(
        _categoryId,
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
        ],
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
  /// İzin verilirse `true` döner. Reddedildiğinde arayüz tercihi açık
  /// kaydetmez; işletim sistemi ile uygulama durumu böylece tutarlı kalır.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await initialize();

    try {
      if (_isIos) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: true);
        return granted ?? false;
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } on PlatformException catch (error) {
      debugPrint('Bildirim izni alınamadı: $error');
      return false;
    }
  }

  /// İşletim sisteminin uygulamaya şu anda bildirim gönderebilme hakkı verip
  /// vermediğini okur. Kullanıcı izni daha sonra Ayarlar'dan kapatmış olabilir.
  Future<bool> hasPermission() async {
    if (!_supported) return false;
    await initialize();

    try {
      if (_isIos) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }

      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    } on PlatformException catch (error) {
      debugPrint('Bildirim izni okunamadı: $error');
      return false;
    }
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
    await _syncCategoryLanguage(l10n);

    try {
      if (!settings.proUnlocked || !settings.reminderEnabled) {
        await _plugin.cancelAll();
        return;
      }

      final now = tz.TZDateTime.now(tz.UTC);
      final byId = {for (final note in notes) note.id: note};
      final schedule = reminderSchedule(
        requests: [
          for (final note in notes)
            ReminderRequest(
              noteId: note.id,
              anchorAt: note.reminderAnchorAt ?? note.createdAt,
              remindAfterDays: note.remindAfterDays,
              repeats: note.remindRepeats,
              expiresAt: note.expiresAt,
            ),
        ],
        now: now,
      );

      final desired = <int, _DesiredReminder>{};
      for (final reminder in schedule) {
        final note = byId[reminder.noteId];
        if (note == null) continue;
        desired[reminder.notificationId] = _DesiredReminder(
          reminder: reminder,
          note: note,
          payload: _payload(reminder, note),
          photo: photoOf?.call(note),
        );
      }

      // Hatırlatması kapatılan ve silinen notların tepsiye ulaşmış satırları
      // da gider. Tek atışını teslim etmiş, hâlâ açık bir not korunur.
      await _removeObsoleteDeliveredNotifications(notes);

      final existing = <int>{};
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
        await _plugin.cancel(id: request.id);
      }

      // İzin kapalıyken eski/hayalet kayıtlar yukarıda temizlenir ama yeni
      // kayıt kurulmaz. Kullanıcı sistem ayarından dönünce sync yeniden koşar.
      if (!await hasPermission()) return;

      await _sweepAttachments(desired.keys.toSet());

      for (final entry in desired.entries) {
        if (existing.contains(entry.key)) continue;
        await _schedule(entry.value, l10n);
      }
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
  /// iOS'un `UNNotificationAttachment`'ı kabul ettiği türler.
  ///
  /// Bu sınır kozmetik değil: desteklenmeyen bir dosya verilince Apple hata
  /// döndürüyor, eklenti onu `PlatformException`'a çeviriyor ve [sync]'in
  /// döngüsü orada kesiliyor — yani **tek bir HEIC kare, o senkrondaki bütün
  /// hatırlatmaları kurulmadan bırakır**. Galeriden ve paylaşımdan gelen
  /// kareler pekâlâ HEIC olabilir. Görsel süs, hatırlatma taşıyıcı bilgi:
  /// şüphede kalınca ek düşer, bildirim kalır.
  static const _attachableExtensions = {'.jpg', '.jpeg', '.png', '.gif'};

  /// Apple'ın görsel eki sınırı 10 MB. Üstünü göndermek de aynı hatayı üretir.
  static const _attachmentSizeLimit = 10 * 1024 * 1024;

  /// Kopyanın uzun kenarı. Kilit ekranındaki önizleme ile açılmış bildirimin
  /// geniş görseline fazlasıyla yeter; ötesi yalnızca bellek ve süre.
  static const _attachmentMaxEdge = 1024;

  Future<String?> _attachmentPath(File? photo, int notificationId) async {
    if (photo == null || !photo.existsSync()) return null;

    final dot = photo.path.lastIndexOf('.');
    final extension = dot < 0 ? '' : photo.path.substring(dot).toLowerCase();
    if (!_attachableExtensions.contains(extension)) return null;
    if (await photo.length() > _attachmentSizeLimit) return null;

    final dir = await _resolveArtDir();
    if (dir == null) return null;

    ui.Image? image;
    try {
      // Buffer'ın sahipliğini codec devralır ve kendisi kapatır.
      final buffer = await ui.ImmutableBuffer.fromFilePath(photo.path);
      final codec = await ui.instantiateImageCodecWithSize(
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

      final copy = File('${dir.path}/$notificationId.png');
      await copy.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return copy.path;
    } on Object catch (error) {
      // Kare iliştirilemezse bildirim yine de gitmeli; görsel süs, taşıyıcı
      // bilgi değil. Çözme hatası da dosya hatası da aynı yere çıkar.
      debugPrint('Bildirim karesi hazırlanamadı: $error');
      return null;
    } finally {
      image?.dispose();
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
    final reminder = desired.reminder;
    final note = desired.note;
    final art = await _attachmentPath(desired.photo, reminder.notificationId);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        sound: const RawResourceAndroidNotificationSound(_soundName),
        styleInformation: art == null
            ? null
            : BigPictureStyleInformation(
                FilePathAndroidBitmap(art),
                // Katlanmış hâlde de kare görünsün: küçük ikon yerine
                // fotoğrafın kendisi duruyor.
                largeIcon: FilePathAndroidBitmap(art),
                hideExpandedLargeIcon: true,
              ),
      ),
      iOS: DarwinNotificationDetails(
        sound: _iosSoundFile,
        // Düğmeleri bildirime bağlayan tek bağ. Android'e karşılığı
        // verilmiyor: oradaki davranış olduğu gibi korunuyor.
        categoryIdentifier: _categoryId,
        attachments: art == null ? null : [DarwinNotificationAttachment(art)],
      ),
    );

    final interval = reminder.repeatInterval;
    if (interval != null) {
      final calendarRepeat = _isIos
          ? switch (interval.inDays) {
              1 => DateTimeComponents.time,
              7 => DateTimeComponents.dayOfWeekAndTime,
              _ => null,
            }
          : null;
      if (calendarRepeat != null) {
        await _plugin.zonedSchedule(
          id: reminder.notificationId,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          title: _title,
          body: l10n.notificationBodyNoBody,
          payload: desired.payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: details,
          matchDateTimeComponents: calendarRepeat,
        );
        return;
      }
      await _plugin.periodicallyShowWithDuration(
        id: reminder.notificationId,
        repeatDurationInterval: interval,
        // Native tekrar aynı kalan programda yeniden kurulmaz; aksi hâlde
        // uygulamayı açmak sayacı başa sarardı. Bu nedenle metin de not
        // gövdesinin eski bir kopyasını taşımak yerine zamansız/genel kalır.
        // Dokununca açılan not her zaman veritabanındaki güncel gövdedir.
        title: _title,
        body: l10n.notificationBodyNoBody,
        payload: desired.payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: details,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
      title: _title,
      body: _body(note, l10n),
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
        if (note.remindAfterDays > 0) note.id,
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
    _pendingNoteId = null;
    await _noteTaps.close();
  }

  /// Bildirimin başlığı her zaman uygulamanın adı.
  ///
  /// Kilit ekranında satırın *kimden* geldiği başlıktan okunuyor; "Hatırlatma"
  /// gibi genel bir sözcük her uygulamada aynı görünüyordu. Notun kendi metni
  /// zaten gövdede.
  static const _title = 'Latermark Pro';

  static String _body(Note note, L10n l10n) =>
      note.body.isEmpty ? l10n.notificationBodyNoBody : note.body;
}

/// Kurulum şemasının sürümü.
///
/// Kanal kimliğiyle birlikte yükseliyor. Bekleyen bir bildirimin hangi kanalla
/// —dolayısıyla hangi sesle— kurulduğunu sonradan sorgulamanın yolu yok:
/// `pendingNotificationRequests()` yalnızca kimlik, başlık, gövde ve payload
/// veriyor. Sürümü payload'a yazmak, eski kurulumları tanınır kılıyor.
const _payloadVersion = 'v3';

String _payload(ScheduledReminder reminder, Note note) {
  if (reminder.repeatsIndefinitely) {
    final anchor = note.reminderAnchorAt ?? note.createdAt;
    return 'note/${note.id}/$_payloadVersion/every/${note.remindAfterDays}/'
        '${anchor.toUtc().millisecondsSinceEpoch}';
  }
  return 'note/${note.id}/$_payloadVersion/at/'
      '${reminder.at.toUtc().millisecondsSinceEpoch}';
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
  // kanal/ses ile yeniden kurdurmanın yolu. Okurken eskisi de kabul edilir:
  // tepside hâlâ v2 ile duran bir satır dokununca yine doğru notu açmalı.
  const readable = {'v2', _payloadVersion};
  final validAt =
      segments.length == 5 &&
      readable.contains(segments[2]) &&
      segments[3] == 'at' &&
      int.tryParse(segments[4]) != null;
  final everyDays = segments.length == 6 && segments[3] == 'every'
      ? int.tryParse(segments[4])
      : null;
  final validEvery =
      segments.length == 6 &&
      readable.contains(segments[2]) &&
      segments[3] == 'every' &&
      everyDays != null &&
      everyDays > 0 &&
      int.tryParse(segments[5]) != null;
  return validAt || validEvery ? noteId : null;
}

/// Bir hatırlatma payload'ının temsil ettiği oluşum anı.
///
/// "Yarın aynı saatte" sözünü tutmak için gerekiyor: kullanıcı bildirime
/// saatler sonra cevap verebilir ve o durumda referans, dokunma anı değil
/// bildirimin çaldığı andır.
///
/// Tek atışta payload zaten anı taşıyor. Süresiz tekrarda anı yok, aralık ve
/// çıpa var; oradan **geçmişteki son oluşum** hesaplanıyor. Okunamayan ya da
/// sürümsüz eski payload'lar için `null` döner ve arayan tarafta [now]'a
/// düşülür.
DateTime? reminderFiredAt(String? payload, {required DateTime now}) {
  if (payload == null || noteIdFromReminderPayload(payload) == null) {
    return null;
  }

  final segments = payload.split('/');
  if (segments.length == 5 && segments[3] == 'at') {
    final milliseconds = int.tryParse(segments[4]);
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: true,
          ).toLocal();
  }

  if (segments.length == 6 && segments[3] == 'every') {
    final days = int.tryParse(segments[4]);
    final anchorMilliseconds = int.tryParse(segments[5]);
    if (days == null || days <= 0 || anchorMilliseconds == null) return null;

    final anchor = DateTime.fromMillisecondsSinceEpoch(
      anchorMilliseconds,
      isUtc: true,
    ).toLocal();
    final elapsed = now.difference(anchor);
    if (elapsed.isNegative) return null;

    // Döngüyle değil aritmetikle: bir yıl önce başlamış günlük bir tekrarda
    // yüzlerce adım atmanın anlamı yok.
    final anchorLocal = anchor.toLocal();
    final nowLocal = now.toLocal();
    final anchorDay = DateTime.utc(
      anchorLocal.year,
      anchorLocal.month,
      anchorLocal.day,
    );
    final nowDay = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
    var step = nowDay.difference(anchorDay).inDays ~/ days;
    if (step < 1) return null;
    var occurrence = shiftLocalCalendarDays(anchor, days * step);
    if (occurrence.isAfter(now)) {
      step--;
      if (step < 1) return null;
      occurrence = shiftLocalCalendarDays(anchor, days * step);
    }
    return occurrence;
  }

  return null;
}
