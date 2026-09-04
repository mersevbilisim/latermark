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
import 'package:latermark/features/notes/presentation/detail/note_detail_page.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/shared/widgets/aperture.dart';
import 'package:latermark/shared/widgets/choice_rail.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_motion');
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

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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

  // `pumpAndSettle` yalnız ekranda sürekli dönen hiçbir şey kalmadığında
  // döner. Uygulamanın geri kalanında bu çağrı asla tamamlanmaz — diyafram
  // nefes alır, künye kelimesi solar. "Hareketi azalt" açıkken tamamlanması
  // gerekiyor: ölçüt bu, tek tek animasyonları saymak değil.
  testWidgets('hareket azaltıldığında ana ekranda dönen hiçbir şey kalmıyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );

    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await disposeTree(tester);
  });

  testWidgets('hareket azaltıldığında dolu akış ve detay da duruyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await tester.tap(find.byType(NoteCard));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailPage), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    await disposeTree(tester);
  });

  /// İki kare arasında öğe yer değiştirdi mi.
  ///
  /// `pumpAndSettle`'ın dönmesi yalnız **sürekli** hareketin durduğunu
  /// kanıtlıyor; 760 ms'lik bir yolculuk da tamamlanıp duruyor ve o teste
  /// yakalanmıyordu. Ölçüt burada konum: tercih açıkken sahne kurulmaz,
  /// kurulmuş gelir.
  Future<double> travelOf(
    WidgetTester tester,
    Finder finder, {
    Duration over = const Duration(milliseconds: 200),
  }) async {
    final first = tester.getRect(finder.first);
    await tester.pump(over);
    final second = tester.getRect(finder.first);
    return (second.top - first.top).abs() + (second.left - first.left).abs();
  }

  testWidgets('ilk kayıtta diyafram yol almıyor, yerine varıyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await tester.pumpAndSettle();

    // Boş ekranda diyafram ortada; ilk kayıt kaydedilince şeride iniyor.
    // Ölçüldü: tercih yokken bu yol 362 pt.
    await addNote(tester, 'Otopark P10');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      await travelOf(tester, find.byType(ApertureButton)),
      lessThan(1),
      reason: 'diyafram hâlâ yol alıyor',
    );

    await tester.pumpAndSettle();
    await disposeTree(tester);
  });

  testWidgets('detay sayfası yazma kipine kayarak geçmiyor', (tester) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NoteCard));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('detail-action-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Baskı yazma kipinde küçülüyor: yeni ölçüsünde doğmalı, küçülerek değil.
    expect(
      await travelOf(tester, find.byKey(const ValueKey('note-photo-stage'))),
      lessThan(1),
      reason: 'baskı sahnesi hâlâ morfluyor',
    );

    await tester.pumpAndSettle();
    await disposeTree(tester);
  });

  testWidgets('seçim rayının pili kaymadan yerine geçiyor', (tester) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();

    final rail = find.byType(ChoiceRail<AppThemeMode>);
    await tester.ensureVisible(rail);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: rail, matching: find.text('Aydınlık')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      await travelOf(
        tester,
        find.descendant(of: rail, matching: find.byType(AnimatedPositioned)),
      ),
      lessThan(1),
      reason: 'pil hâlâ kayıyor',
    );

    await tester.pumpAndSettle();
    await disposeTree(tester);
  });

  testWidgets('uygulama içi tercih tek başına hareketi durduruyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    // Sistem tercihi KAPALI: durduran şey Latermark'ın kendi anahtarı.
    await settings.setAlwaysReduceMotion(true);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );

    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);

    await disposeTree(tester);
  });
}
