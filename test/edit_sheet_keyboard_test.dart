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
import 'package:latermark/features/notes/presentation/detail/widgets/edit_note_sheet.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/notes/presentation/widgets/collapsed_options.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_control.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Yazarken klavye ekranın yarısını alıyor. Bu dosya, panelin o yarıya
/// sığmayan kısmını **ulaşılabilir** bıraktığını ölçüyor.
///
/// Geçmişi olan bir hata: panel `SliverFillRemaining` içinde viewport boyuna
/// kilitliydi ve künye ile hatırlatma hem rayın hem klavyenin arkasına düşüp
/// kaydırmayla da ulaşılamaz oluyordu.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_edit_kb');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
    // Hatırlatma Pro'ya kilitli; kilitliyken alanın TextField'ı bile yok.
    await settings.setProUnlocked(true);
    final photo = File('${sandbox.path}/p.png')..writeAsBytesSync(_pixel);
    await repository.create(
      capture: XFile(photo.path),
      body: 'Yaz dönemi seyahat rotasına ekle.',
      retention: const RetentionChoice.off(),
    );
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('klavye açıkken baskı küçülür ve hatırlatma ulaşılabilir kalır', (
    tester,
  ) async {
    const height = 852.0;
    const keyboard = 336.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await _settle(tester);
    await tester.tap(find.byType(NoteCard));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('detail-note-copy')));
    await _settle(tester);
    expect(find.byType(EditNoteSheet), findsOneWidget);

    final photoBeforeKeyboard = tester
        .getSize(find.byKey(const ValueKey('note-photo-stage')))
        .height;

    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = const FakeViewPadding(top: 47);
    await _settle(tester);

    // Yazarken baskı referans, konu değil: klavye yükselince küçülüyor ve
    // yer nota kalıyor.
    final photoWithKeyboard = tester
        .getSize(find.byKey(const ValueKey('note-photo-stage')))
        .height;
    expect(photoWithKeyboard, lessThan(photoBeforeKeyboard));

    final railTop = tester
        .getRect(find.byKey(const ValueKey('edit-action-rail')))
        .top;
    // Ray klavyenin tam üstünde durur.
    expect(railTop + 0.5, greaterThan(height - keyboard - 120));
    expect(railTop, lessThan(height - keyboard));

    // Yazarken anahtarın yerini tek satır alıyor.
    //
    // Eskiden bu test hatırlatmaya ulaşmak için `jumpTo(maxScrollExtent)`
    // yapıyordu — yani satır ekranda değildi, sona kadar kaydırmak
    // gerekiyordu. "Erişilebilir" olmak ile "ulaşılır" olmak aynı şey değil.
    expect(find.byType(CollapsedOptions), findsOneWidget);
    expect(find.byType(ReminderControl).hitTestable(), findsNothing);
    expect(find.byKey(const ValueKey('edit-pull-down-region')), findsNothing);
    // Ama ağaçta kurulu: dokunuşta ilk kez kurulsaydı o maliyet klavyenin
    // indiği son karenin üstüne binerdi.
    expect(
      find.byType(ReminderControl, skipOffstage: false),
      findsOneWidget,
      reason: 'Anahtar sahne dışında tutulmalı, ağaçtan çıkarılmamalı',
    );

    // Kapıya dokunmak karar aşamasına geçiriyor: odak düşüyor, anahtar
    // yerini alıyor. Kaydırmaya gerek yok.
    await tester.tap(find.byType(CollapsedOptions));
    await _settle(tester);

    expect(find.byType(ReminderControl).hitTestable(), findsOneWidget);
    // Tutamak da yerine döndü: yazarken çekiliyor, karar aşamasında geri
    // geliyor. Paneli kapatmak yazarken yapılan bir şey değil.
    expect(find.byKey(const ValueKey('edit-pull-down-region')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-switch-row')));
    await _settle(tester);

    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const Key('reminder-switch')))
          .value,
      isTrue,
    );

    // Şeridin kaydet kelimesi de kararı yansıtır.
    expect(find.text('KAYDET VE HATIRLAT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('uzun metin künyeyi ve hatırlatmayı aşağı itmez', (tester) async {
    // Panel metinle birlikte uzasaydı hatırlatma satırı ekrandan çıkardı;
    // kullanıcı yazdıkça seçeneklerini kaybederdi.
    const height = 852.0;
    const keyboard = 336.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, height);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await _settle(tester);
    await tester.tap(find.byType(NoteCard));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('detail-note-copy')));
    await _settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = const FakeViewPadding(top: 47);
    await _settle(tester);

    final sheetBefore = tester.getSize(
      find.byKey(const ValueKey('edit-note-sheet-surface')),
    );
    final fieldBefore = tester.getSize(
      find.byKey(const ValueKey('edit-note-body-field')),
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-note-body-field')),
      List.filled(120, 'Bu not kasten çok uzun tutuldu.').join(' '),
    );
    await _settle(tester);

    // Panel de yazı alanı da aynı boyda: uzayan tek şey metnin kendisi ve o da
    // alanın içinde kayıyor.
    expect(
      tester.getSize(find.byKey(const ValueKey('edit-note-sheet-surface'))),
      sheetBefore,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('edit-note-body-field'))),
      fieldBefore,
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
