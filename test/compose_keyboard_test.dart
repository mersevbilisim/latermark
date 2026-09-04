import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/presentation/compose/compose_page.dart';
import 'package:latermark/features/notes/presentation/compose/widgets/note_composer.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_control.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';
import 'package:latermark/l10n/app_localizations.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Klavye açıkken yeni kayıt ekranının yazma alanı ile hatırlatma arasındaki
/// pazarlık.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;
  late File photo;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_compose_kb');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
    // Hatırlatma Pro'ya kilitli; kilitliyken alanın TextField'ı bile yok.
    await settings.setProUnlocked(true);
    photo = File('${sandbox.path}/p.png')..writeAsBytesSync(_pixel);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('klavye açıkken yazı alanı tabanını korur, hatırlatma erişilir', (
    tester,
  ) async {
    const height = 852.0;
    const keyboard = 336.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ComposePage(
            capture: XFile(photo.path),
            source: ComposeSource.gallery,
          ),
        ),
      ),
    );
    await _settle(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = const FakeViewPadding(top: 47);
    await _settle(tester);

    // Yazı alanı düzendeki tek esneyen parça değil artık: tabanının altına
    // inmiyor, sığmayan durumda sayfa kayıyor.
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.height, greaterThanOrEqualTo(NoteComposer.minFieldExtent));

    // Kaydet şeridi hep klavyenin üstünde, kaydırmanın dışında.
    final bar = tester.getRect(
      find.byKey(const ValueKey('compose-action-bar')),
    );
    expect(bar.bottom, lessThanOrEqualTo(height - keyboard));

    // Klavye açıkken anahtarların yerinde tek satır var: yazarken üç anahtarı
    // ekranda tutmaya çalışmak, klavyenin zaten aldığı yer için kavga etmekti.
    expect(find.byType(ReminderControl).hitTestable(), findsNothing);
    expect(find.byKey(const Key('compose-options-collapsed')), findsOneWidget);
    // Satır bir kapı ve kapı gibi görünüyor: bilmece ikonlar değil, tek söz.
    expect(find.text('SEÇENEKLER'), findsOneWidget);

    // Anahtarlar görünmüyor ama **ağaçta kurulu**: dokunuşta ilk kez
    // kurulsalardı üç `Stateful` denetimin kurulum bedeli, klavyenin indiği
    // son karenin üstüne binerdi — gözle görülür takılma buradan geliyordu.
    // Bulucular `Offstage` altını varsayılan olarak atladığı için yukarıdaki
    // "görünmüyor" iddiaları da doğru kalıyor.
    expect(
      find.byType(ReminderControl, skipOffstage: false),
      findsOneWidget,
      reason: 'Anahtarlar sahne dışında tutulmalı, ağaçtan çıkarılmamalı',
    );

    // Satıra dokunmak karar aşamasına geçiriyor: klavye iniyor, anahtarlar
    // açılıyor. Testte klavyenin inişini `viewInsets` temsil ediyor.
    await tester.tap(find.byKey(const Key('compose-options-collapsed')));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    await _settle(tester);

    // Hatırlatma artık klavyenin altında ikinci bir form değil, tek bir
    // anahtar: gün ve saat kaydettikten sonraki ekranda soruluyor. Kaydırmaya
    // da gerek yok — `ensureVisible` çağrısı kalktı.
    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await _settle(tester);

    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const Key('reminder-switch')))
          .value,
      isTrue,
    );

    // Anahtar açıkken alt şeridin kelimesi de değişir: kaydetmek burada
    // bitmiyor, arkasından planlama ekranı geliyor.
    expect(find.text('KAYDET VE HATIRLAT'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('compose-action-bar'))).bottom,
      lessThanOrEqualTo(height),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// Açılışta anahtarlar bir an görünüp sonra katlanıyordu.
  ///
  /// Sebep sıralama: alan `autofocus` ile açılıyor ama odak ilk kareden
  /// **sonra** geliyor. Kapı doğrudan `hasFocus`'a bakınca ilk kare
  /// anahtarlarla çiziliyor, odak gelince de kullanıcının hiç istemediği bir
  /// kapanma animasyonu oynuyordu.
  testWidgets('ilk kare kapalı çiziliyor, anahtarlar hiç görünmüyor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ComposePage(
            capture: XFile(photo.path),
            source: ComposeSource.gallery,
          ),
        ),
      ),
    );

    // Tek kare: odak henüz gelmedi.
    await tester.pump();
    expect(
      find.byType(ReminderControl).hitTestable(),
      findsNothing,
      reason: 'İlk karede anahtarlar görünmemeli',
    );
    expect(find.text('SEÇENEKLER'), findsOneWidget);

    await _settle(tester);
    // Odak geldikten sonra da kapalı: arada bir katlanma oynamadı.
    expect(find.byType(ReminderControl).hitTestable(), findsNothing);
    expect(find.text('SEÇENEKLER'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// Simülatörde fark edilmeyen, gerçek cihazda canını sıkan şey: satır
  /// 30pt'ydi. Parmak ucu 44pt'nin altındaki bir hedefi güvenilir bulmuyor —
  /// Apple'ın asgarisi de bu.
  testWidgets('daraltılmış satırın dokunma hedefi 44pt', (tester) async {
    const height = 852.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ComposePage(
            capture: XFile(photo.path),
            source: ComposeSource.gallery,
          ),
        ),
      ),
    );
    await _settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await _settle(tester);

    final target = tester.getRect(
      find.byKey(const Key('compose-options-collapsed')),
    );
    expect(target.height, greaterThanOrEqualTo(44));
    // Genişlik satırın tamamı: 15pt'lik irise nişan almak gerekmiyor.
    expect(target.width, greaterThan(300));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('uzun metin seçenekleri aşağı itmez', (tester) async {
    // Alan metinle birlikte uzasaydı seçenek satırı sayfanın altına kaçardı;
    // kullanıcı yazdıkça seçeneklerine giden kapıyı kaybederdi.
    const height = 852.0;
    const keyboard = 336.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ComposePage(
            capture: XFile(photo.path),
            source: ComposeSource.gallery,
          ),
        ),
      ),
    );
    await _settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await _settle(tester);

    final before = tester.getRect(
      find.byKey(const Key('compose-options-collapsed')),
    );
    final fieldBefore = tester.getRect(find.byType(TextField).first);

    await tester.enterText(
      find.byType(TextField).first,
      List.filled(120, 'Bu not kasten çok uzun tutuldu.').join(' '),
    );
    await _settle(tester);

    expect(
      tester.getRect(find.byKey(const Key('compose-options-collapsed'))),
      before,
    );
    expect(tester.getRect(find.byType(TextField).first), fieldBefore);
    expect(before.bottom, lessThanOrEqualTo(height - keyboard));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// Seçenekler artık kaydırılarak değil, tek dokunuşla açılıyor: en alttaki
  /// anahtar da o kapının ardında erişilebilir olmalı.
  testWidgets('daraltılmış satır bütün anahtarları açıyor', (tester) async {
    const height = 852.0;
    const keyboard = 336.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        notes: repository,
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: ComposePage(
            capture: XFile(photo.path),
            source: ComposeSource.gallery,
          ),
        ),
      ),
    );
    await _settle(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = const FakeViewPadding(top: 47);
    await _settle(tester);

    // Anahtar klavye açıkken çizilmiyor; kapı daraltılmış satır.
    expect(
      find.byKey(const Key('keep-original-row')).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('compose-options-collapsed')));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    await _settle(tester);

    // Ölçüm sırasında bırakılmış iki `debugPrint` buradan kalktı: hiçbir
    // iddiayı beslemiyor, her koşuda çıktıyı kirletiyorlardı.
    final row = tester.getRect(find.byKey(const Key('keep-original-row')));
    // Klavye indi: satırın sınırı artık ekranın kendisi.
    expect(row.bottom, lessThanOrEqualTo(height));

    await tester.tap(find.byKey(const Key('keep-original-row')));
    await _settle(tester);
    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const Key('keep-original-switch')))
          .value,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
