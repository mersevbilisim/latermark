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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('bildirim not bağlantısı', () {
    late List<MethodCall> calls;
    late Map<String, Object?> launchDetails;
    late List<Map<String, Object?>> activeNotifications;
    late List<Map<String, Object?>> pendingNotifications;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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

    test('süresiz tekrarlayan not native tek kayıt olarak planlanır', () async {
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

      final periodic = calls.where(
        (call) => call.method == 'periodicallyShowWithDuration',
      );
      expect(periodic, hasLength(1));
      final arguments = periodic.single.arguments as Map;
      expect(arguments['id'], reminderNotificationId(40, 0));
      expect(arguments['repeatIntervalMilliseconds'], 86400000);
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      await service.dispose();
    });

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
