import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../notes/data/notes_database.dart';
import '../notes/domain/note_reminder.dart';
import '../settings/domain/app_settings.dart';

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

  bool _ready = false;
  bool _disposed = false;
  Future<void>? _initialization;
  int? _pendingNoteId;

  /// v2, 64 kimliklik oluşum aralığını ve native süresiz tekrarları kullanır.
  /// Kanal kimliği Android'de aktif bir bildirimin eski (/8) ya da yeni (/64)
  /// kimlik şemasıyla çözülmesini de sağlar.
  static const _channelId = 'latermark_reminders_v2';
  static const _legacyChannelId = 'latermark_reminders';
  static const _legacyOccurrenceSpan = 8;

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
      // Bölge adını tahmin etmek yerine her şey UTC üzerinden planlanır.
      //
      // Hatırlatma "şu andan X gün sonra" olduğu için önemli olan mutlak an;
      // duvar saati değil. UTC kullanmak, cihazın bölge adını bilmeye (ve fazladan
      // bir pakete) gerek bırakmadan anı tam doğru veriyor. Bu yaklaşım yalnızca
      // "her gün saat 9'da" gibi tekrarlarda yetersiz kalırdı — öyle bir şey yok.
      tz.setLocalLocation(tz.UTC);

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // İzin, kullanıcı ayarı açtığında açıkça istenir; açılışta değil.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          _emitPayload(response.payload);
        },
      );

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
  Future<void> sync(List<Note> notes, AppSettings settings, L10n l10n) async {
    if (!_supported) return;
    await initialize();

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

      for (final entry in desired.entries) {
        if (existing.contains(entry.key)) continue;
        await _schedule(entry.value, l10n);
      }
    } on PlatformException catch (error) {
      // İzin yoksa veya tam zamanlı alarm hakkı verilmemişse sessizce geç.
      debugPrint('Hatırlatmalar kurulamadı: $error');
    }
  }

  Future<void> _schedule(_DesiredReminder desired, L10n l10n) async {
    final reminder = desired.reminder;
    final note = desired.note;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final interval = reminder.repeatInterval;
    if (interval != null) {
      await _plugin.periodicallyShowWithDuration(
        id: reminder.notificationId,
        repeatDurationInterval: interval,
        // Native tekrar aynı kalan programda yeniden kurulmaz; aksi hâlde
        // uygulamayı açmak sayacı başa sarardı. Bu nedenle metin de not
        // gövdesinin eski bir kopyasını taşımak yerine zamansız/genel kalır.
        // Dokununca açılan not her zaman veritabanındaki güncel gövdedir.
        title: l10n.notificationTitle,
        body: l10n.notificationBodyNoBody,
        payload: desired.payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: details,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
      title: _title(note, l10n),
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
    if (notification.channelId == _channelId) {
      return noteIdFromNotificationId(id);
    }
    if (notification.channelId == _legacyChannelId) {
      return id ~/ _legacyOccurrenceSpan;
    }
    return null;
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

  static String _title(Note note, L10n l10n) =>
      note.body.isEmpty ? l10n.notificationTitleNoBody : 'Latermark Pro';

  static String _body(Note note, L10n l10n) =>
      note.body.isEmpty ? l10n.notificationBodyNoBody : note.body;
}

String _payload(ScheduledReminder reminder, Note note) {
  if (reminder.repeatsIndefinitely) {
    final anchor = note.reminderAnchorAt ?? note.createdAt;
    return 'note/${note.id}/v2/every/${note.remindAfterDays}/'
        '${anchor.toUtc().millisecondsSinceEpoch}';
  }
  return 'note/${note.id}/v2/at/'
      '${reminder.at.toUtc().millisecondsSinceEpoch}';
}

final class _DesiredReminder {
  const _DesiredReminder({
    required this.reminder,
    required this.note,
    required this.payload,
  });

  final ScheduledReminder reminder;
  final Note note;
  final String payload;
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

  final validV2At =
      segments.length == 5 &&
      segments[2] == 'v2' &&
      segments[3] == 'at' &&
      int.tryParse(segments[4]) != null;
  final everyDays = segments.length == 6 && segments[3] == 'every'
      ? int.tryParse(segments[4])
      : null;
  final validV2Every =
      segments.length == 6 &&
      segments[2] == 'v2' &&
      segments[3] == 'every' &&
      everyDays != null &&
      everyDays > 0 &&
      int.tryParse(segments[5]) != null;
  return validV2At || validV2Every ? noteId : null;
}
