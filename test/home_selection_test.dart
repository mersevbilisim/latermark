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
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/shared/widgets/aperture.dart';

/// 1×1 saydam PNG — çözülebilir gerçek bir görsel olması yeterli.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_selection');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    await SettingsRepository(database).setLocale(AppLocale.turkish);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Diyafram sürekli nefes aldığı için `pumpAndSettle` ana ekranda dönmez.
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

  Future<void> addNote(WidgetTester tester, String body) async {
    await tester.runAsync(() async {
      final file = File(
        '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(file.path),
        body: body,
        retention: RetentionChoice(Retention.threeDays),
      );
    });
  }

  testWidgets('seçim kipi başlığı, sayacı ve şeridi birlikte değiştirir', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Fiş');
    await addNote(tester, 'Park yeri');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    expect(find.text('Notlar'), findsOneWidget);
    // Şerit üç yuvalı: solda galeri, ortada deklanşör, sağda eleme.
    // (Galeri ikonu boş sahnenin davet düğmesinde de var; o yüzden "en az
    // bir tane" aranıyor.)
    expect(find.byIcon(Icons.photo_library_outlined), findsWidgets);
    expect(find.byType(ApertureButton), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    // Üstlükte artık silme denetimi yok.
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);

    // Seçim ayrı bir ekran değil, başlığın bir hâli. Kipteyken deklanşörün
    // yerini künye dili alır; arama ve ayarlar çekilir.
    expect(find.text('Seç'), findsOneWidget);
    expect(find.text('SEÇİM YOK'), findsOneWidget);
    expect(find.text('Silmek istediğin karelere dokun'), findsOneWidget);
    expect(find.byType(ApertureButton), findsNothing);
    // Galeri yuvası boşalıyor ama yerinden sıçramıyor: sönerek çekiliyor.
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('dock-gallery-slot')),
          )
          .opacity,
      0,
    );
    expect(find.byIcon(Icons.search_rounded), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    // Girilen kapı çıkılan kapı: aynı yuva çarpıya döner.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byType(NoteCard).first);
    await settle(tester);

    expect(find.text('1 SEÇİLDİ'), findsOneWidget);
    // Hap düğme değil, künyedeki kelimenin aynısı.
    expect(find.text('SİL'), findsOneWidget);

    await tester.tap(find.byType(NoteCard).last);
    await settle(tester);

    expect(find.text('2 SEÇİLDİ'), findsOneWidget);

    // Aynı karta bir daha dokunmak işareti kaldırır.
    await tester.tap(find.byType(NoteCard).last);
    await settle(tester);
    expect(find.text('1 SEÇİLDİ'), findsOneWidget);

    // Kipten çıkınca hiçbir kayıt gitmemiş olur.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);

    expect(find.text('Notlar'), findsOneWidget);
    expect(find.byType(ApertureButton), findsOneWidget);
    expect(find.byType(NoteCard), findsNWidgets(2));

    await disposeTree(tester);
  });

  testWidgets('toplu silme tekli silmeyle aynı basılı tutma onayını açar', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Fiş');
    await addNote(tester, 'Park yeri');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);
    await tester.tap(find.byType(NoteCard).first);
    await tester.tap(find.byType(NoteCard).last);
    await settle(tester);

    await tester.tap(find.text('SİL'));
    await settle(tester);

    expect(find.text('2 kare silinsin mi?'), findsOneWidget);
    expect(find.text('Silmek için basılı tut'), findsOneWidget);

    // Vazgeçmek kipi bozmaz: seçim olduğu gibi durur.
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);

    expect(find.text('2 SEÇİLDİ'), findsOneWidget);
    expect(find.byType(NoteCard), findsNWidgets(2));

    await disposeTree(tester);
  });
}
