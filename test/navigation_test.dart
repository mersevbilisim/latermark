import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/compose/compose_page.dart';
import 'package:latermark/features/notes/presentation/detail/note_detail_page.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/notes/presentation/home/widgets/shutter_dock.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';

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
    sandbox = await Directory.systemTemp.createTemp('latermark_nav');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    // Doğrulanan metinler Türkçe. Test ortamının sistem dili İngilizce'ye
    // düşüyor, o yüzden dil burada bir kez sabitleniyor — tercih veritabanında
    // durduğu için sonraki her `LatermarkApp` örneği onu okuyor.
    await SettingsRepository(database).setLocale(AppLocale.turkish);
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
        retention: RetentionChoice(Retention.threeDays),
      );
    });
  }

  testWidgets('kayıt yokken davet gösterilir', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    expect(find.text('Dokun ve çek'), findsOneWidget);
    expect(find.text('Galeriden seç'), findsOneWidget);
    // Manifesto küçük kapitel çiziliyor; Türkçe büyük harf kuralı geçerli.
    expect(find.text('SADE'), findsOneWidget);
    expect(find.text('CİHAZINDA'), findsOneWidget);
    expect(find.text('GÜVENDE'), findsOneWidget);
    expect(find.byType(NoteCard), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('galeriden gelen fotoğraf mevcut etiketleme akışını açar', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final galleryFile = File('${sandbox.path}/gallery.png');
    await tester.runAsync(() => galleryFile.writeAsBytes(_pixel));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ComposePage(
          capture: XFile(galleryFile.path),
          source: ComposeSource.gallery,
        ),
      ),
    );
    await settle(tester);

    expect(find.text('GALERİ'), findsOneWidget);
    expect(find.text('Başka fotoğraf'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(galleryFile.existsSync(), isTrue);

    await disposeTree(tester);
    // Compose ekranı kapanırken galeri kaynağına dokunmamalı.
    expect(galleryFile.existsSync(), isTrue);
  });

  testWidgets('Android paylaşımından gelen fotoğraf etiketleme akışını açar', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final sharedFile = File('${sandbox.path}/shared.png');
    await tester.runAsync(() => sharedFile.writeAsBytes(_pixel));
    var delivered = false;
    var completed = false;

    const channel = MethodChannel('latermark/shared_import');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'takePendingSharedImport' && !delivered) {
            delivered = true;
            return <String, Object?>{
              'id': '03f17aca-a2f8-4f42-a50f-3c52935c7340',
              'path': sharedFile.path,
              'initialText': 'Galeriden paylaşılan etiket',
              'createdAtMilliseconds': DateTime.now().millisecondsSinceEpoch,
              'saveImmediately': false,
            };
          }
          if (call.method == 'completeSharedImport') completed = true;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    expect(find.text('PAYLAŞIM'), findsOneWidget);
    expect(find.text('Galeriden paylaşılan etiket'), findsOneWidget);
    expect(find.text('Başka fotoğraf'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    expect(completed, isTrue);

    await disposeTree(tester);
  });

  testWidgets('kayıt varken akış ve yerleşmiş deklanşör gösterilir', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Muhasebeye göndereceğim');
    final settings = SettingsRepository(database);
    // Gün ayıraçları yalnızca tek sütun görünümünde var; varsayılan ızgara.
    await settings.setDensity(FeedDensity.single);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
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
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NoteDetailPage), findsOneWidget);
    // Rota opak olmadığı için ana akış hâlâ ağaçta: aynı metin arkadaki kartta
    // da duruyor. Aranan şey detayın kendi kopyası.
    expect(
      find.descendant(
        of: find.byType(NoteDetailPage),
        matching: find.text('Araba burada — P10'),
      ),
      findsOneWidget,
    );

    // Üç eylem de alt şeritte görünür durur; hiçbiri menüye saklanmaz.
    expect(find.byKey(const ValueKey('detail-action-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-action-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-action-delete')), findsOneWidget);

    // Düzenleme ayrıca okunan satırın kendisine dokunarak da açılır.
    await tester.tap(find.byKey(const ValueKey('detail-note-copy')));
    await settle(tester);
    expect(find.text('Kaydet'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets(
    'widgettaki eski bir kimlik boş detay bırakmadan ana ekrana döner',
    (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        LatermarkApp(notes: repository, settings: SettingsRepository(database)),
      );
      await settle(tester);

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const NoteDetailPage(noteId: 404),
            ),
          );
      await settle(tester);

      expect(find.byType(NoteDetailPage), findsNothing);
      expect(find.text('Dokun ve çek'), findsOneWidget);

      await disposeTree(tester);
    },
  );

  testWidgets('otomatik silme durumu detayda okunur biçimde görünür', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await addNote(tester, 'Fiş');
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: SettingsRepository(database)),
    );
    await settle(tester);

    await tester.tap(find.byType(NoteCard));
    await settle(tester);

    // Kart bir bakışlık kısa biçimi ("3g") taşıyor; detay tam cümleyi.
    expect(
      find.text('2 GÜN 23 SAAT SONRA SİLİNECEK'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('detail-life-edge')), findsOneWidget);

    await disposeTree(tester);
  });
}
