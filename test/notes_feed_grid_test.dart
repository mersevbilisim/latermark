import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/presentation/home/widgets/home_header.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/notes/presentation/home/widgets/shutter_dock.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';

/// 1×1 saydam PNG — çözülebilir gerçek bir görsel olması yeterli.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Hero taşımasının dışında bırakılmış alt ağaçlar.
Iterable<HeroMode> _withdrawn(WidgetTester tester) => tester
    .widgetList<HeroMode>(find.byType(HeroMode))
    .where((mode) => !mode.enabled);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_feed_grid');
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

  Future<void> addNote(WidgetTester tester, String body, DateTime at) async {
    await tester.runAsync(() async {
      final file = File(
        '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(file.path),
        body: body,
        retention: const RetentionChoice(Retention.off),
        createdAt: at,
      );
    });
  }

  /// Arşiv birden çok yaş bölümüne yayıldığında ızgara aşağı gitmeyi
  /// bırakıyordu: her bölüm kendi sliver'ı ve geride kalan ızgara her karede
  /// kaydırmayı kendi konumu kadar geri çekiyordu. Parmak kayıyor, liste başa
  /// dönüyor, eski kayıtlara hiç ulaşılamıyordu.
  testWidgets('ızgarada en eski kayda kadar kaydırılabiliyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    // Bugünden iki yıl geriye: bugün, geçen hafta, geçen ay, üç ay, yıl ve
    // daha eski — akışta altı ayrı bölüm oluşuyor.
    for (var i = 0; i < 40; i++) {
      await addNote(tester, 'kare$i', now.subtract(Duration(days: i * 18)));
    }

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);

    for (var step = 0; step < 30; step++) {
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Akışın sonu gerçekten geliyor.
    expect(find.text('kare39'), findsOneWidget);
    expect(position.pixels, greaterThan(1000));

    // Geri dönüş de takılmıyor: tepe yine tepe.
    for (var step = 0; step < 30; step++) {
      await tester.drag(scrollable, const Offset(0, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Yaylanma sönene kadar bekle: tepede duruş tam sıfır olmalı.
    await settle(tester);
    expect(position.pixels, 0);
    expect(find.text('kare0'), findsOneWidget);

    await disposeTree(tester);
  });

  /// Yoğunluk geçişi 420 ms sürüyor ve o süre boyunca iki düzen birlikte
  /// yaşıyor — aynı kare iki kez çiziliyor. Hero etiketleri kayıt kimliğine
  /// bağlı olduğu için bu, geçiş penceresinde bir karta dokunmayı "aynı
  /// etiketten iki tane" hatasına çeviriyordu.
  testWidgets('geçiş sırasında çekilen düzen Hero taşımasının dışında', (
    tester,
  ) async {
    usePhoneSurface(tester);

    for (var i = 0; i < 4; i++) {
      await addNote(tester, 'kare$i', DateTime.now());
    }
    await settings.setDensity(FeedDensity.single);

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
    expect(find.byType(NoteCard), findsWidgets);
    expect(_withdrawn(tester), isEmpty);

    await tester.runAsync(() => settings.setDensity(FeedDensity.grid));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Aynı kare iki düzende birden duruyor...
    expect(find.text('kare0'), findsNWidgets(2));
    // ...ama çekilen düzen taşımanın dışında, yani her etiketten bir Hero
    // kalıyor. Uçuş her zaman yerine oturan düzenden başlar.
    expect(_withdrawn(tester), hasLength(1));

    // Geçiş bitince ortada tek düzen kalıyor, kapı da açılıyor.
    await settle(tester);
    expect(find.text('kare0'), findsOneWidget);
    expect(_withdrawn(tester), isEmpty);

    await disposeTree(tester);
  });

  /// Arama sonucu zaman başlıklarına bölünmeden tek bir ızgarada çiziliyor;
  /// ızgara oradan da geçiyor mu.
  testWidgets('ızgarada arama sonuçları listeleniyor', (tester) async {
    usePhoneSurface(tester);

    await addNote(tester, 'Otopark P10', DateTime.now());
    await addNote(
      tester,
      'Fatura',
      DateTime.now().subtract(const Duration(days: 40)),
    );
    await addNote(
      tester,
      'Otopark P3',
      DateTime.now().subtract(const Duration(days: 400)),
    );

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'otopark');
    await settle(tester);

    // İki eşleşme kalıyor, tarih ayıraçları kalkıyor.
    expect(find.text('Otopark P10'), findsOneWidget);
    expect(find.text('Otopark P3'), findsOneWidget);
    expect(find.text('Fatura'), findsNothing);
    expect(find.text('BUGÜN'), findsNothing);

    await disposeTree(tester);
  });

  /// Bölümde tek kare varsa sütunlardan biri boş kalıyor; boş bir tembel
  /// liste de düzeni bozmamalı.
  testWidgets('tek kareli bölüm ızgarayı bozmuyor', (tester) async {
    usePhoneSurface(tester);

    await addNote(tester, 'yalnız', DateTime.now());
    await addNote(
      tester,
      'eski bir',
      DateTime.now().subtract(const Duration(days: 400)),
    );
    await addNote(
      tester,
      'eski iki',
      DateTime.now().subtract(const Duration(days: 401)),
    );

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('yalnız'), findsOneWidget);
    expect(find.text('eski bir'), findsOneWidget);
    expect(find.text('eski iki'), findsOneWidget);

    await disposeTree(tester);
  });

  /// Seçim kipi ızgarada da kareyi işaretliyor mu.
  testWidgets('ızgarada seçim kipi kareyi işaretliyor', (tester) async {
    usePhoneSurface(tester);

    await addNote(tester, 'kare bir', DateTime.now());
    await addNote(tester, 'kare iki', DateTime.now());

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);
    expect(find.text('SEÇİM YOK'), findsOneWidget);

    await tester.tap(find.text('kare bir'));
    await settle(tester);
    expect(find.text('1 SEÇİLDİ'), findsOneWidget);

    await disposeTree(tester);
  });

  Finder separator(String group) =>
      find.byKey(ValueKey('age-separator-$group'));

  /// Sayı her ayraçta çiziliyor, yalnız görünürlüğü değişiyor — bu yüzden
  /// varlığı değil opaklığı sorgulanıyor.
  double countOpacity(WidgetTester tester, String group) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: separator(group),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  String countOf(WidgetTester tester, String group) => tester
      .widget<Text>(
        find.descendant(of: separator(group), matching: find.byType(Text)).last,
      )
      .data!;

  /// Uzun bir arşivde tarama kolaylığı: bölüm kapanınca kayıtları ağaca hiç
  /// girmiyor.
  testWidgets('zaman bölümü kapanıp açılıyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    await addNote(tester, 'bugunku kare', now);
    await addNote(tester, 'eski kare', now.subtract(const Duration(days: 20)));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    expect(find.text('bugunku kare'), findsOneWidget);
    expect(find.text('eski kare'), findsOneWidget);

    // Ayracın kendisi hedef: 15 puanlık irise nişan almak gerekmiyor.
    await tester.tap(find.byKey(const ValueKey('age-separator-pastMonth')));
    await settle(tester);

    expect(find.text('eski kare'), findsNothing);
    // Kapağın üstünde ne saklandığı yazıyor. Sayının **yeri** her ayraçta
    // ayrılıyor (kapanırken satır zıplamasın diye), okunması kapağa bağlı.
    expect(countOf(tester, 'pastMonth'), '1');
    expect(countOpacity(tester, 'pastMonth'), 1);
    expect(countOpacity(tester, 'today'), 0);
    // Kapatılan bölüm dışındaki hiçbir şey etkilenmiyor.
    expect(find.text('bugunku kare'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('age-separator-pastMonth')));
    await settle(tester);
    expect(find.text('eski kare'), findsOneWidget);
    expect(countOpacity(tester, 'pastMonth'), 0);

    await disposeTree(tester);
  });

  /// Kapalı bölüm uygulamayı kapatınca da kapalı kalıyor.
  ///
  /// Tercih ayarlar tablosunda duruyor; burada sınanan şey **aynı diskten**
  /// yeniden kurulan bir ağacın onu geri okuması.
  testWidgets('kapalı bölüm yeniden açılışta kapalı geliyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    await addNote(tester, 'bugunku kare', now);
    await addNote(tester, 'eski kare', now.subtract(const Duration(days: 20)));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    await tester.tap(separator('pastMonth'));
    await settle(tester);
    expect(find.text('eski kare'), findsNothing);

    // Ağaç tamamen sökülüp aynı depolarla yeniden kuruluyor: uygulamayı
    // kapatıp açmanın testteki karşılığı.
    await disposeTree(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    expect(find.text('bugunku kare'), findsOneWidget);
    expect(
      find.text('eski kare'),
      findsNothing,
      reason: 'Kapatılan bölüm açılışta yeniden açılmamalı',
    );
    expect(countOpacity(tester, 'pastMonth'), 1);

    await disposeTree(tester);
  });

  /// Görünmeyen kayıt silinemez.
  ///
  /// Seçim kipinde kapalı bir bölüm kalsaydı kullanıcı, ekranda hiç görmediği
  /// kareleri de kapsayan bir silme yapabilirdi — geri dönüşü olmayan bir
  /// işlemi göremediği şeyin üstünde.
  testWidgets('seçim kipi kapalı bölüm bırakmıyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    await addNote(tester, 'bugunku kare', now);
    await addNote(tester, 'eski kare', now.subtract(const Duration(days: 20)));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('age-separator-pastMonth')));
    await settle(tester);
    expect(find.text('eski kare'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);

    // Kip açılırken bölüm de açıldı: silinecek her şey ekranda.
    expect(find.text('SEÇİM YOK'), findsOneWidget);
    expect(find.text('eski kare'), findsOneWidget);

    // Ve kipteyken ayraç artık bir düğme değil.
    expect(
      tester.widget<AgeSeparator>(separator('pastMonth')).onToggle,
      isNull,
    );

    // Kipten çıkınca kullanıcı arşivini bıraktığı gibi buluyor: açılma
    // **geçici**, tercih silinmiyor.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);

    expect(
      find.text('eski kare'),
      findsNothing,
      reason: 'Toplu silmeden vazgeçmek kapalı bölümü kalıcı olarak açmamalı',
    );
    expect(countOpacity(tester, 'pastMonth'), 1);

    // Diske de yazılmamış olmalı: yeniden açılışta hâlâ kapalı.
    await disposeTree(tester);
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
    expect(find.text('eski kare'), findsNothing);

    await disposeTree(tester);
  });

  /// Aramada tarih omurgası yok: `14:32` üç yıl önceki bir kareyi bugünkünden
  /// ayırmıyor. Damga orada kendi tarihini taşımalı, akışta ise saat kalmalı.
  testWidgets('arama sonucundaki kart kendi tarihini taşıyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    await addNote(tester, 'Otopark P10', now);
    await addNote(tester, 'Otopark P10', DateTime(now.year - 3, 5, 6, 14, 32));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    // Akışta gün ayıracı var: künye yalnız saati söyler, tarih yok.
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(find.textContaining('${now.year - 3}'), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'otopark');
    await settle(tester);

    // İki eşleşme yan yana; ayıraç yok ama eski kare artık yılını söylüyor —
    // ve saat damganın sonunda duruyor, kaybolmuyor.
    expect(find.text('Otopark P10'), findsNWidgets(2));
    expect(find.text('BUGÜN'), findsNothing);
    expect(find.textContaining('${now.year - 3}'), findsOneWidget);
    expect(find.textContaining('14:32'), findsOneWidget);
    expect(find.textContaining('Bugün'), findsOneWidget);

    await disposeTree(tester);
  });

  /// Arama kutusuna dokunmak akışı yerinden oynatmamalı: tarih omurgası durur,
  /// daralma ancak yazmaya başlayınca olur. Boş kutu için bütün akışı söküp
  /// yeniden kurmak dokunuşta hissedilen takılmayı yaratıyordu.
  testWidgets('boş arama kutusu akışın düzenini bozmuyor', (tester) async {
    usePhoneSurface(tester);

    final now = DateTime.now();
    await addNote(tester, 'Otopark P10', now);
    await addNote(tester, 'Fatura', now.subtract(const Duration(days: 400)));

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
    expect(find.text('BUGÜN'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);

    // Kutu açık ama sorgu yok: ayıraçlar yerinde, kartlar hâlâ saati taşıyor.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(find.text('Otopark P10'), findsOneWidget);
    expect(find.text('Fatura'), findsOneWidget);
    expect(find.textContaining('Bugün'), findsNothing);

    // Yazınca tek kümeye dönüyor.
    await tester.enterText(find.byType(TextField), 'otopark');
    await settle(tester);
    expect(find.text('BUGÜN'), findsNothing);
    expect(find.text('Fatura'), findsNothing);

    // Sorgu silinince omurga geri geliyor.
    await tester.enterText(find.byType(TextField), '');
    await settle(tester);
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(find.text('Fatura'), findsOneWidget);

    await disposeTree(tester);
  });

  /// Aramada eşleşme çıkmadığında şerit "ilk kareni çek" davetine dönüyordu:
  /// dev deklanşör başlığın üstüne biniyor ve dolu bir arşivi olan kullanıcıya
  /// boş uygulama gösteriliyordu. Ücretsiz katman sayacı da aynı yerden
  /// besleniyordu, yani aramada yanlış sayı yazıyordu. Şerit ekrandaki
  /// süzülmüş listeye değil, arşive bakmalı.
  testWidgets('sonuçsuz arama boş ekran davetini getirmiyor', (tester) async {
    usePhoneSurface(tester);

    await addNote(tester, 'Otopark P10', DateTime.now());
    await addNote(tester, 'Fatura', DateTime.now());

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);

    ShutterDock dock() => tester.widget<ShutterDock>(find.byType(ShutterDock));
    expect(dock().docked, isTrue);
    expect(dock().noteCount, 2);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'buradaboylebirseyyok');
    await settle(tester);

    // Eşleşme yok...
    expect(find.byType(NoteCard), findsNothing);
    expect(find.text('0 SONUÇ'), findsOneWidget);
    // ...ama arşiv dolu: şerit yerinde kalıyor, davet açılmıyor.
    expect(dock().docked, isTrue);
    // Ve sayaç arşivi sayıyor, ekrandaki eşleşmeleri değil.
    expect(dock().noteCount, 2);

    await disposeTree(tester);
  });
}
