import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:not_app/app/app.dart';
import 'package:not_app/features/notes/data/notes_database.dart';
import 'package:not_app/features/notes/data/notes_repository.dart';
import 'package:not_app/features/notes/data/photo_store.dart';
import 'package:not_app/features/settings/data/settings_repository.dart';
import 'package:not_app/features/notes/domain/retention.dart';
import 'package:not_app/features/notes/presentation/detail/note_detail_page.dart';
import 'package:not_app/features/notes/presentation/home/widgets/note_card.dart';
import 'package:not_app/features/notes/presentation/home/widgets/shutter_dock.dart';

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
    sandbox = await Directory.systemTemp.createTemp('not_app_nav');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Testler varsayılan olarak 800x600'lük yatay bir yüzeyde koşar; bu düzen
  /// telefon için tasarlandığından kartlar oraya sığmıyor. Gerçek bir cihaz
  /// oranı vermek, dokunma noktalarının da doğru yere düşmesini sağlar.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Ana ekranda diyafram sürekli nefes aldığı için [WidgetTester.pumpAndSettle]
  /// asla dönmez. Sahnenin oturması için sabit sayıda kare çeviriyoruz.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  /// Ağacı söker ve bir kare daha çevirir.
  ///
  /// Drift, akış aboneliği iptal edilirken sıfır süreli bir timer kuruyor;
  /// test bittiğinde bu timer hâlâ beklemede olursa çerçeve "A Timer is still
  /// pending" diye patlıyor. Fazladan bir kare onu tüketiyor.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Süresi sıfır olsa da bir timer'ın çalışması için sahte saatin ilerlemesi
    // gerekir; `pump()` tek başına yalnızca kare çevirir.
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Kayıt eklemek gerçek dosya kopyalama yapar; bu yüzden testin sahte
  /// zaman bölgesi dışında, [WidgetTester.runAsync] içinde çalışmalı. Aksi
  /// halde `File.copy` future'ı hiç tamamlanmaz ve test asılı kalır.
  Future<void> addNote(WidgetTester tester, String body) async {
    await tester.runAsync(() async {
      final file = File(
        '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(file.path),
        body: body,
        retention: Retention.threeDays,
      );
    });
  }

  testWidgets('kayıt yokken davet gösterilir', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(LatermarkApp(notes: repository, settings: SettingsRepository(database)));
    await settle(tester);

    expect(find.text('Dokun ve çek'), findsOneWidget);
    expect(find.byType(NoteCard), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('kayıt varken akış ve yerleşmiş deklanşör gösterilir', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Muhasebeye göndereceğim');
    await tester.pumpWidget(LatermarkApp(notes: repository, settings: SettingsRepository(database)));
    await settle(tester);

    expect(find.text('Notlar'), findsOneWidget);
    expect(find.text('1 NOT'), findsOneWidget);
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(find.byType(NoteCard), findsOneWidget);
    expect(find.byType(ShutterDock), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('karta dokununca detay açılır ve depoya ulaşabilir', (
    tester,
  ) async {
    // Bu test, `AppScope`'un Navigator'ın ÜSTÜNDE durduğunu doğrular. Kapsam
    // `MaterialApp.home` içine konulursa push edilen bu sayfa depoyu bulamaz
    // ve assert ile patlar.
    usePhoneSurface(tester);
    await addNote(tester, 'Araba burada — P10');
    await tester.pumpWidget(LatermarkApp(notes: repository, settings: SettingsRepository(database)));
    await settle(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NoteDetailPage), findsOneWidget);
    expect(find.text('Araba burada — P10'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('otomatik silme durumu detayda okunur biçimde görünür', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Fiş');
    await tester.pumpWidget(LatermarkApp(notes: repository, settings: SettingsRepository(database)));
    await settle(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);

    expect(
      find.textContaining('3 Gün · 2 gün 23 saat sonra silinecek'),
      findsOneWidget,
    );

    await disposeTree(tester);
  });
}
