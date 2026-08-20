import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
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
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return launchDetails;
        }
        if (call.method == 'checkPermissions') {
          return <String, Object?>{'isEnabled': true};
        }
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

      await service.dismissNote(23);

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

      await service.dismissNote(24);

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
        remindAfterDays: 1,
        remindRepeats: false,
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
        remindAfterDays: 1,
        remindRepeats: true,
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
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        isEmpty,
      );
      await service.dispose();
    });

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
        remindAfterDays: 3,
        reminderAnchorAt: anchor,
        remindRepeats: false,
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
        remindAfterDays: 3,
        reminderAnchorAt: anchor,
        remindRepeats: false,
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
      expect(photo.existsSync(), isTrue);
      await service.dispose();
    });

    test('desteklenmeyen kare eklenmez ama hatırlatma yine kurulur', () async {
      final sandbox = Directory.systemTemp.createTempSync('lm_heic');
      addTearDown(() => sandbox.deleteSync(recursive: true));
      // Galeriden ve paylaşımdan HEIC gelebiliyor. Apple bunu ek olarak kabul
      // etmiyor ve hata döndürüyor; hata sync döngüsünü keserdi.
      final photo = File('${sandbox.path}/502.heic')
        ..writeAsBytesSync(<int>[1, 2, 3]);

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
        remindAfterDays: 3,
        reminderAnchorAt: anchor,
        remindRepeats: false,
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
      expect(specifics['attachments'], anyOf(isNull, isEmpty));
      await service.dispose();
    });

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
        Note noteWith({required int remindAfterDays}) => Note(
          id: 600,
          imageName: '600.png',
          body: 'Kare',
          createdAt: anchor,
          retention: Retention.off,
          customMinutes: 0,
          remindAfterDays: remindAfterDays,
          reminderAnchorAt: anchor,
          remindRepeats: false,
          updatedAt: anchor,
        );
        const on = AppSettings(reminderEnabled: true, proUnlocked: true);

        await service.sync([noteWith(remindAfterDays: 3)], on, l10n);
        final art = Directory('${support.path}/reminder_art');
        expect(art.existsSync(), isTrue);
        expect(art.listSync().whereType<File>(), hasLength(1));

        // Kopyanın ölçütü zaman değil, hâlâ planda olup olmadığı. Hatırlatma
        // kapatılınca dosyanın da gitmesi gerekir.
        await service.sync([noteWith(remindAfterDays: 0)], on, l10n);
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
          remindAfterDays: 3,
          reminderAnchorAt: anchor,
          remindRepeats: false,
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
          contains('/v3/'),
        );
        await service.dispose();
      },
    );

    test('uygulama yeniden senkron olunca native tekrar başa sarmaz', () async {
      final service = ReminderService(supported: true);
      await service.initialize();
      final l10n = await L10n.delegate.load(const Locale('en'));
      final anchor = DateTime.now();
      final note = Note(
        id: 401,
        imageName: '401.jpg',
        body: 'Her 30 günde bir',
        createdAt: anchor,
        retention: Retention.off,
        customMinutes: 0,
        remindAfterDays: 30,
        reminderAnchorAt: anchor,
        remindRepeats: true,
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
        calls.where((call) => call.method == 'periodicallyShowWithDuration'),
        hasLength(1),
      );
      await service.dispose();
    });

    test('365 günlük tekrar 64-bit milisaniye aralığıyla kurulur', () async {
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
        remindAfterDays: 365,
        reminderAnchorAt: anchor,
        remindRepeats: true,
      );

      calls.clear();
      await service.sync(
        [note],
        const AppSettings(reminderEnabled: true, proUnlocked: true),
        l10n,
      );

      final call = calls.singleWhere(
        (item) => item.method == 'periodicallyShowWithDuration',
      );
      expect(
        (call.arguments as Map)['repeatIntervalMilliseconds'],
        const Duration(days: 365).inMilliseconds,
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
        remindAfterDays: 1,
        reminderAnchorAt: anchor,
        remindRepeats: true,
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
        remindAfterDays: 30,
        remindRepeats: true,
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
        remindAfterDays: 1,
        remindRepeats: false,
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
          remindAfterDays: 1,
          remindRepeats: false,
        );

        calls.clear();
        await service.sync(
          [note],
          const AppSettings(reminderEnabled: true, proUnlocked: true),
          l10n,
        );
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
        remindAfterDays: 0,
        remindRepeats: false,
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
          remindAfterDays: 30,
          reminderAnchorAt: anchor,
          remindRepeats: true,
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
        final periodic = calls.singleWhere(
          (call) => call.method == 'periodicallyShowWithDuration',
        );
        expect(
          (periodic.arguments as Map)['repeatIntervalMilliseconds'],
          const Duration(days: 30).inMilliseconds,
        );
        await service.dispose();
      },
    );

    test(
      'Pro hakkı geri alınınca açık ana şalter de tümünü iptal eder',
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

        expect(calls.where((call) => call.method == 'cancelAll'), hasLength(1));
        expect(
          calls.where((call) => call.method == 'cancelAllPendingNotifications'),
          isEmpty,
        );
        await service.dispose();
      },
    );
  });

  test('yalnız geçerli reminder payloadı not kimliğine çevrilir', () {
    expect(noteIdFromReminderPayload('note/19'), 19);
    expect(noteIdFromReminderPayload(null), isNull);
    expect(noteIdFromReminderPayload(''), isNull);
    expect(noteIdFromReminderPayload('note/0'), isNull);
    expect(noteIdFromReminderPayload('note/-1'), isNull);
    expect(noteIdFromReminderPayload('note/not-a-number'), isNull);
    expect(noteIdFromReminderPayload('other/19'), isNull);
    expect(noteIdFromReminderPayload('note/19/extra'), isNull);
  });
}
