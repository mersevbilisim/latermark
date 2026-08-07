import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/app_scope.dart';
import 'package:not_app/features/notes/data/notes_database.dart';
import 'package:not_app/features/notes/data/notes_repository.dart';
import 'package:not_app/features/notes/data/photo_store.dart';
import 'package:not_app/features/notes/domain/retention.dart';
import 'package:not_app/features/settings/data/settings_repository.dart';
import 'package:not_app/features/settings/domain/app_locale.dart';
import 'package:not_app/features/settings/presentation/widgets/pro_callout.dart';
import 'package:not_app/l10n/app_localizations.dart';

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
    sandbox = await Directory.systemTemp.createTemp('not_app_pro_callout');
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
            body: Padding(
              padding: EdgeInsets.all(22),
              child: ProCallout(),
            ),
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

  testWidgets('kontakt baskısı dolu gözleri kullanıcının kareleriyle doldurur', (
    tester,
  ) async {
    await addNotes(tester, 7);
    await pumpCallout(tester);

    // Teklif okunuyor ve eylemin ne olduğu yazıyor — chevron değil.
    expect(find.text('Bazı kareler kalmalı.'), findsOneWidget);
    expect(find.text("Pro'ya geç"), findsOneWidget);
    // Yedi kare var, yedi göz dolu. Kalan üç göz boş: sınır sayılabiliyor.
    expect(find.byType(Image), findsNWidgets(7));

    await disposeTree(tester);
  });

  testWidgets('şerit sınırdan fazlasını göstermez', (tester) async {
    // Ücretsiz katman zaten 10'da duruyor, ama şerit bunu kendi başına da
    // garanti etmeli: 10 gözü olan bir baskı 11. kareyi çizemez.
    await addNotes(tester, 12);
    await pumpCallout(tester);

    expect(find.byType(Image), findsNWidgets(10));

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

    // Durum onaylanıyor: ne teklif ne de sayılacak bir sınır var.
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('Şu an 3 karen var.'), findsOneWidget);
    expect(find.text("Pro'ya geç"), findsNothing);
    expect(find.text('Bazı kareler kalmalı.'), findsNothing);
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
