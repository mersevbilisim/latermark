import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_kind.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/edit_note_sheet.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Yeni kayıt ekranı, karesiz bir kaydın boş gövdeyle kaydedilmesini
/// engelliyor: ortada ne kare ne yazı kalırdı (bkz. `ComposePage` içindeki
/// `_bodyEmpty` koruması). Aynı kayıt **düzenlemeden** aynı şekilde
/// boşaltılabiliyordu; akışta boş bir kart, aramada hiç bulunmayan bir satır
/// kalıyordu.
void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_edit_empty');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    settings = SettingsRepository(database);
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Paneli ve alt şeridi doğrudan kurar.
  ///
  /// Bütün uygulamayı ayağa kaldırmak bu iddia için gereğinden pahalı: kural
  /// panelin kendi kuralı ve burada tek başına ölçülebiliyor.
  Future<void> openEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);

    final note = (await database.select(database.notes).get()).single;
    final controller = EditNoteController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        // Panelin içindeki hatırlatma denetimi tercihleri kapsamdan okuyor.
        home: AppScope(
          notes: repository,
          settings: settings,
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: EditNoteSheet(
                    note: note,
                    repository: repository,
                    controller: controller,
                    onSaved: () {},
                    onScheduleReminder: (_) {},
                  ),
                ),
                EditNoteActionRail(
                  controller: controller,
                  onCancel: () {},
                  onDismissed: () {},
                  onDismissRequested: controller.saveForDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(EditNoteSheet), findsOneWidget);
  }

  /// Ağacı söker.
  ///
  /// [AppScope] süpürme ve hatırlatma saati için zamanlayıcı kuruyor; ağaç
  /// yerinde bırakılırsa test "bir Timer hâlâ bekliyor" diye düşüyor.
  Future<void> closeEditor(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  /// Kaydetme kelimesi basılabilir mi.
  bool canSave(WidgetTester tester) => tester
      .getSemantics(find.byKey(const ValueKey('edit-action-save')))
      .getSemanticsData()
      .flagsCollection
      .isEnabled ==
      Tristate.isTrue;

  /// Kaydın diskteki gövdesi.
  Future<String> bodyOnDisk() async {
    final rows = await database.select(database.notes).get();
    return rows.single.body;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('edit-note-body-field')),
      text,
    );
    await settle(tester);
  }

  testWidgets('karesiz kaydın yazısı silinince kaydetme kapanıyor', (
    tester,
  ) async {
    await repository.createText(
      body: 'Faturayı öde',
      retention: const RetentionChoice.off(),
    );
    await openEditor(tester);

    expect(canSave(tester), isTrue);

    await type(tester, '');
    expect(canSave(tester), isFalse);

    // Yalnız boşluktan ibaret gövde de boş sayılıyor.
    await type(tester, '   ');
    expect(canSave(tester), isFalse);

    // Ve kayıt diskte olduğu gibi duruyor. Drift'in gerçek asenkronu sahte
    // saat altında ilerlemediği için okuma `runAsync` içinde.
    expect(await tester.runAsync(bodyOnDisk), 'Faturayı öde');

    // Yazı geri gelince kapı da açılıyor ve kaydetme gerçekten yazıyor.
    await type(tester, 'Faturayı yarın öde');
    expect(canSave(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('edit-action-save')));
    await settle(tester);

    expect(await tester.runAsync(bodyOnDisk), 'Faturayı yarın öde');
    await closeEditor(tester);
  });

  test('kural yalnızca karesiz kaydı kapsıyor', () async {
    // Kapsam burada kilitleniyor. Kare varsa gövdenin boşalmasında sakınca
    // yok: kayıt hâlâ bir şey. Aksi hâlde kullanıcı fotoğrafına yazdığı notu
    // bir daha hiç silemezdi.
    //
    // Ölçü widget koşumunda değil: fotoğraflı bir kayıtla açılan panel,
    // [AppScope]'un arka plan küçük-kopya işi yüzünden sahte saat altında
    // hiç bitmiyor. Kural zaten panelin değil kaydın kuralı.
    final photo = File('${sandbox.path}/p.png')..writeAsBytesSync(_pixel);
    await repository.create(
      capture: XFile(photo.path),
      body: 'silinebilir olmalı',
      retention: const RetentionChoice.off(),
    );
    await repository.createText(
      body: 'yazıdan ibaret',
      retention: const RetentionChoice.off(),
    );

    final notes = await repository.watchNotes().first;
    final framed = notes.firstWhere((note) => note.hasPhoto);
    final textOnly = notes.firstWhere((note) => note.isTextOnly);

    expect(framed.wouldBeEmpty(''), isFalse);
    expect(framed.wouldBeEmpty('   '), isFalse);
    expect(textOnly.wouldBeEmpty(''), isTrue);
    expect(textOnly.wouldBeEmpty('   \n '), isTrue);
    expect(textOnly.wouldBeEmpty('bir şey'), isFalse);
  });
}
