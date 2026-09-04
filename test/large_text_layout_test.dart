import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/app/app_routes.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/backup/presentation/backup_page.dart';
import 'package:latermark/features/notes/presentation/capture/widgets/camera_notice.dart';
import 'package:latermark/features/paywall/presentation/paywall_page.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/presentation/compose/compose_page.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/photo_dismiss_surface.dart';
import 'package:latermark/features/notes/presentation/reminder/reminder_schedule_page.dart';
import 'package:latermark/features/settings/presentation/your_data_page.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/presentation/settings_page.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Dinamik Yazı Tipi'nin en büyük erişilebilirlik boyu. Uygulama tavanı
/// 2×'te; sistem bunun üstünü isterse orada kesiliyor, düzen dağılmıyor.
const _axScale = 3.1;

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    PackageInfo.setMockInitialValues(
      appName: 'Latermark',
      packageName: 'com.mersev.latermark',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_axtext');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Küçük ekran + en büyük yazı: taşma buradan çıkar.
  void useSurface(WidgetTester tester, {Size size = const Size(320, 568)}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.platformDispatcher.textScaleFactorTestValue = _axScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> addNote(
    WidgetTester tester,
    String body, {
    bool keepOriginal = false,
  }) async {
    await tester.runAsync(() async {
      final file = File(
        '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(file.path),
        body: body,
        retention: RetentionChoice(Retention.threeDays),
        keepOriginal: keepOriginal,
      );
    });
  }

  /// Kendi başına açılan sayfalar için: uygulamanın kökünde uyguladığı yazı
  /// tavanının aynısı. Sayfayı 3.1×'te sınamak gerçeğin ötesinde bir yük olur;
  /// uygulama o ölçeği hiçbir zaman geçirmiyor.
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.dark(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 2),
            ),
            child: child!,
          );
        },
        home: page,
      ),
    );
    await settle(tester);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
  }

  testWidgets('boş ana ekran en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('dolu akış en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    await addNote(tester, 'Otoparkın P10 katındaki sarı sütunun yanı');
    await addNote(tester, 'Kısa');
    await pumpApp(tester);

    expect(find.byType(NoteCard), findsWidgets);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('detay sayfası en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    // Orijinali saklanmış kayıt: künye en uzun hâlinde — saat, tarih ve
    // dosya boyu satırı birlikte.
    await addNote(
      tester,
      'Otoparkın P10 katındaki sarı sütunun yanı',
      keepOriginal: true,
    );
    await pumpApp(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);

    // Şerit sabit yükseklikte olsaydı künye taşma hatası bile vermeden
    // alttan kırpılırdı: `clipBehavior: hardEdge` sessizce keser.
    final stamp = tester.getRect(
      find.byKey(const ValueKey('detail-note-date')),
    );
    final chrome = tester.getRect(find.byKey(const ValueKey('detail-chrome')));
    expect(stamp.top, greaterThanOrEqualTo(chrome.top - 0.5));
    expect(stamp.bottom, lessThanOrEqualTo(chrome.bottom + 0.5));

    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('ayarlar ve erişilebilirlik en büyük yazı boyunda taşmıyor', (
    tester,
  ) async {
    useSurface(tester);
    await addNote(tester, 'Kısa');
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ayarlar en büyük yazıda 3000 pt'yi aşıyor: satır tembel kuruluyor,
    // önce oraya kadar kaydırmak gerekiyor.
    final accessibilityRow = find.byKey(const Key('settings-accessibility'));
    await tester.scrollUntilVisible(
      accessibilityRow,
      300,
      scrollable: find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(accessibilityRow);
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(accessibilityRow);
    await settle(tester);
    expect(find.byKey(const Key('accessibility-page')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('yazma ekranı en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    await pumpApp(tester);

    // Karesiz kayıt: composer kareyi beklemeden açılıyor.
    // En büyük yazı boyunda davet ekrana sığmıyor ve kaydırılabiliyor:
    // eylem ekranın dışında kalmıyor, bir parmak hareketi uzakta.
    final textEntry = find.byKey(const ValueKey('invite-action-text'));
    await tester.ensureVisible(textEntry);
    await settle(tester);
    await tester.tap(textEntry);
    await settle(tester);

    expect(find.byType(ComposePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('hatırlatma planı en büyük yazı boyunda taşmıyor', (
    tester,
  ) async {
    useSurface(tester);
    await settings.setProUnlocked(true);
    await settings.setReminderEnabled(true);
    final id = await tester.runAsync(() async {
      final file = File('${sandbox.path}/reminder.png');
      await file.writeAsBytes(_pixel);
      return repository.create(
        capture: XFile(file.path),
        body: 'Otopark',
        retention: RetentionChoice(Retention.threeDays),
      );
    });
    await pumpApp(tester);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          AppRoutes.lift(
            ReminderSchedulePage(
              noteId: id!,
              initial: const ReminderChoice.off(),
            ),
          ),
        );
    await settle(tester);

    expect(find.byType(ReminderSchedulePage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('fotoğraf görüntüleyici en büyük yazı boyunda taşmıyor', (
    tester,
  ) async {
    useSurface(tester);
    await addNote(tester, 'Otopark', keepOriginal: true);
    await pumpApp(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);
    // Detaydaki baskıya dokunmak tam ekran görüntüleyiciyi açıyor.
    await tester.tap(find.byType(PhotoDismissSurface));
    await settle(tester);

    expect(find.byKey(const Key('photo-viewer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('paywall en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    await pumpPage(
      tester,
      PaywallPage(price: '₺149,99', onPurchase: () {}, onRestore: () {}),
    );

    expect(find.byType(PaywallPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('yedekleme sayfası en büyük yazı boyunda taşmıyor', (
    tester,
  ) async {
    useSurface(tester);
    await pumpPage(tester, const BackupPage.create());

    expect(find.byType(BackupPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('kamera uyarısı en büyük yazı boyunda taşmıyor', (tester) async {
    useSurface(tester);
    // Canlı vizör donanım istiyor ve testte kurulamıyor; yazıyı taşıyan yüzey
    // zaten bu uyarı — izni reddetmiş ya da kamerasız bir cihazda kullanıcının
    // gördüğü ekran. En uzun metin çifti (başarısız açılış) sınanıyor.
    final l10n = await L10n.delegate.load(const Locale('tr'));
    await pumpPage(
      tester,
      Scaffold(
        backgroundColor: Colors.black,
        body: CameraNotice(
          icon: Icons.error_outline_rounded,
          title: l10n.cameraFailedTitle,
          message: l10n.cameraFailedBody,
          actionLabel: l10n.actionRetry,
          onAction: () {},
        ),
      ),
    );

    expect(find.byType(CameraNotice), findsOneWidget);
    expect(find.text(l10n.actionRetry), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('yedekleme ve veri sayfaları en büyük yazı boyunda taşmıyor', (
    tester,
  ) async {
    useSurface(tester);
    await addNote(tester, 'Kısa');
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);

    final row = find.byKey(const Key('settings-your-data'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);

    expect(find.byType(YourDataPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
