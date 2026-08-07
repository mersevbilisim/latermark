import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../notes/data/notes_database.dart';
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
  ReminderService();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _settingsChannel = MethodChannel('latermark/app_settings');

  bool _ready = false;

  /// Bildirim kimlikleri not kimlikleriyle birebir aynı; böylece bir notu
  /// yeniden planlamak eskisini kendiliğinden değiştirir.
  static const _channelId = 'latermark_reminders';

  static bool get _supported => Platform.isIOS || Platform.isAndroid;

  Future<void> initialize() async {
    if (_ready || !_supported) return;

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
    );
    _ready = true;
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

  /// Tüm hatırlatmaları baştan kurar.
  ///
  /// Tek tek güncellemek yerine hepsini silip yeniden planlamak, notların
  /// silinmesi/süresinin dolması gibi durumlarda hayalet bildirim kalmasını
  /// imkânsız kılıyor. Bildirim sayısı not sayısı kadar, yani zaten küçük.
  Future<void> sync(List<Note> notes, AppSettings settings, L10n l10n) async {
    if (!_supported) return;
    await initialize();

    try {
      await _plugin.cancelAll();
      if (!settings.reminderEnabled) return;
      if (!await hasPermission()) return;

      final now = tz.TZDateTime.now(tz.UTC);

      for (final note in notes) {
        // Süre verilmemiş kayıtlar sessiz kalır.
        if (note.remindAfterDays <= 0) continue;

        final at = tz.TZDateTime.from(
          note.createdAt.add(Duration(days: note.remindAfterDays)).toUtc(),
          tz.UTC,
        );

        // Geçmişte kalanı planlamanın anlamı yok.
        if (!at.isAfter(now)) continue;
        // Hatırlatmadan önce zaten silinecekse hiç kurma.
        if (note.expiresAt != null && !note.expiresAt!.isAfter(at)) continue;

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

  Future<void> cancelAll() async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancelAll();
    } on PlatformException {
      // Yoksay.
    }
  }

  static String _title(Note note, L10n l10n) => note.body.isEmpty
      ? l10n.notificationTitleNoBody
      : l10n.notificationTitle;

  static String _body(Note note, L10n l10n) =>
      note.body.isEmpty ? l10n.notificationBodyNoBody : note.body;
}
