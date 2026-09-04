import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app_boot.dart';
import 'package:latermark/features/notes/data/archive_recovery.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/shared/widgets/aperture.dart';

/// Arşiv okunamadığında ana ekran ne diyor.
///
/// Bu durum boş tuvalle geçiştiriliyordu: kullanıcının gördüğü şey açılış
/// ekranından ayırt edilemeyen kara bir sayfaydı. Oradan çıkarılacak tek sonuç
/// "kayıtlarım gitti" olur ve o sonucun götüreceği yer uygulamayı silmektir —
/// asıl veri kaybı işte o zaman olur. Ekran bu yüzden iki şey söylemek
/// zorunda: ne olduğu ve ne yapılmaması gerektiği.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late PhotoStore photos;

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_archive_down');
    // Veritabanı yerine okunamayan bir dosya: SQLite açmayı reddediyor ve
    // Drift akışı hata yayıyor. Cihazda bozulan bir arşivin karşılığı bu.
    final broken = File('${sandbox.path}/broken.sqlite')
      ..writeAsStringSync('bu bir veritabanı değil');
    database = NotesDatabase.forExecutor(NativeDatabase(broken));
    photos = await PhotoStore.openIn(sandbox);
  });

  tearDown(() async {
    try {
      await database.close();
    } on Object {
      // Zaten açılamamış bağlantı kapanırken de itiraz edebilir.
    }
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Diskte, uygulamanın kendi adlandırmasıyla duran bir kare: onarımın
  /// kurtaracağı şey.
  File dropFrame(DateTime at, String salt) {
    final file = File(
      '${sandbox.path}/captures/${at.microsecondsSinceEpoch}-$salt.jpg',
    );
    file.parent.createSync(recursive: true);
    return file..writeAsBytesSync(_pixel);
  }

  /// Gerçek kök: onarım yığını tazelemek zorunda olduğu için ekranı
  /// `LatermarkApp` ile değil buradan kuruyoruz.
  Widget boot() => LatermarkBoot(
    photos: photos,
    initialDatabase: database,
    recovery: ArchiveRecovery(photos: photos, databaseDirectory: sandbox),
    // Onarımın kuracağı taze veritabanı; testte `path_provider` yok.
    openDatabase: () => NotesDatabase.forExecutor(
      NativeDatabase(File('${sandbox.path}/repaired.sqlite')),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('okunamayan arşiv boş ekranla geçiştirilmiyor', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(boot());
    await settle(tester);

    // Uygulama açıldı: ölü açılış ekranı yok.
    expect(find.byType(LatermarkBoot), findsOneWidget);
    expect(
      find.byKey(const Key('archive-unavailable-title')),
      findsOneWidget,
      reason: 'Arşiv okunamadığında ekran sebebini söylemeli',
    );
    // Kullanıcıyı uygulamayı silmekten alıkoyan cümle ekranda.
    //
    // Dil İngilizce: arşiv okunamıyorsa **tercihler de** okunamıyor ve
    // uygulama cihazın diline düşüyor. Bu ekranın kendi gerçeği — mesajın
    // kullanıcının seçtiği dilde çıkacağının garantisi yok.
    expect(find.textContaining("Don't delete the app"), findsOneWidget);
    // Deklanşör çizilmiyor: okunamayan bir arşivin üstüne kare eklemek
    // kullanıcıya olmayan bir normallik gösterirdi.
    expect(find.byType(ApertureButton), findsNothing);
    // Yeniden denemek bir sorgu: kalıcı olmayan bir kilit için tek çıkış yolu.
    expect(
      find.byKey(const ValueKey('archive-unavailable-retry')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('yeniden dene arşivi tekrar sorar', (tester) async {
    await tester.pumpWidget(boot());
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('archive-unavailable-retry')));
    await settle(tester);

    // Dosya hâlâ bozuk, yani ekran yerinde kalıyor — ama dokunuş bir çökmeye
    // dönüşmüyor ve mesaj kayboluyor da değil.
    expect(find.byKey(const Key('archive-unavailable-title')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('kurtarılacak kare yoksa onarım sunulmuyor', (tester) async {
    await tester.pumpWidget(boot());
    await settle(tester);

    // Hiçbir şey getirmeyecek bir düğmeyi ekrandaki en umut verici şey yapmak
    // olurdu.
    expect(find.byKey(const ValueKey('archive-repair')), findsNothing);
    expect(find.byKey(const Key('archive-repair-count')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('onarım kareleri geri alıyor ve bozuk dosyayı silmiyor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final broken = File('${sandbox.path}/${ArchiveRecovery.databaseFileName}')
      ..writeAsStringSync('bu bir veritabanı değil');
    final first = dropFrame(DateTime(2026, 8, 1, 9), 'aaaa');
    final second = dropFrame(DateTime(2026, 8, 2, 9), 'bbbb');

    await tester.pumpWidget(boot());
    await settle(tester);

    // Sayı basmadan önce ekranda: kullanıcı sonucunu görmeden karar vermiyor.
    expect(find.byKey(const Key('archive-repair-count')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('archive-repair')));
    await settle(tester);

    // Kareler kayıt olarak geri geldi: ekran artık arşivi çiziyor.
    expect(find.byKey(const Key('archive-unavailable-title')), findsNothing);
    expect(find.byType(ApertureButton), findsOneWidget);

    // Dosyalar yerinde ve bozuk veritabanı **silinmedi**, yana alındı.
    expect(first.existsSync(), isTrue);
    expect(second.existsSync(), isTrue);
    expect(broken.existsSync(), isFalse);
    expect(
      sandbox.listSync().whereType<File>().any(
        (file) => file.path.contains('.broken-'),
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
