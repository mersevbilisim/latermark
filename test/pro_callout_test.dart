import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/shared/widgets/pro_badge.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/presentation/widgets/pro_callout.dart';
import 'package:latermark/features/paywall/domain/pro_limits.dart';
import 'package:latermark/l10n/app_localizations.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_pro_callout');
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

  Future<void> addNotes(WidgetTester tester, int count) async {
    await tester.runAsync(() async {
      for (var i = 0; i < count; i++) {
        final file = File('${sandbox.path}/shot-$i.png');
        await file.writeAsBytes(_pixel);
        await repository.create(
          capture: XFile(file.path),
          body: 'kare $i',
          retention: RetentionChoice(Retention.off),
        );
      }
    });
  }

  Future<void> pumpCallout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: AppScope(
          notes: repository,
          settings: settings,
          child: const Scaffold(
            body: Padding(padding: EdgeInsets.all(22), child: ProCallout()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    'kontakt baskısı dolu gözleri kullanıcının kareleriyle doldurur',
    (tester) async {
      // Sınırın altında bir sayı: kalan gözlerin boş kalması testin konusu.
      // Sabit bir sayı yerine sınırdan türetiliyor, yoksa ücretsiz katman her
      // değiştiğinde bu test kırılır — nitekim kırıldı.
      const filled = ProLimits.freeNotes - 2;
      await addNotes(tester, filled);
      await pumpCallout(tester);

      // Teklif okunuyor ve eylemin ne olduğu yazıyor — chevron değil.
      expect(find.text('Önemlileri sakla, hatırla.'), findsOneWidget);
      expect(find.text("Pro'ya geç"), findsOneWidget);
      // Kaç kare varsa o kadar göz dolu; gerisi boş kalıyor ve sınır
      // sayılabiliyor.
      expect(find.byType(Image), findsNWidgets(filled));

      await disposeTree(tester);
    },
  );

  testWidgets('şerit sınırdan fazlasını göstermez', (tester) async {
    // Ücretsiz katman zaten sınırda duruyor, ama şerit bunu kendi başına da
    // garanti etmeli: n gözü olan bir baskı n+1. kareyi çizemez. Geri yükleme
    // sınırın üstünde bir arşiv bırakabildiği için bu gerçek bir durum.
    await addNotes(tester, ProLimits.freeNotes + 2);
    await pumpCallout(tester);

    expect(find.byType(Image), findsNWidgets(ProLimits.freeNotes));

    await disposeTree(tester);
  });

  testWidgets('şerit kayıt eklendikçe kendiliğinden dolar', (tester) async {
    await addNotes(tester, 2);
    await pumpCallout(tester);
    expect(find.byType(Image), findsNWidgets(2));

    await addNotes(tester, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Image), findsNWidgets(3));

    await disposeTree(tester);
  });

  testWidgets('ödemiş kullanıcıya satış yapılmaz', (tester) async {
    await addNotes(tester, 3);
    await settings.setProUnlocked(true);
    await pumpCallout(tester);

    // Durum sakin biçimde ama **görünür** biçimde onaylanıyor. Ödediğini
    // hissetmesi gereken kullanıcıya jenerik bir onay ikonu ya da kenarlıklı
    // bir kapsül takılmıyor; uygulamanın kilitli kapı işareti olan diyafram
    // burada açılıyor — aynı sembolün zıt durumu.
    expect(find.text('LATERMARK PRO'), findsOneWidget);
    expect(find.byType(ProOwnedMark), findsOneWidget);
    expect(find.text('Latermark Pro senin.'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('Şu an 3 karen var.'), findsOneWidget);

    // Künye vurgu rengiyle çiziliyor: nötr griyken bu şerit ayarlardaki
    // herhangi bir bölüm başlığından ayırt edilemiyordu. Kurulum tema
    // uzantısı vermiyor, dolayısıyla `context.palette` koyu palete düşüyor.
    expect(
      tester.widget<Text>(find.text('LATERMARK PRO')).style?.color,
      AppPalette.dark.ember,
    );
    expect(find.text("Pro'ya geç"), findsNothing);
    expect(find.text('Önemlileri sakla, hatırla.'), findsNothing);
    expect(find.byType(Image), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('kart taşmadan sığar', (tester) async {
    await addNotes(tester, 9);
    await pumpCallout(tester);

    // Taşma olsaydı çerçeve testi zaten düşürürdü; burada kartın gerçekten
    // çizildiğini de doğruluyoruz.
    expect(find.byType(ProCallout), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });
}
