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

  /// Bildirim kimlikleri not kimlikleriyle birebir aynı; böylece bir notu
  /// yeniden planlamak eskisini kendiliğinden değiştirir.
  static const _channelId = 'latermark_reminders';

  bool get _supported =>
      _supportedOverride ?? (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

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
      if (Platform.isIOS) {
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
      if (Platform.isIOS) {
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

  /// Bekleyen hatırlatma programını baştan kurar.
  ///
  /// Tek tek zaman karşılaştırmak yerine bekleyen istekleri yenilemek, notların
  /// düzenlenmesi ve saat değişikliklerinde programı deterministik tutar.
  /// Daha önce teslim edilmiş geçerli bildirimler burada korunur; yalnız
  /// silinmiş notların hayalet bildirimleri ayıklanır.
  Future<void> sync(List<Note> notes, AppSettings settings, L10n l10n) async {
    if (!_supported) return;
    await initialize();

    try {
      // Ana şalter kapatıldığında hem bekleyen hem de daha önce teslim edilmiş
      // Latermark bildirimleri temizlenir. Açıkken ise yalnız bekleyen programı
      // yeniden kurarız; okunmamış, teslim edilmiş başka bir not bildirimi sırf
      // veritabanında bir şey değişti diye tepsiden kaybolmamalı.
      // Mağaza hakkı ana şalterden bağımsız bir güvenlik sınırıdır. Eski bir
      // ayar satırı `reminderEnabled=true` taşısa bile iade/geri alma sonrası
      // Pro yoksa bekleyen ve teslim edilmiş Latermark bildirimleri kalmaz.
      if (!settings.proUnlocked || !settings.reminderEnabled) {
        await _plugin.cancelAll();
        return;
      }

      await _plugin.cancelAllPendingNotifications();
      await _removeOrphanedDeliveredNotifications(notes);
      if (!await hasPermission()) return;

      final now = tz.TZDateTime.now(tz.UTC);

      for (final note in notes) {
        final pendingAt = pendingReminderAt(
          createdAt: note.createdAt,
          remindAfterDays: note.remindAfterDays,
          expiresAt: note.expiresAt,
          now: now,
        );
        if (pendingAt == null) continue;
        final at = tz.TZDateTime.from(pendingAt.toUtc(), tz.UTC);

        await _plugin.zonedSchedule(
          id: note.id,
          scheduledDate: at,
          title: _title(note, l10n),
          body: _body(note, l10n),
          payload: 'note/${note.id}',
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              l10n.notificationChannelName,
              channelDescription: l10n.notificationChannelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              // Android dokunulduğunda kendi satırını tepsiden anında siler.
              autoCancel: true,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    } on PlatformException catch (error) {
      // İzin yoksa veya tam zamanlı alarm hakkı verilmemişse sessizce geç.
      debugPrint('Hatırlatmalar kurulamadı: $error');
    }
  }

  /// İlgili notun sistem tepsisindeki teslim edilmiş bildirimini kaldırır.
  ///
  /// Önce aktif listeyi okumamız bilinçli: `cancel(id:)` bekleyen isteği de
  /// kaldırır. Kullanıcı hatırlatma tarihi gelmeden nota kendi kendine bakarsa
  /// gelecekte istediği hatırlatmayı yanlışlıkla iptal etmemeliyiz.
  Future<void> dismissNote(int noteId) async {
    if (!_supported || _disposed || noteId <= 0) return;
    await initialize();

    try {
      final active = await _plugin.getActiveNotifications();
      final delivered = active.any(
        (notification) => _noteIdOf(notification) == noteId,
      );
      if (delivered) await _plugin.cancel(id: noteId);
    } on PlatformException catch (error) {
      debugPrint('Not bildirimi kapatılamadı: $error');
    }
  }

  /// Uygulama kapalıyken süresi dolup silinen bir nota ait teslim edilmiş
  /// bildirimi de geride bırakma. Geçerli notların okunmamış bildirimlerine
  /// dokunulmaz; onlar kullanıcı notu açana kadar tepside kalabilir.
  Future<void> _removeOrphanedDeliveredNotifications(List<Note> notes) async {
    final noteIds = notes.map((note) => note.id).toSet();
    final active = await _plugin.getActiveNotifications();

    for (final notification in active) {
      final noteId = _noteIdOf(notification);
      if (noteId != null && !noteIds.contains(noteId)) {
        await _plugin.cancel(id: noteId);
      }
    }
  }

  int? _noteIdOf(ActiveNotification notification) => Platform.isAndroid
      ? (notification.channelId == _channelId ? notification.id : null)
      : noteIdFromReminderPayload(notification.payload);

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

/// Yalnızca bu servisin ürettiği `note/<pozitif kimlik>` biçimini kabul eder.
int? noteIdFromReminderPayload(String? payload) {
  if (payload == null) return null;
  final segments = payload.split('/');
  if (segments.length != 2 || segments.first != 'note') return null;

  final noteId = int.tryParse(segments.last);
  return noteId != null && noteId > 0 ? noteId : null;
}
