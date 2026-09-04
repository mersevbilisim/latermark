import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/reminder_action.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/reminders/reminder_service.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// 1×1 saydam PNG. Ek hazırlama kodu dosyayı gerçekten çözdüğü için
/// testte de geçerli bir görüntü gerekiyor.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 2048×2048, sıkıştırmasız siyah BMP. Kaynak 10 MB'tan büyük; bildirime giden
/// 1024 px PNG ise küçük. Böylece Apple'ın **çıktı** sınırını yanlışlıkla
/// kaynağa uygulamadığımız gerçek bir codec yoluyla sınanır.
Uint8List _oversizedBmp() {
  const width = 2048;
  const height = 2048;
  const headerLength = 54;
  const rowLength = width * 3;
  const imageLength = rowLength * height;
  const fileLength = headerLength + imageLength;
  final bytes = Uint8List(fileLength);
  final header = ByteData.view(bytes.buffer);
  bytes[0] = 0x42;
  bytes[1] = 0x4d;
  header.setUint32(2, fileLength, Endian.little);
  header.setUint32(10, headerLength, Endian.little);
  header.setUint32(14, 40, Endian.little);
  header.setInt32(18, width, Endian.little);
  header.setInt32(22, height, Endian.little);
  header.setUint16(26, 1, Endian.little);
  header.setUint16(28, 24, Endian.little);
  header.setUint32(34, imageLength, Endian.little);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const actionChannel = MethodChannel('latermark/reminder_actions');
  // Ek kopyalarının yaşadığı kalıcı dizin path_provider'dan geliyor; testte
  // eklenti yok, sahtesi olmadan kare hiç iliştirilmez.
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('bildirim not bağlantısı', () {
    late List<MethodCall> calls;
    late Map<String, Object?> launchDetails;
    late List<Map<String, Object?>> activeNotifications;
    late List<Map<String, Object?>> pendingNotifications;
    late PlatformException? Function(MethodCall call) notificationFailure;
    late Map<String, Object?>? permissionOptions;
    late bool? requestedPermission;

    late Directory support;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      support = Directory.systemTemp.createTempSync('lm_support');
      messenger.setMockMethodCallHandler(pathProvider, (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return support.path;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(actionChannel, (call) async {
        if (call.method == 'timeZoneIdentifier') return 'Europe/Istanbul';
        return null;
      });
      calls = <MethodCall>[];
      launchDetails = <String, Object?>{'notificationLaunchedApp': false};
      activeNotifications = <Map<String, Object?>>[];
      pendingNotifications = <Map<String, Object?>>[];
      notificationFailure = (_) => null;
      permissionOptions = <String, Object?>{'isEnabled': true};
      requestedPermission = null;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final failure = notificationFailure(call);
        if (failure != null) throw failure;
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return launchDetails;
        }
        if (call.method == 'checkPermissions') {
          return permissionOptions;
        }
        if (call.method == 'requestPermissions') return requestedPermission;
        if (call.method == 'getActiveNotifications') {
          return activeNotifications;
        }
        if (call.method == 'pendingNotificationRequests') {
          return pendingNotifications;
        }
        if (call.method == 'zonedSchedule' ||
            call.method == 'periodicallyShowWithDuration') {
          final arguments = (call.arguments as Map).cast<String, Object?>();
          final id = arguments['id']! as int;
          pendingNotifications.removeWhere((item) => item['id'] == id);
          pendingNotifications.add(<String, Object?>{
            'id': id,
            'title': arguments['title'],
            'body': arguments['body'],
            'payload': arguments['payload'],
          });
        }
        if (call.method == 'cancel') {
          pendingNotifications.removeWhere(
            (item) => item['id'] == call.arguments,
          );
        }
        if (call.method == 'cancelAll' ||
            call.method == 'cancelAllPendingNotifications') {
          pendingNotifications.clear();
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(pathProvider, null);
      messenger.setMockMethodCallHandler(actionChannel, null);
      if (support.existsSync()) support.deleteSync(recursive: true);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'cold-start payload dinleyiciden önce gelse de bir kez teslim edilir',
      () async {
        launchDetails = <String, Object?>{
          'notificationLaunchedApp': true,
          'notificationResponse': <String, Object?>{
            'notificationId': 42,
            'actionId': null,
            'input': null,
            'notificationResponseType': 0,
            'payload': 'note/42',
            'data': <String, Object?>{},
          },
        };
        final service = ReminderService(supported: true);

        await Future.wait([service.initialize(), service.initialize()]);

        final received = <int>[];
        final subscription = service.listenNoteTaps(received.add);
        expect(received, [42]);
        expect(
          calls.where((call) => call.method == 'initialize'),
          hasLength(1),
        );
        expect(
          calls.where(
            (call) => call.method == 'getNotificationAppLaunchDetails',
          ),
          hasLength(1),
        );

        await subscription.cancel();
        await service.dispose();
      },
    );

    test('iOS kategorileri nota özel kapatmayı doğru yerde sunar', () async {
      final service = ReminderService(supported: true);
      await service.initialize();

      final initialize = calls.singleWhere(
        (call) => call.method == 'initialize',
      );
      final arguments = (initialize.arguments as Map).cast<String, Object?>();
      final categories = (arguments['notificationCategories']! as List)
          .cast<Map>();
      final byId = <String, Map>{
        for (final category in categories)
          category['identifier']! as String: category,
      };

      List<String> actionIds(String categoryId) =>
          (byId[categoryId]!['actions']! as List)
              .cast<Map>()
              .map((action) => action['identifier']! as String)
              .toList();

      expect(actionIds('latermark.reminder.once'), [
        ReminderAction.done.id,
        ReminderAction.tomorrow.id,
        ReminderAction.nextWeek.id,
        ReminderAction.turnOff.id,
      ]);
      expect(actionIds('latermark.reminder.repeat'), [
        ReminderAction.done.id,
        ReminderAction.turnOff.id,
      ]);
      final turnOff = (byId['latermark.reminder.once']!['actions']! as List)
          .cast<Map>()
          .singleWhere(
            (action) => action['identifier'] == ReminderAction.turnOff.id,
          );
      expect(turnOff['title'], isNotEmpty);
      expect(turnOff['options'], [2]);

      await service.dispose();
    });

    test('iOS izin durumu kesin sonuçları yayınlar', () async {
      final service = ReminderService(supported: true);

      permissionOptions = <String, Object?>{'isEnabled': false};
      expect(await service.refreshPermission(), ReminderPermissionState.denied);
      expect(service.permission.value, ReminderPermissionState.denied);

      permissionOptions = <String, Object?>{
        'isEnabled': false,
        'isProvisionalEnabled': true,
      };
      expect(
        await service.refreshPermission(),
        ReminderPermissionState.granted,
      );
      expect(service.permission.value, ReminderPermissionState.granted);

      await service.dispose();
    });

    test('bilinmeyen izin cevabı son kesin durumu silmez', () async {
      final service = ReminderService(supported: true);
      await service.refreshPermission();
      expect(service.permission.value, ReminderPermissionState.granted);

      permissionOptions = null;
      expect(
        await service.refreshPermission(),
        ReminderPermissionState.unknown,
      );
      expect(service.permission.value, ReminderPermissionState.granted);

      notificationFailure = (call) => call.method == 'checkPermissions'
          ? PlatformException(code: 'transient')
          : null;
      expect(
        await service.refreshPermission(),
        ReminderPermissionState.unknown,
      );
      expect(service.permission.value, ReminderPermissionState.granted);

      await service.dispose();
    });

    test('izin cevabı unknown iken bekleyen alarm değiştirilmez', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final id = reminderNotificationId(26, 0);
      pendingNotifications = <Map<String, Object?>>[
        <String, Object?>{'id': id, 'payload': 'note/26/v4/at/1000/art1/none'},
      ];
      permissionOptions = null;
      final note = Note(
        id: 26,
        imageName: '26.jpg',
        body: 'Transient permission read',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(anchor, 3),
        remindEveryDays: 0,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(calls.where((call) => call.method == 'cancel'), isEmpty);
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      expect(pendingNotifications.single['id'], id);
      await service.dispose();
    });

    test('geciken izin okuması kullanıcı reddini ezemez', () async {
      final check = Completer<Map<String, Object?>?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return launchDetails;
        }
        if (call.method == 'checkPermissions') return check.future;
        if (call.method == 'requestPermissions') return false;
        return null;
      });
      final service = ReminderService(supported: true);

      final staleRead = service.refreshPermission();
      while (!calls.any((call) => call.method == 'checkPermissions')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await service.requestPermission(), isFalse);
      expect(service.permission.value, ReminderPermissionState.denied);

      check.complete(<String, Object?>{'isEnabled': true});
      expect(await staleRead, ReminderPermissionState.unknown);
      expect(service.permission.value, ReminderPermissionState.denied);

      await service.dispose();
    });

    test('açık uygulamadaki dokunuş callback payloadını yayınlar', () async {
      final service = ReminderService(supported: true);
      final received = <int>[];
      final subscription = service.listenNoteTaps(received.add);
      await service.initialize();

      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('didReceiveNotificationResponse', <String, Object?>{
            'notificationId': 7,
            'actionId': null,
            'input': null,
            'payload': 'note/7',
            'notificationResponseType': 0,
          }),
        ),
        (ByteData? _) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, [7]);

      await subscription.cancel();
      await service.dispose();
    });

    test('not açılınca aynı kimlikteki bildirim kaldırılır', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      calls.clear();
      activeNotifications = <Map<String, Object?>>[
        <String, Object?>{'id': 23, 'payload': 'note/23'},
      ];

      expect(await service.dismissNote(23), isTrue);

      expect(
        calls,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'cancel')
              .having((call) => call.arguments, 'id', 23),
        ),
      );
      await service.dispose();
    });

    test('henüz teslim edilmemiş hatırlatma nota bakınca korunur', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      calls.clear();

      expect(await service.dismissNote(24), isFalse);

      expect(calls.where((call) => call.method == 'cancel'), isEmpty);
      await service.dispose();
    });

    test('senkron bekleyen programı topluca silmez', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      calls.clear();
      final l10n = await L10n.delegate.load(const Locale('en'));

      await service.sync(
        const [],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(
        calls.where((call) => call.method == 'cancelAllPendingNotifications'),
        isEmpty,
      );
      expect(
        calls.where((call) => call.method == 'pendingNotificationRequests'),
        hasLength(1),
      );
      expect(calls.where((call) => call.method == 'cancelAll'), isEmpty);
      await service.dispose();
    });

    /// Ayarlardaki ana şalter: kapatınca yalnız yeni kurulum durmaz, işletim
    /// sistemine **kurulmuş** hatırlatmalar da iptal edilir. Aksi hâlde
    /// kullanıcı anahtarı kapattıktan sonra bile bildirim almaya devam ederdi.
    test('ana şalter kapatılınca kurulmuş hatırlatmalar iptal edilir', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final pending = Note(
        id: 61,
        imageName: '61.jpg',
        body: 'Fatura',
        createdAt: DateTime.now(),
        retention: Retention.off,
        customMinutes: 0,
        remindAt: DateTime.now().add(const Duration(days: 2)),
        remindEveryDays: 0,
      );

      // Önce açıkken kuruluyor.
      calls.clear();
      await service.sync(
        [pending],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );
      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        isNotEmpty,
        reason: 'açıkken kurulmalıydı',
      );

      // Şalter kapanıyor: not listesi aynı, tercih değişti.
      calls.clear();
      final off = await service.sync(
        [pending],
        const AppSettings(reminderEnabled: false, proUnlocked: true),
        l10n,
      );

      expect(calls.where((call) => call.method == 'cancelAll'), hasLength(1));
      // Program **bilinen** biçimde boş. Çağıran ücretsiz hak defterini buna
      // dayanarak temizliyor: eskiden alarm kalkıyor ama defter kalıyordu ve
      // zamanı gelince hiç çalmamış bildirim için hak yanıyordu.
      expect(off.scheduled, isEmpty);
      expect(off.scheduleKnown, isTrue);
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);

      // Şalter yeniden açılınca not kendi `remindAt` değerinden geri kuruluyor:
      // kapatmak seçimi silmiyor.
      calls.clear();
      await service.sync(
        [pending],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );
      expect(calls.where((call) => call.method == 'zonedSchedule'), isNotEmpty);

      await service.dispose();
    });

    test(
      'Free kullanıcıda şalter açıksa tek atışlı bildirim kurulur',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        final pending = Note(
          id: 62,
          imageName: '62.jpg',
          body: 'Park',
          createdAt: DateTime.now(),
          retention: Retention.off,
          customMinutes: 0,
          remindAt: DateTime.now().add(const Duration(days: 2)),
          remindEveryDays: 0,
        );

        calls.clear();
        await service.sync(
          [pending],
          const AppSettings(reminderEnabled: true, proUnlocked: false),
          l10n,
        );

        expect(calls.where((call) => call.method == 'cancelAll'), isEmpty);
        expect(
          calls.where((call) => call.method == 'zonedSchedule'),
          hasLength(1),
        );

        await service.dispose();
      },
    );

    test('zamanı gelmiş tek seferlik hatırlatma yeniden kurulmaz', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final delivered = Note(
        id: 25,
        imageName: '25.jpg',
        body: 'Already reminded',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(
          DateTime.now().subtract(const Duration(days: 2)),
          1,
        ),
        remindEveryDays: 0,
      );

      calls.clear();
      await service.sync(
        [delivered],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      await service.dispose();
    });

    test('günlük tekrar iOS takvim saatini koruyan tek kayıt olur', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final note = Note(
        id: 40,
        imageName: '40.jpg',
        body: 'Her gün',
        createdAt: DateTime.now(),
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(DateTime.now(), 1),
        remindEveryDays: 1,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final calendar = calls.where((call) => call.method == 'zonedSchedule');
      expect(calendar, hasLength(1));
      final arguments = calendar.single.arguments as Map;
      expect(arguments['id'], reminderNotificationId(40, 0));
      expect(
        arguments['matchDateTimeComponents'],
        DateTimeComponents.time.index,
      );
      expect(
        ((arguments['platformSpecifics'] as Map)['categoryIdentifier']),
        'latermark.reminder.repeat',
      );
      expect(
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      await service.dispose();
    });

    test('zamansız gövde karesiz kayıtta kareden söz etmiyor', () async {
      // Yinelenen kayıt işletim sisteminde aylarca bekliyor, bu yüzden gövde
      // notun kendi metni değil zamansız bir cümle. O cümle fotoğraflı kayıtta
      // "kare"den söz ediyor — karesiz kayıtta ortada kare yok ve Siri'nin
      // hatırlatmalı not akışı tam olarak o kaydı üretiyor.
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final at = shiftLocalCalendarDays(DateTime.now(), 1);
      Note noteWith(int id, String imageName) => Note(
        id: id,
        imageName: imageName,
        body: 'Her gün',
        createdAt: DateTime.now(),
        retention: Retention.off,
        customMinutes: 0,
        remindAt: at,
        remindEveryDays: 1,
      );

      calls.clear();
      await service.sync(
        [noteWith(41, '41.jpg'), noteWith(42, '')],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final bodies = {
        for (final call in calls.where((c) => c.method == 'zonedSchedule'))
          (call.arguments as Map)['id'] as int:
              (call.arguments as Map)['body'] as String,
      };
      expect(
        bodies[reminderNotificationId(41, 0)],
        l10n.notificationBodyNoBody,
      );
      expect(
        bodies[reminderNotificationId(42, 0)],
        l10n.notificationBodyNoFrame,
      );
      // İkisi gerçekten ayrışıyor; aynı dizeye düşen bir geri adım testi
      // sessizce geçmesin.
      expect(l10n.notificationBodyNoFrame, isNot(l10n.notificationBodyNoBody));
      await service.dispose();
    });

    test('saat dilimi her senkronda köprüden okunmuyor', () async {
      // Bölge ancak uygulama arkadayken değişebilir; bir notun düzenlenmesi
      // onu değiştirmez. Eskiden her senkron native kanala gidiyordu ve
      // senkron her kayıt değişiminde koşuyor.
      var reads = 0;
      messenger.setMockMethodCallHandler(actionChannel, (call) async {
        if (call.method == 'timeZoneIdentifier') {
          reads++;
          return 'Europe/Istanbul';
        }
        return null;
      });

      final service = ReminderService(supported: true);
      final l10n = await L10n.delegate.load(const Locale('en'));
      const settings = AppSettings(reminderEnabled: true, proUnlocked: true);

      await service.sync(const [], settings, l10n);
      expect(reads, 1);

      await service.sync(const [], settings, l10n);
      await service.sync(const [], settings, l10n);
      expect(reads, 1, reason: 'sonraki senkronlar köprüye gitmiyor');

      // Öne dönüşte yeniden okunuyor: kullanıcı seyahatte olabilir.
      service.invalidateTimeZone();
      await service.sync(const [], settings, l10n);
      expect(reads, 2);
      await service.dispose();
    });

    test('debug Pro test bildirimi tek immediate show çağrısı yapar', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final note = Note(
        id: 404,
        imageName: '404.jpg',
        body: 'Test notification body',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(anchor, 3),
        remindEveryDays: 3,
      );

      requestedPermission = true;
      calls.clear();
      expect(
        await service.sendDebugTestNotification(
          note: note,
          l10n: l10n,
          debugProEnabled: true,
        ),
        isTrue,
      );

      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      expect(
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      final shown = calls.singleWhere((call) => call.method == 'show');
      final arguments = shown.arguments as Map;
      expect(arguments['id'], 0);
      expect(arguments['body'], 'Test notification body');
      expect(arguments['payload'], 'note/404');

      calls.clear();
      expect(
        await service.sendDebugTestNotification(
          note: note,
          l10n: l10n,
          debugProEnabled: false,
        ),
        isFalse,
      );
      expect(calls.where((call) => call.method == 'show'), isEmpty);
      await service.dispose();
    });

    test(
      'eski 60 exact debug kaydı tek çağrıyla gün programına taşınır',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now();
        final note = Note(
          id: 405,
          imageName: '405.jpg',
          body: 'Migration',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: shiftLocalCalendarDays(anchor, 3),
          remindEveryDays: 3,
        );
        pendingNotifications = [
          for (
            var occurrence = 0;
            occurrence < kPendingReminderBudget;
            occurrence++
          )
            <String, Object?>{
              'id': reminderNotificationId(405, occurrence),
              'payload':
                  'note/405/v5/at/'
                  '${anchor.add(Duration(minutes: 3 * (occurrence + 1))).toUtc().millisecondsSinceEpoch}'
                  '/art1/none',
            },
        ];

        calls.clear();
        await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        expect(
          calls.where((call) => call.method == 'cancelAllPendingNotifications'),
          hasLength(1),
        );
        expect(calls.where((call) => call.method == 'cancel'), isEmpty);
        expect(
          calls.where((call) => call.method == 'periodicallyShowWithDuration'),
          isEmpty,
        );
        // Ritim işletim sisteminin takvim eşlemesine bırakıldığı için tek
        // kayıt yetiyor; kayan pencereye gerek kalmadı.
        expect(
          calls.where((call) => call.method == 'zonedSchedule'),
          hasLength(1),
        );
        expect(pendingNotifications, hasLength(1));
        await service.dispose();
      },
    );

    test('bildirim başlığı uygulamanın adı, gövdesi notun kendisi', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now().subtract(const Duration(days: 1));
      final note = Note(
        id: 500,
        imageName: '500.jpg',
        body: 'Şelale fotoğrafı',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(anchor, 3),
        remindEveryDays: 0,
        updatedAt: anchor,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final scheduled = calls.where((call) => call.method == 'zonedSchedule');
      expect(scheduled, isNotEmpty);
      final arguments = (scheduled.first.arguments as Map)
          .cast<String, Object?>();
      // Kilit ekranında satırın kimden geldiği başlıktan okunuyor; "Reminder"
      // gibi genel bir sözcük her uygulamada aynı görünüyordu.
      expect(arguments['title'], 'Latermark Pro');
      expect(arguments['body'], 'Şelale fotoğrafı');
      expect(
        ((arguments['platformSpecifics'] as Map)['categoryIdentifier']),
        'latermark.reminder.once',
      );
      await service.dispose();
    });

    test('notun karesi bildirime kopya olarak iliştirilir', () async {
      final sandbox = Directory.systemTemp.createTempSync('lm_art');
      addTearDown(() => sandbox.deleteSync(recursive: true));
      final photo = File('${sandbox.path}/500.png')..writeAsBytesSync(_png);

      final service = ReminderService(supported: true);
      await service.initialize();
      service.photoOf = (_) => photo;
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now().subtract(const Duration(days: 1));
      final note = Note(
        id: 501,
        imageName: '501.jpg',
        body: 'Kare',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(anchor, 3),
        remindEveryDays: 0,
        updatedAt: anchor,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final scheduled = calls.where((call) => call.method == 'zonedSchedule');
      expect(scheduled, isNotEmpty);
      final arguments = (scheduled.first.arguments as Map)
          .cast<String, Object?>();
      final specifics = (arguments['platformSpecifics']! as Map)
          .cast<String, Object?>();
      final attachments = (specifics['attachments']! as List)
          .cast<Map<Object?, Object?>>();
      expect(attachments, hasLength(1));
      final attached = attachments.single['filePath']! as String;

      // iOS eki kendi deposuna **taşır**, Android ise bitmap'i bizim
      // sürecimizde tam çözünürlükte çözer. İkisi için de giden şey asıl kare
      // değil, küçültülmüş tek kullanımlık bir kopya.
      expect(attached, isNot(photo.path));
      expect(attached, endsWith('.png'));
      expect(File(attached).existsSync(), isTrue);
      expect(File(attached).lengthSync(), lessThanOrEqualTo(10 * 1024 * 1024));
      expect(photo.existsSync(), isTrue);
      await service.dispose();
    });

    test(
      'uzantısı desteklenmeyen ve 10 MB üstü kaynak destekli çıktıya çevrilir',
      () async {
        final sandbox = Directory.systemTemp.createTempSync('lm_heic');
        addTearDown(() => sandbox.deleteSync(recursive: true));
        final photo = File('${sandbox.path}/502.heic')
          ..writeAsBytesSync(_oversizedBmp(), flush: true);
        expect(photo.lengthSync(), greaterThan(10 * 1024 * 1024));

        final service = ReminderService(supported: true);
        await service.initialize();
        service.photoOf = (_) => photo;
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now().subtract(const Duration(days: 1));
        final note = Note(
          id: 502,
          imageName: '502.heic',
          body: 'HEIC kare',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: shiftLocalCalendarDays(anchor, 3),
          remindEveryDays: 0,
          updatedAt: anchor,
        );

        calls.clear();
        await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        final scheduled = calls.where((call) => call.method == 'zonedSchedule');
        expect(scheduled, isNotEmpty, reason: 'hatırlatma yine kurulmalı');
        final specifics =
            ((scheduled.first.arguments as Map)['platformSpecifics']! as Map)
                .cast<String, Object?>();
        final attachments = (specifics['attachments']! as List)
            .cast<Map<Object?, Object?>>();
        expect(attachments, hasLength(1));
        final attached = attachments.single['filePath']! as String;
        expect(attached, endsWith('.png'));
        expect(
          File(attached).lengthSync(),
          lessThanOrEqualTo(10 * 1024 * 1024),
        );
        await service.dispose();
      },
    );

    test(
      'ilk karesiz kurulum fotoğraf gelince fingerprint ile onarılır',
      () async {
        final sandbox = Directory.systemTemp.createTempSync('lm_art_repair');
        addTearDown(() => sandbox.deleteSync(recursive: true));
        final photo = File('${sandbox.path}/503.heic');

        final service = ReminderService(supported: true);
        await service.initialize();
        service.photoOf = (_) => photo;
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now().subtract(const Duration(days: 1));
        final note = Note(
          id: 503,
          imageName: '503.heic',
          body: 'Sonradan gelen kare',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: shiftLocalCalendarDays(anchor, 3),
          remindEveryDays: 0,
          updatedAt: anchor,
        );
        const settings = AppSettings(reminderEnabled: true, proUnlocked: true);

        calls.clear();
        await service.sync([note], settings, l10n);
        final first = calls.singleWhere(
          (call) => call.method == 'zonedSchedule',
        );
        final firstArguments = (first.arguments as Map).cast<String, Object?>();
        final firstPayload = firstArguments['payload']! as String;
        expect(firstPayload, contains('/v6/'));
        expect(firstPayload, endsWith('/art1/none'));
        final firstSpecifics = (firstArguments['platformSpecifics']! as Map)
            .cast<String, Object?>();
        expect(firstSpecifics['attachments'], anyOf(isNull, isEmpty));

        photo.writeAsBytesSync(_png, flush: true);
        calls.clear();
        await service.sync([note], settings, l10n);

        final id = reminderNotificationId(503, 0);
        expect(
          calls.where(
            (call) => call.method == 'cancel' && call.arguments == id,
          ),
          hasLength(1),
        );
        final repaired = calls.singleWhere(
          (call) => call.method == 'zonedSchedule',
        );
        final repairedArguments = (repaired.arguments as Map)
            .cast<String, Object?>();
        expect(repairedArguments['payload'], isNot(firstPayload));
        final repairedSpecifics =
            (repairedArguments['platformSpecifics']! as Map)
                .cast<String, Object?>();
        expect(repairedSpecifics['attachments'], isNotEmpty);
        await service.dispose();
      },
    );

    test(
      'native attachment reddi karesiz denenir ve sonraki kayıt yine kurulur',
      () async {
        final sandbox = Directory.systemTemp.createTempSync('lm_art_retry');
        addTearDown(() => sandbox.deleteSync(recursive: true));
        final photo = File('${sandbox.path}/retry.png')
          ..writeAsBytesSync(_png, flush: true);
        final firstId = reminderNotificationId(610, 0);
        var rejected = false;
        notificationFailure = (call) {
          if (rejected || call.method != 'zonedSchedule') return null;
          final arguments = (call.arguments as Map).cast<String, Object?>();
          if (arguments['id'] != firstId) return null;
          final specifics = (arguments['platformSpecifics']! as Map)
              .cast<String, Object?>();
          final attachments = specifics['attachments'];
          if (attachments is! List || attachments.isEmpty) return null;
          rejected = true;
          return PlatformException(
            code: 'attachment_invalid',
            message: 'UNNotificationAttachment rejected the file',
          );
        };

        final service = ReminderService(supported: true);
        await service.initialize();
        service.photoOf = (_) => photo;
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now().subtract(const Duration(days: 1));
        Note note(int id) => Note(
          id: id,
          imageName: '$id.png',
          body: 'Kare $id',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: shiftLocalCalendarDays(anchor, 3),
          remindEveryDays: 0,
          updatedAt: anchor,
        );

        calls.clear();
        await service.sync(
          [note(610), note(611)],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        final scheduled = calls
            .where((call) => call.method == 'zonedSchedule')
            .toList();
        final firstCalls = scheduled.where(
          (call) => (call.arguments as Map)['id'] == firstId,
        );
        expect(firstCalls, hasLength(2));
        final firstAttachments = firstCalls.map(
          (call) =>
              ((call.arguments as Map)['platformSpecifics']
                  as Map)['attachments'],
        );
        expect(firstAttachments.first, isNotEmpty);
        expect(firstAttachments.last, anyOf(isNull, isEmpty));

        final secondId = reminderNotificationId(611, 0);
        final secondCalls = scheduled.where(
          (call) => (call.arguments as Map)['id'] == secondId,
        );
        expect(secondCalls, hasLength(1));
        final secondSpecifics =
            ((secondCalls.single.arguments as Map)['platformSpecifics'] as Map);
        expect(secondSpecifics['attachments'], isNotEmpty);
        expect(
          pendingNotifications.map((request) => request['id']),
          containsAll(<int>[firstId, secondId]),
        );
        await service.dispose();
      },
    );

    test(
      'kare kopyası kalıcı dizinde yaşar ve plandan düşünce silinir',
      () async {
        // Android bildirimi kurulum anında değil, alarm çaldığı anda kuruyor ve
        // dosyayı *o an* okuyor. Kopya kurulumdan sonra silinseydi kare günler
        // sonra çalan bildirimde kaybolurdu.
        final sandbox = Directory.systemTemp.createTempSync('lm_keep');
        addTearDown(() => sandbox.deleteSync(recursive: true));
        final photo = File('${sandbox.path}/600.png')..writeAsBytesSync(_png);

        final service = ReminderService(supported: true);
        await service.initialize();
        service.photoOf = (_) => photo;
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now().subtract(const Duration(days: 1));
        Note noteWith({DateTime? remindAt}) => Note(
          id: 600,
          imageName: '600.png',
          body: 'Kare',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: remindAt,
          remindEveryDays: 0,
          updatedAt: anchor,
        );
        const on = AppSettings(reminderEnabled: true, proUnlocked: true);

        await service.sync(
          [noteWith(remindAt: shiftLocalCalendarDays(anchor, 3))],
          on,
          l10n,
        );
        final art = Directory('${support.path}/reminder_art');
        expect(art.existsSync(), isTrue);
        expect(art.listSync().whereType<File>(), hasLength(1));

        // Kopyanın ölçütü zaman değil, hâlâ planda olup olmadığı. Hatırlatma
        // kapatılınca dosyanın da gitmesi gerekir.
        await service.sync([noteWith()], on, l10n);
        expect(art.listSync().whereType<File>(), isEmpty);
        await service.dispose();
      },
    );

    test(
      'payload sürümü yükselince eski kurulum sökülüp yenisi kurulur',
      () async {
        // Bekleyen bir bildirimin hangi kanalla —dolayısıyla hangi sesle—
        // kurulduğu sonradan sorulamıyor. Sürüm etiketi payload'da taşındığı
        // için eski kurulum tanınıp yeniden kuruluyor.
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now().subtract(const Duration(days: 1));
        final note = Note(
          id: 601,
          imageName: '601.jpg',
          body: 'Eski kurulum',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: shiftLocalCalendarDays(anchor, 3),
          remindEveryDays: 0,
          updatedAt: anchor,
        );

        // Yükseltme öncesinden kalmış gibi davran.
        final staleId = reminderNotificationId(601, 0);
        pendingNotifications.add(<String, Object?>{
          'id': staleId,
          'title': 'Reminder',
          'body': 'Eski kurulum',
          'payload':
              'note/601/v2/at/'
              '${anchor.add(const Duration(days: 3)).toUtc().millisecondsSinceEpoch}',
        });

        calls.clear();
        await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        expect(
          calls.where(
            (call) => call.method == 'cancel' && call.arguments == staleId,
          ),
          hasLength(1),
          reason: 'eski sürümle kurulmuş kayıt sökülmeli',
        );
        final scheduled = calls.where((call) => call.method == 'zonedSchedule');
        expect(scheduled, hasLength(1));
        expect(
          (scheduled.single.arguments as Map)['payload'],
          contains('/v6/'),
        );
        await service.dispose();
      },
    );

    test('iOS exact tekrar lifecycle syncinde yeniden kurulmaz', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final day31 = DateTime(
        anchor.year + 1,
        DateTime.january,
        31,
        anchor.hour,
        anchor.minute,
      );
      final note = Note(
        id: 401,
        imageName: '401.jpg',
        body: 'Her ayın son geçerli günü',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: day31,
        remindEveryDays: 30,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        hasLength(kRollingReminderWindowPerNote),
      );
      expect(
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      await service.dispose();
    });

    test('iOS normal yıllık tekrar native takvim kaydı olur', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final note = Note(
        id: 402,
        imageName: '402.jpg',
        body: 'Her yıl',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(anchor, 365),
        remindEveryDays: 365,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final exact = calls.where((item) => item.method == 'zonedSchedule');
      expect(exact, hasLength(1));
      expect(
        (exact.single.arguments as Map)['matchDateTimeComponents'],
        DateTimeComponents.dateAndTime.index,
      );
      expect(
        calls.where((item) => item.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      await service.dispose();
    });

    test('otomatik silinen tekrar native değil sonlu kurulur', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final note = Note(
        id: 403,
        imageName: '403.jpg',
        body: 'Süreli',
        createdAt: anchor,
        retention: Retention.custom,
        customMinutes: 4 * 24 * 60,
        expiresAt: anchor.add(const Duration(days: 4)),
        remindAt: shiftLocalCalendarDays(anchor, 1),
        remindEveryDays: 1,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        hasLength(3),
      );
      await service.dispose();
    });

    test('notu daha önce silinecek bir tekrar hiç kurulmaz', () async {
      // Sessiz tuzak ve yukarıdaki "sonlu kurulur" testinden farkı bu:
      // orada not birkaç oluşumu görecek kadar yaşıyor, burada ilk oluşuma
      // bile varmadan siliniyor. Sonuç hiç bildirim değil — kullanıcı
      // hatırlatma kurduğunu sanır, sistemde karşılığı olmaz.
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final created = DateTime.now();
      final note = Note(
        id: 10,
        imageName: '10.jpg',
        body: 'Kısa ömürlü',
        createdAt: created,
        retention: Retention.threeDays,
        customMinutes: 0,
        expiresAt: created.add(const Duration(days: 3)),
        remindAt: shiftLocalCalendarDays(created, 30),
        remindEveryDays: 30,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      await service.dispose();
    });

    test('tekrar kapalıyken tek bir oluşum planlanır', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final note = Note(
        id: 41,
        imageName: '41.jpg',
        body: 'Bir kez',
        createdAt: DateTime.now(),
        retention: Retention.off,
        customMinutes: 0,
        remindAt: shiftLocalCalendarDays(DateTime.now(), 1),
        remindEveryDays: 0,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        hasLength(1),
      );
      await service.dispose();
    });

    test(
      'tekrarlayan notun teslim edilmiş oluşumlarının hepsi kapanır',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        calls.clear();
        // Kullanıcı iki turu da kaçırmış: ikisi de tepside duruyor.
        activeNotifications = <Map<String, Object?>>[
          <String, Object?>{
            'id': reminderNotificationId(42, 0),
            'payload': 'note/42',
          },
          <String, Object?>{
            'id': reminderNotificationId(42, 1),
            'payload': 'note/42',
          },
        ];

        await service.dismissNote(42);

        expect(
          calls
              .where((call) => call.method == 'cancel')
              .map((call) => call.arguments),
          [reminderNotificationId(42, 0), reminderNotificationId(42, 1)],
        );
        await service.dispose();
      },
    );

    test(
      'geçerli teslim edilmiş bildirim korunur, hayalet olan silinir',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        activeNotifications = <Map<String, Object?>>[
          <String, Object?>{'id': 31, 'payload': 'note/31'},
        ];
        final note = Note(
          id: 31,
          imageName: '31.jpg',
          body: 'Still here',
          createdAt: DateTime(2026),
          retention: Retention.off,
          customMinutes: 0,
          // Teslim edilmiş tek atış hâlâ kullanıcı açana kadar geçerli.
          // `0` olsaydı kullanıcı hatırlatmayı kapatmış demekti ve tepsiden
          // de kaldırılması gerekirdi.
          remindAt: shiftLocalCalendarDays(DateTime(2026), 1),
          remindEveryDays: 0,
        );

        calls.clear();
        final result = await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );
        expect(result.delivered, {31});
        // İki kanıt ayrı kümelerde: kayıt tepside duruyor ama anı geçtiği
        // için programda değil. Eskiden ikisi tek küme hâlinde dönüyordu ve
        // çağıran "kurulu" ile "görülmüş"ü ayıramıyordu.
        expect(result.scheduled, isEmpty);
        expect(result.scheduleKnown, isTrue);
        expect(calls.where((call) => call.method == 'cancel'), isEmpty);

        calls.clear();
        await service.sync(
          const [],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );
        expect(
          calls.where(
            (call) => call.method == 'cancel' && call.arguments == 31,
          ),
          hasLength(1),
        );
        await service.dispose();
      },
    );

    test(
      'silinen notun bekleyen ve teslim edilmiş bildirimi kapanır',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        final id = reminderNotificationId(52, 0);
        activeNotifications = <Map<String, Object?>>[
          <String, Object?>{'id': id, 'payload': 'note/52'},
        ];
        pendingNotifications = <Map<String, Object?>>[
          <String, Object?>{'id': id, 'payload': 'note/52/v2/every/30/1000'},
        ];

        calls.clear();
        await service.sync(
          const [],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        expect(
          calls.where(
            (call) => call.method == 'cancel' && call.arguments == id,
          ),
          isNotEmpty,
        );
        expect(pendingNotifications, isEmpty);
        await service.dispose();
      },
    );

    test('hatırlatma kapatılınca tepsideki eski satır da kapanır', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final id = reminderNotificationId(53, 0);
      activeNotifications = <Map<String, Object?>>[
        <String, Object?>{'id': id, 'payload': 'note/53'},
      ];
      final note = Note(
        id: 53,
        imageName: '53.jpg',
        body: 'Kapalı',
        createdAt: DateTime.now(),
        retention: Retention.off,
        customMinutes: 0,
        remindEveryDays: 0,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      expect(
        calls.where((call) => call.method == 'cancel' && call.arguments == id),
        hasLength(1),
      );
      await service.dispose();
    });

    test(
      'aralık düzenlenince eski tekrar sökülüp yeni aralık kurulur',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        final l10n = await L10n.delegate.load(const Locale('en'));
        final anchor = DateTime.now();
        final nextMonth = DateTime(
          anchor.year,
          anchor.month + 1,
          1,
          anchor.hour,
          anchor.minute,
        );
        final id = reminderNotificationId(54, 0);
        pendingNotifications = <Map<String, Object?>>[
          <String, Object?>{'id': id, 'payload': 'note/54/v2/every/3/1000'},
        ];
        final note = Note(
          id: 54,
          imageName: '54.jpg',
          body: 'Yeni aralık',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAt: nextMonth,
          remindEveryDays: 30,
        );

        calls.clear();
        await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );

        expect(
          calls.where(
            (call) => call.method == 'cancel' && call.arguments == id,
          ),
          hasLength(1),
        );
        final exact = calls.where((call) => call.method == 'zonedSchedule');
        expect(exact, hasLength(1));
        expect(
          (exact.single.arguments as Map)['matchDateTimeComponents'],
          DateTimeComponents.dayOfMonthAndTime.index,
        );
        expect(
          calls.where((call) => call.method == 'periodicallyShowWithDuration'),
          isEmpty,
        );
        await service.dispose();
      },
    );

    test(
      'Free katmana geçince açık ana şalter programı topluca iptal etmez',
      () async {
        final service = ReminderService(supported: true);
        await service.initialize();
        calls.clear();
        final l10n = await L10n.delegate.load(const Locale('en'));

        await service.sync(
          const [],
          const AppSettings(reminderEnabled: true, proUnlocked: false),
          l10n,
        );

        expect(calls.where((call) => call.method == 'cancelAll'), isEmpty);
        expect(
          calls.where((call) => call.method == 'cancelAllPendingNotifications'),
          isEmpty,
        );
        await service.dispose();
      },
    );
  });

  group('Android bildirim teslimat hakkı', () {
    var appEnabled = true;
    List<Map<String, Object?>>? channels;
    late List<MethodCall> androidCalls;

    Map<String, Object?> reminderChannel({required int importance}) =>
        <String, Object?>{
          'id': 'latermark_reminders_v3',
          'name': 'Reminders',
          'description': 'Latermark reminders',
          'groupId': null,
          'showBadge': true,
          'importance': importance,
          'bypassDnd': false,
          'playSound': true,
          'enableLights': false,
          'enableVibration': true,
          'vibrationPattern': null,
          'ledColor': 0,
          'audioAttributesUsage': 5,
        };

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      messenger.setMockMethodCallHandler(actionChannel, (call) async {
        if (call.method == 'timeZoneIdentifier') return 'Europe/Istanbul';
        return null;
      });
      appEnabled = true;
      channels = <Map<String, Object?>>[];
      androidCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        androidCalls.add(call);
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return <String, Object?>{'notificationLaunchedApp': false};
        }
        if (call.method == 'areNotificationsEnabled') return appEnabled;
        if (call.method == 'getNotificationChannels') return channels;
        if (call.method == 'getActiveNotifications' ||
            call.method == 'pendingNotificationRequests') {
          return <Map<String, Object?>>[];
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(actionChannel, null);
      debugDefaultTargetPlatformOverride = null;
      IOSFlutterLocalNotificationsPlugin.registerWith();
    });

    test('uygulama bildirimi kapalıysa denied', () async {
      appEnabled = false;
      final service = ReminderService(supported: true);
      expect(await service.refreshPermission(), ReminderPermissionState.denied);
      await service.dispose();
    });

    test('yalnız Latermark reminder kanalı kapalıysa denied', () async {
      channels = [reminderChannel(importance: Importance.none.value)];
      final service = ReminderService(supported: true);
      expect(await service.refreshPermission(), ReminderPermissionState.denied);
      await service.dispose();
    });

    test('kanal henüz oluşmadıysa uygulama izni yeterlidir', () async {
      final service = ReminderService(supported: true);
      expect(
        await service.refreshPermission(),
        ReminderPermissionState.granted,
      );
      await service.dispose();
    });

    test('kanal listesi okunamıyorsa unknown kalır', () async {
      channels = null;
      final service = ReminderService(supported: true);
      expect(
        await service.refreshPermission(),
        ReminderPermissionState.unknown,
      );
      expect(service.permission.value, ReminderPermissionState.unknown);
      await service.dispose();
    });

    test('native haftalık tekrar ilk kesin oluşumdan başlar', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final remindAt = shiftLocalCalendarDays(anchor, 1);
      final expected = pendingReminderAt(
        remindAt: remindAt,
        cadence: ReminderCadence.weekly,
        now: DateTime.now(),
      );
      final note = Note(
        id: 90,
        imageName: '90.jpg',
        body: 'Android phase',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAt: remindAt,
        remindEveryDays: 7,
      );

      androidCalls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      // İlk kesin an `scheduledDateTime` ile gidiyor, ritim de haftanın
      // günü ve saat bileşenleriyle eşleşiyor.
      final scheduled = androidCalls.singleWhere(
        (call) => call.method == 'zonedSchedule',
      );
      final arguments = scheduled.arguments as Map;
      expect(
        arguments['matchDateTimeComponents'],
        DateTimeComponents.dayOfWeekAndTime.index,
      );
      expect(arguments['timeZoneName'], 'Europe/Istanbul');
      // Karşılaştırma **an** üzerinden: `scheduledDateTime` bölgesiz yazılıyor,
      // ISO8601 alanı ise kaymayı taşıyor.
      final sent = DateTime.parse(
        arguments['scheduledDateTimeISO8601'] as String,
      );
      expect(
        sent.difference(expected!).abs(),
        lessThan(const Duration(seconds: 1)),
      );
      await service.dispose();
    });
  });

  test('yalnız geçerli reminder payloadı not kimliğine çevrilir', () {
    expect(noteIdFromReminderPayload('note/19'), 19);
    expect(noteIdFromReminderPayload('note/19/v2/every/3/1000'), 19);
    expect(noteIdFromReminderPayload('note/19/v3/every_minutes/3/1000'), 19);
    expect(
      noteIdFromReminderPayload('note/19/v4/every_minutes/3/1000/art1/a-b'),
      19,
    );
    expect(noteIdFromReminderPayload('note/19/v4/at/1000/art1/none'), 19);
    expect(noteIdFromReminderPayload('note/19/v5/at/1000/art1/none'), 19);
    expect(noteIdFromReminderPayload(null), isNull);
    expect(noteIdFromReminderPayload(''), isNull);
    expect(noteIdFromReminderPayload('note/0'), isNull);
    expect(noteIdFromReminderPayload('note/-1'), isNull);
    expect(noteIdFromReminderPayload('note/not-a-number'), isNull);
    expect(noteIdFromReminderPayload('other/19'), isNull);
    expect(noteIdFromReminderPayload('note/19/extra'), isNull);
    expect(noteIdFromReminderPayload('note/19/v4/at/1000'), isNull);
    expect(noteIdFromReminderPayload('note/19/v5/at/1000'), isNull);
    expect(
      noteIdFromReminderPayload('note/19/v4/at/1000/art1/not!valid'),
      isNull,
    );
  });

  test('arayüzdeki Next her derlemede gün programını kullanır', () async {
    final anchor = DateTime(2026, 8, 21, 10);
    final note = Note(
      id: 81,
      imageName: '81.jpg',
      body: 'Next parity',
      createdAt: anchor,
      retention: Retention.off,
      customMinutes: 0,
      remindAt: shiftLocalCalendarDays(anchor, 3),
      remindEveryDays: 3,
    );
    const settings = AppSettings(reminderEnabled: true, proUnlocked: true);

    final service = ReminderService(supported: false);
    expect(
      service.nextReminderAt(note, settings, now: anchor),
      DateTime(2026, 8, 24, 10),
    );
    await service.dispose();
  });
}
