import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../notes/data/notes_database.dart';
import '../settings/domain/app_settings.dart';

/// "Bu nota bir süredir bakmadın" hatırlatıcısı.
///
/// Her notun kendi bildirimi vardır ve zamanı, nota **en son bakılan andan**
/// itibaren sayılır. Kayda girildiğinde sayaç sıfırlanır, yani hatırlatma
/// ileri atılır. Bu yüzden hatırlatıcı bir alarm değil, unutulmuşluk ölçüsü.
class ReminderService {
  ReminderService();

  final _plugin = FlutterLocalNotificationsPlugin();

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
  /// İzin verilirse `true` döner. Reddedilirse ayar açık kalır ama bildirim
  /// gitmez; kullanıcı sistem ayarlarından izin verdiğinde kendiliğinden
  /// çalışmaya başlar.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await initialize();

    try {
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
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

  /// Tüm hatırlatmaları baştan kurar.
  ///
  /// Tek tek güncellemek yerine hepsini silip yeniden planlamak, notların
  /// silinmesi/süresinin dolması gibi durumlarda hayalet bildirim kalmasını
  /// imkânsız kılıyor. Bildirim sayısı not sayısı kadar, yani zaten küçük.
  Future<void> sync(List<Note> notes, AppSettings settings) async {
    if (!_supported) return;
    await initialize();

    try {
      await _plugin.cancelAll();
      if (!settings.reminderEnabled) return;

      final now = tz.TZDateTime.now(tz.UTC);
      final delay = settings.reminderDelay.duration;

      for (final note in notes) {
        final seen = note.lastSeenAt ?? note.createdAt;
        final at = tz.TZDateTime.from(seen.add(delay).toUtc(), tz.UTC);

        // Geçmişte kalanı planlamanın anlamı yok.
        if (!at.isAfter(now)) continue;
        // Hatırlatmadan önce zaten silinecekse hiç kurma.
        if (note.expiresAt != null && !note.expiresAt!.isAfter(at)) continue;

        await _plugin.zonedSchedule(
          id: note.id,
          scheduledDate: at,
          title: _title(note),
          body: _body(note),
          payload: 'note/${note.id}',
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Hatırlatmalar',
              channelDescription:
                  'Bir süredir bakmadığın kayıtları hatırlatır.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
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

  static String _title(Note note) =>
      note.body.isEmpty ? 'Bir kare bekliyor' : 'Hatırlatma';

  static String _body(Note note) => note.body.isEmpty
      ? 'Bu kareye bir süredir bakmadın.'
      : note.body;
}
