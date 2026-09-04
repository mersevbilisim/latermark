import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/app/app_routes.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/detail/note_detail_page.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/notes/presentation/compose/compose_page.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/presentation/settings_page.dart';

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
    sandbox = await Directory.systemTemp.createTemp('latermark_backswipe');
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

  /// Kenardan başlayan, **kare çevirerek** ilerleyen çekiş.
  ///
  /// `dragFrom` bütün hareketi tek karede gönderiyor ve gerçek bir parmağın
  /// yaptığı şeyi yapmıyor: arada yeniden çizim olmuyor. Sayfa donduran
  /// hatalar tam da o yeniden çizimlerde ortaya çıkıyor.
  Future<void> edgeSwipe(
    WidgetTester tester, {
    required double toX,
    double y = 420,
    double fromX = 6,
  }) async {
    final gesture = await tester.startGesture(Offset(fromX, y));
    await gesture.moveBy(const Offset(kDragSlopDefault, 0));
    await tester.pump();

    var x = fromX + kDragSlopDefault;
    while (x < toX) {
      final step = math.min(48.0, toX - x);
      await gesture.moveBy(Offset(step, 0));
      x += step;
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
  }

  Future<void> openDetail(WidgetTester tester, String body) async {
    usePhoneSurface(tester);
    await addNote(tester, body);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);
    await tester.tap(find.byType(NoteCard));
    await settle(tester);
    expect(find.byType(NoteDetailPage), findsOneWidget);
  }

  testWidgets('kenardan sağa çekiş detay sayfasını geri veriyor', (
    tester,
  ) async {
    await openDetail(tester, 'Otopark P10');

    // Parmak ekranın sol kenarında başlıyor: iOS'un öğrettiği yer.
    await edgeSwipe(tester, toX: 260);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NoteDetailPage), findsNothing);
    expect(find.byType(NoteCard), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('eşiği geçmeyen çekiş sayfayı yerine geri yaylandırıyor', (
    tester,
  ) async {
    await openDetail(tester, 'Otopark P10');

    final chrome = find.byKey(const ValueKey('detail-chrome'));
    final restingX = tester.getTopLeft(chrome).dx;

    final gesture = await tester.startGesture(const Offset(6, 420));
    // İlk adım dokunma toleransını harcıyor; sayfa ondan sonra yola çıkıyor.
    await gesture.moveBy(const Offset(kDragSlopDefault, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // Sayfa gerçekten parmağın altında: hareket eşiği geçmese de görünür.
    expect(tester.getTopLeft(chrome).dx, greaterThan(restingX + 30));

    await gesture.up();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NoteDetailPage), findsOneWidget);
    // Yay tamamlandı: sayfa yerine oturdu, yolda kalmadı.
    expect(
      tester.getTopLeft(chrome).dx,
      moreOrLessEquals(restingX, epsilon: 0.5),
    );

    await disposeTree(tester);
  });

  testWidgets('kenar şeridi geri düğmesinin dokunuşunu yutmuyor', (
    tester,
  ) async {
    await openDetail(tester, 'Otopark P10');

    // Düğme tam bu bandın içinde duruyor; şerit yalnız yatay çekişi
    // sahiplendiği için dokunuş altına düşmeli.
    await tester.tap(find.byKey(const ValueKey('detail-action-back')));
    await settle(tester);

    expect(find.byType(NoteDetailPage), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('kenardan çekiş ayarlar sayfasını da geri veriyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    expect(find.byType(SettingsPage), findsOneWidget);

    await edgeSwipe(tester, toX: 300);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(NoteCard), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('opak sayfa çekilirken altındaki ekran görünür oluyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Otopark P10');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    // Sayfa yerleşince altındaki akış çizilmiyor: rota opak.
    expect(find.byType(NoteCard), findsNothing);

    final gesture = await tester.startGesture(const Offset(6, 420));
    await gesture.moveBy(const Offset(kDragSlopDefault, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));

    // Parmak sayfayı ittiği anda alttaki ekran geri geliyor. Sayfayı
    // `Transform` ile itseydik burada siyah bir boşluk olurdu.
    expect(find.byType(NoteCard), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);

    // Sayfa gerçekten parmağın altında ilerliyor — kare çevrildikten
    // *sonra* da. Jest sahibini kaybederse burada yerinde kalırdı.
    final movedTo = tester.getTopLeft(find.byType(SettingsPage)).dx;
    expect(movedTo, greaterThan(30));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getTopLeft(find.byType(SettingsPage)).dx,
      greaterThan(movedTo + 30),
    );

    await gesture.up();
    await settle(tester);

    // Eşiği geçmedi: sayfa yerine döndü, yolda donmadı.
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(SettingsPage)).dx,
      moreOrLessEquals(0, epsilon: 0.5),
    );
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('yazma ekranı da kenardan geri veriliyor', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    final textEntry = find.byKey(const ValueKey('invite-action-text'));
    await tester.ensureVisible(textEntry);
    await settle(tester);
    await tester.tap(textEntry);
    await settle(tester);
    expect(find.byType(ComposePage), findsOneWidget);

    await edgeSwipe(tester, toX: 300);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ComposePage), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('sayfa kendini kilitlediyse kenar çekişi de geçmiyor', (
    tester,
  ) async {
    usePhoneSurface(tester);
    // Kayıt sürerken yazma, yedekleme ve hatırlatma sayfaları `PopScope` ile
    // kendilerini kilitliyor. Jest kararı kendi vermiyor, aynı kapıdan
    // soruyor: kilidi olan sayfa çekilerek de kaçırılamıyor.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              AppRoutes.lift(
                const PopScope(
                  canPop: false,
                  child: Scaffold(body: Center(child: Text('kilitli'))),
                ),
              ),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('kilitli'), findsOneWidget);

    await edgeSwipe(tester, toX: 300);
    await tester.pumpAndSettle();

    expect(find.text('kilitli'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekranın ortasından yatay çekiş sayfayı kapatmıyor', (
    tester,
  ) async {
    await openDetail(tester, 'Otopark P10');

    await tester.dragFrom(const Offset(200, 420), const Offset(240, 0));
    await settle(tester);

    expect(find.byType(NoteDetailPage), findsOneWidget);

    await disposeTree(tester);
  });
}
