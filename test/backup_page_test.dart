import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/backup/presentation/backup_page.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  void useSurface(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> pumpCreate(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      theme: AppTheme.light(),
      home: const BackupPage.create(),
    ),
  );

  test('yedek dosya türü iOS ve Android sözleşmelerini birlikte taşır', () {
    expect(latermarkBackupType.extensions, contains('latermark'));
    expect(latermarkBackupType.uniformTypeIdentifiers, contains('public.data'));
    expect(
      latermarkBackupType.mimeTypes,
      containsAll([latermarkBackupMimeType, 'application/octet-stream']),
    );
  });

  testWidgets('yedek işlemleri paneli iki açık seçeneği kartsız gösterir', (
    tester,
  ) async {
    useSurface(tester, const Size(320, 568), textScale: 1.3);
    BackupMode? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showBackupActionsSheet(
                  context,
                  noteCount: 14,
                  // Diskte olmayan yollar: şeridin çizildiğini görmek için
                  // gerçek kare gerekmiyor, NotePhoto eksik dosyayı sessiz
                  // yer tutucuyla karşılıyor.
                  previews: [File('a.jpg'), File('b.jpg'), File('c.jpg')],
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // Yüzeyin ilk söylediği şey başlık değil, sayı: korumaya alınacak kare
    // adedi. Bölüm adı onun üstünde küçük kapitellerde duruyor.
    expect(find.text('YEDEKLEME'), findsOneWidget);
    expect(find.byKey(const Key('backup-actions-count')), findsOneWidget);
    expect(find.text('14 not'), findsOneWidget);

    // Panel bir ayar listesi değil, arşivin yüzü: üstte kullanıcının kendi
    // kareleri duruyor.
    expect(find.byKey(const Key('backup-actions-strip')), findsOneWidget);
    expect(find.byKey(const Key('backup-action-create')), findsOneWidget);
    expect(find.byKey(const Key('backup-action-restore')), findsOneWidget);

    // Sıralı olmayan iki alternatifi numaralamak tören katmaktan başka bir
    // şey yapmıyordu.
    expect(find.text('01'), findsNothing);
    expect(find.text('02'), findsNothing);

    // Yedeğin ne olduğu başlıkta, geri yüklemenin sonucu ise satırında.
    expect(
      find.text('Latermark\'ındaki her şey tek ve şifreli dosyada.'),
      findsOneWidget,
    );
    expect(
      find.text('Yedeğini geri yükleyerek tüm notlarını al.'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('backup-action-restore')));
    await tester.pumpAndSettle();
    expect(selected, BackupMode.restore);
  });

  testWidgets('kayıt yokken yedek alma kapalı ama sebebiyle görünür', (
    tester,
  ) async {
    // Boş arşivden teknik olarak geçerli ama işe yaramaz bir dosya çıkardı.
    // Seçenek gizlenmiyor: gizlemek "neden yedekleyemiyorum" sorusunu
    // doğururdu, soluk satır cevabı yanında taşıyor.
    useSurface(tester, const Size(320, 568), textScale: 1.3);
    BackupMode? selected;
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                opened++;
                selected = await showBackupActionsSheet(
                  context,
                  noteCount: 0,
                  previews: const [],
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yedeklenecek bir şey yok.'), findsOneWidget);
    // Arşiv boşken gösterilecek kare de yok.
    expect(find.byKey(const Key('backup-actions-strip')), findsNothing);

    // Dokunmak paneli kapatmamalı; seçenek gerçekten atıl.
    await tester.tap(find.byKey(const Key('backup-action-create')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(opened, 1);

    // Geri yükleme açık kalıyor: yeni telefonda yedeği açmanın tek yolu o.
    await tester.tap(find.byKey(const Key('backup-action-restore')));
    await tester.pumpAndSettle();
    expect(selected, BackupMode.restore);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'yedek parola ekranı dar telefonda app dilinde ve taşmadan açılır',
    (tester) async {
      useSurface(tester, const Size(320, 568), textScale: 1.3);
      await pumpCreate(tester);
      await tester.pumpAndSettle();

      expect(find.text('Bir parola seç'), findsOneWidget);
      expect(find.text('Bu parola yedeğinin tek anahtarı.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('kısa ve eşleşmeyen parola açıkça anlatılır', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpCreate(tester);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'kısa');
    await tester.enterText(fields.at(1), 'başka');
    await tester.tap(find.byKey(const Key('backup-password-submit')));
    await tester.pump();

    expect(find.text('En az 8 karakter kullan.'), findsOneWidget);

    await tester.enterText(fields.at(0), 'uzun-parola');
    await tester.enterText(fields.at(1), 'eşleşmiyor');
    await tester.tap(find.byKey(const Key('backup-password-submit')));
    await tester.pump();
    expect(find.text('İki parola aynı değil.'), findsOneWidget);
  });

  testWidgets('parola kaybı onayı standart yuvarlak checkbox değildir', (
    tester,
  ) async {
    useSurface(tester, const Size(390, 844));
    await pumpCreate(tester);
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    final mark = find.byKey(const Key('backup-square-check'));
    expect(mark, findsOneWidget);
    await tester.tap(mark);
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
