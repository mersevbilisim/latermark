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
import 'package:latermark/features/notes/presentation/widgets/reminder_control.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';

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

    // Panel viewport'a kilitli değil: sığmayan içerik kaydırma payı üretiyor.
    // Hatırlatmayı gerçekten kaydıran scrollable, onun kendi bağlamından
    // sorulur: sayfada birden fazla dikey scrollable var (yazı alanının kendi
    // iç kaydırması da bir tanesi).
    final position = Scrollable.of(
      tester.element(find.byType(ReminderControl)),
    ).position;
    expect(position.maxScrollExtent, greaterThan(0));

    // Hatırlatma satırı erişilebilir; düzenleme ise not klavyesiyle yarışmayan
    // geçici panelde yapılır. Panel sahte klavye inset'inin de üstünde kalır.
    final reminderContext = tester.element(find.byType(ReminderControl));
    final reminderPosition = Scrollable.of(reminderContext).position;
    reminderPosition.jumpTo(reminderPosition.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.byKey(const Key('reminder-field-control')));
    await _settle(tester);

    final reminderSheet = tester.getRect(
      find.byKey(const Key('reminder-sheet')),
    );
    expect(reminderSheet.bottom, lessThanOrEqualTo(height - keyboard));

    await tester.tap(find.byKey(const Key('reminder-preset-7')));
    await tester.tap(find.byKey(const Key('reminder-mode-repeat')));
    await tester.ensureVisible(find.byKey(const Key('reminder-sheet-save')));
    await tester.tap(find.byKey(const Key('reminder-sheet-save')));
    await _settle(tester);

    expect(find.text('7 gün'), findsOneWidget);

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
