import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/core/theme/app_palette.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/detail/note_detail_page.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/detail_sheet.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/edit_note_sheet.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/domain/app_settings.dart';
import 'package:latermark/shared/widgets/glass_surface.dart';
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

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_detail_theme');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    repository = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
    await settings.setLocale(AppLocale.turkish);
    await settings.setThemeMode(AppThemeMode.light);
    await settings.setProUnlocked(true);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('not detayı ve düzenleme paneli açık tema paletini kullanır', (
    tester,
  ) async {
    const logicalSize = Size(393, 852);
    const topSafeInset = 47.0;
    const bottomSafeInset = 34.0;
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: topSafeInset,
      bottom: bottomSafeInset,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.runAsync(() async {
      final image = File('${sandbox.path}/light-detail.png');
      await image.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(image.path),
        body: 'Açık tema notu',
        retention: const RetentionChoice.off(),
      );
    });

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await _settle(tester);
    await tester.tap(find.byType(NoteCard));
    await _settle(tester);

    final detail = find.byType(NoteDetailPage);
    final palette = Theme.of(tester.element(detail)).extension<AppPalette>()!;
    expect(palette.brightness, Brightness.light);

    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: detail, matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, Colors.transparent);

    // Geri düğmesi ana ekranın sağ üst denetimleriyle aynı yuvarlak kabı
    // taşır: iki ekranda iki ayrı düğme dili yok.
    final backAction = find.byKey(const ValueKey('detail-action-back'));
    expect(tester.getSize(backAction), const Size.square(38));

    // Üç eylem alt şeritte, künyenin diliyle: ikon yok, geniş harf aralıklı
    // ad var. Sıra referans düzendeki gibi.
    final shareAction = find.byKey(const ValueKey('detail-action-share'));
    final editAction = find.byKey(const ValueKey('detail-action-edit'));
    final deleteAction = find.byKey(const ValueKey('detail-action-delete'));
    expect(find.byKey(const ValueKey('detail-action-bar')), findsOneWidget);
    final shareCenter = tester.getCenter(shareAction);
    final editCenter = tester.getCenter(editAction);
    final deleteCenter = tester.getCenter(deleteAction);
    expect(deleteCenter.dy, editCenter.dy);
    expect(editCenter.dy, shareCenter.dy);
    expect(deleteCenter.dx, lessThan(editCenter.dx));
    expect(editCenter.dx, lessThan(shareCenter.dx));
    // Hücreler eşit genişlikte: orta hücre şeridin ekseninde durur.
    expect(editCenter.dx, closeTo(logicalSize.width / 2, 0.5));
    expect(find.text('SİL'), findsOneWidget);
    expect(find.text('DÜZENLE'), findsOneWidget);
    expect(find.text('PAYLAŞ'), findsOneWidget);
    // Şerit güvenli alanın üstünde kalır.
    expect(logicalSize.height - editCenter.dy, greaterThan(bottomSafeInset));

    // Şerit bir kap değil, ama sınırsız da değil: kelimelerin üstünde
    // baskının bittiğini söyleyen güverte çizgisi var.
    final bar = find.byKey(const ValueKey('detail-action-bar'));
    expect(
      find.descendant(of: bar, matching: find.byType(GlassSurface)),
      findsNothing,
    );
    final rule = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 0.5,
      ),
    );
    expect(rule, findsOneWidget);
    expect(tester.getCenter(rule).dy, lessThan(editCenter.dy));
    expect(tester.getSize(rule).width, logicalSize.width - 32);

    // Renk dinlenirken yok; üç kelime de aynı mürekkepte. Tehlike sinyali
    // dokunma anında beliriyor, dinlenen ekranda değil.
    // Renk stilde değil boyanan paragrafta okunur: hücre onu
    // AnimatedDefaultTextStyle üzerinden veriyor.
    Color colorOf(Finder cell) => (tester.renderObject(
          find.descendant(of: cell, matching: find.byType(Text)),
        ) as RenderParagraph)
        .text
        .style!
        .color!;
    expect(colorOf(deleteAction), palette.ink);
    expect(colorOf(editAction), palette.ink);
    expect(colorOf(shareAction), palette.ink);

    final press = await tester.startGesture(deleteCenter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 400));
    expect(colorOf(deleteAction), palette.danger);
    expect(colorOf(shareAction), palette.ink);
    // Dokunuş tamamlanmıyor: bırakmak silme onayını açardı ve sayfanın geri
    // kalanı bu testin konusu değil.
    await press.cancel();
    await _settle(tester);
    expect(colorOf(deleteAction), palette.ink);

    final chrome = find.byKey(const ValueKey('detail-chrome'));
    final photoStage = find.byKey(const ValueKey('note-photo-stage'));
    final noteCopy = find.byKey(const ValueKey('detail-note-copy'));
    final dateStamp = find.byKey(const ValueKey('detail-note-date'));

    // Künye zemini güvenli alanı da kapsar: yukarı kaydırırken ekranın
    // tepesinde kopuk bir kuşak kalmaz.
    expect(tester.getTopLeft(chrome).dy, 0);
    expect(tester.getSize(chrome).height, topSafeInset + 56);

    // Tarih tam ekran ekseninde; soldaki tek düğme onu optik olarak itmez.
    expect(tester.getCenter(dateStamp).dx, closeTo(logicalSize.width / 2, 0.5));
    expect(
      tester.getBottomLeft(dateStamp).dy,
      lessThan(tester.getTopLeft(photoStage).dy),
    );

    // Baskı ve yazı tek bir hatta oturur; ana akıştaki kartın marjıyla aynı.
    expect(tester.getTopLeft(photoStage).dx, kDetailMargin);
    expect(tester.getSize(photoStage).width, logicalSize.width - 32);
    expect(tester.getTopLeft(photoStage).dy, topSafeInset + 72);
    expect(tester.getTopLeft(noteCopy).dx, kDetailMargin);
    expect(
      tester.getTopLeft(noteCopy).dy - tester.getBottomLeft(photoStage).dy,
      inInclusiveRange(24, 28),
    );
    expect(tester.widget<Text>(noteCopy).style?.color, palette.ink);

    // Süresiz kayıtta künye sessiz: çizecek bir ömür yoksa çizgi de yok.
    expect(find.byKey(const ValueKey('detail-life-edge')), findsNothing);

    final restingPhotoHeight = tester.getSize(photoStage).height;
    final restingPhotoWidth = tester.getSize(photoStage).width;

    // Düzenlemeye ayrı bir düğmeden değil, okunan satırın kendisinden girilir.
    await tester.tap(noteCopy);
    await _settle(tester);

    expect(find.byType(EditNoteSheet), findsOneWidget);
    expect(find.byType(DetailSheet), findsNothing);
    final editSurface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('edit-note-sheet-surface')),
    );
    expect(editSurface.color, palette.canvas);
    expect(find.text('NOTU DÜZENLE'), findsNothing);
    final editField = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-note-body-field')),
    );
    expect(editField.keyboardAppearance, Brightness.light);
    expect(editField.style?.color, palette.ink);
    expect(find.text('VAZGEÇ'), findsOneWidget);
    expect(find.text('KAYDET'), findsOneWidget);

    final cancelCenter = tester.getCenter(
      find.byKey(const ValueKey('edit-action-cancel')),
    );
    final saveCenter = tester.getCenter(
      find.byKey(const ValueKey('edit-action-save')),
    );
    expect(cancelCenter.dy, saveCenter.dy);
    expect(cancelCenter.dx, lessThan(saveCenter.dx));
    final editRail = find.byKey(const ValueKey('edit-action-rail'));
    expect(tester.getBottomRight(editRail).dy, logicalSize.height);
    expect(logicalSize.height - saveCenter.dy, lessThan(90));
    expect(logicalSize.height - saveCenter.dy, greaterThan(bottomSafeInset));
    expect(saveCenter.dy, greaterThan(logicalSize.height / 2));
    final pullRegion = find.byKey(const ValueKey('edit-pull-down-region'));
    expect(pullRegion, findsOneWidget);
    expect(
      tester.getCenter(pullRegion).dy,
      greaterThan(logicalSize.height / 2),
    );
    expect(tester.getCenter(pullRegion).dy, lessThan(saveCenter.dy));

    // Yazarken baskı küçülür ama oranını korur: kırpılmaz, letterbox taşımaz.
    expect(tester.getSize(photoStage).height, lessThan(restingPhotoHeight));
    expect(tester.getSize(photoStage).width, lessThan(restingPhotoWidth));
    expect(
      tester.getSize(photoStage).width / tester.getSize(photoStage).height,
      closeTo(restingPhotoWidth / restingPhotoHeight, 0.01),
    );
    expect(tester.getTopLeft(photoStage).dy, topSafeInset + 18);
    expect(tester.getSize(chrome).height, topSafeInset + 14);
    // Yazarken sayfa eylemleri çekilir; yerini kaydet/vazgeç rayı alır.
    expect(find.byKey(const ValueKey('detail-action-bar')), findsOneWidget);

    await tester.tap(find.text('VAZGEÇ'));
    await _settle(tester);
    expect(find.byType(DetailSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('kareye dokunmak onu tam ekrana çıkarır ve geri getirir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final image = File('${sandbox.path}/viewer-detail.png');
      await image.writeAsBytes(_pixel);
      await repository.create(
        capture: XFile(image.path),
        body: 'Tam ekran notu',
        retention: const RetentionChoice.off(),
      );
    });

    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await _settle(tester);
    await tester.tap(find.byType(NoteCard));
    await _settle(tester);

    expect(find.byType(NoteDetailPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-photo-stage')));
    await _settle(tester);

    // Görüntüleyici kendi rotasında açılır; detay altında canlı kalır.
    final close = find.byIcon(Icons.close_rounded);
    expect(close, findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(NoteDetailPage), findsOneWidget);

    await tester.tap(close);
    await _settle(tester);

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byKey(const ValueKey('detail-note-copy')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dar ekranda uzun not sayfanın doğal akışında okunur', (
    tester,
  ) async {
    const logicalSize = Size(280, 568);
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final note = Note(
      id: 1,
      imageName: 'unused.png',
      body: List.filled(
        28,
        'Uzun not satırı, önemli ayrıntılar ve takip edilecek maddeler.',
      ).join(' '),
      createdAt: DateTime(2026, 8, 8, 14, 30),
      retention: Retention.off,
      customMinutes: 0,
      remindEveryDays: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('tr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DetailSheet(
              note: note,
              entrance: const AlwaysStoppedAnimation<double>(1),
              onEdit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final sheet = find.byType(DetailSheet);
    expect(
      tester.getSize(sheet).height,
      greaterThan(logicalSize.height),
    );
    // Panel kendi içinde kaydırmaz; sayfanın akışına katılır.
    expect(
      find.descendant(of: sheet, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('paylaşma beklerken adı nefes alır, çark belirmez', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 300);
    addTearDown(tester.view.reset);

    Future<void> pumpBar({required bool sharing}) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('tr'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              DetailActionBar(
                reveal: const AlwaysStoppedAnimation<double>(1),
                onDelete: () {},
                onEdit: () {},
                onShare: () {},
                sharing: sharing,
              ),
            ],
          ),
        ),
      ),
    );

    double opacityOf(String key) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    await pumpBar(sharing: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(opacityOf('detail-action-share'), 1.0);

    await pumpBar(sharing: true);
    await tester.pump();
    // Sistem paylaşım sayfası beklenirken şeritte Material çarkı yok; bekleme
    // kelimenin kendisinden okunuyor.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 550));
    expect(opacityOf('detail-action-share'), lessThan(1.0));
    // Yalnızca bekleyen kelime nefes alıyor; şeridin geri kalanı sabit.
    expect(opacityOf('detail-action-delete'), 1.0);
    expect(opacityOf('detail-action-edit'), 1.0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}
