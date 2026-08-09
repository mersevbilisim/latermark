import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
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

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      calls = <MethodCall>[];
      launchDetails = <String, Object?>{'notificationLaunchedApp': false};
      activeNotifications = <Map<String, Object?>>[];
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

    test('senkron yalnız bekleyen programı yeniler', () async {
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
          remindAfterDays: 0,
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
