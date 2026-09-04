import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/app/app_routes.dart';
import 'package:latermark/features/backup/presentation/backup_page.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/note_reminder.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/compose/compose_page.dart';
import 'package:latermark/features/notes/presentation/detail/widgets/photo_dismiss_surface.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/notes/presentation/reminder/reminder_schedule_page.dart';
import 'package:latermark/features/paywall/presentation/paywall_page.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';
import 'package:latermark/features/settings/presentation/settings_page.dart';
import 'package:latermark/features/settings/presentation/widgets/settings_pieces.dart';
import 'package:latermark/features/settings/presentation/your_data_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Ekran okuyucunun gördüğü ağacı gezip kural ihlallerini toplar.
///
/// Elle ekran dolaşmak bir kusuru bulur, ötekini kaçırır. Buradaki kurallar
/// VoiceOver ve Voice Control'ün gerçekten takıldığı şeyler:
///
/// 1. Dokunulabilen her öğenin bir adı olmalı — adsız öğe VoiceOver'da
///    "düğme" diye okunur, Voice Control'de hiç söylenemez.
/// 2. Düğme diye okunan her öğe çalıştırılabilmeli — `excludeSemantics`
///    çocuğun dokunma eylemini de siler ve geriye okunan ama çalışmayan bir
///    düğme kalır.
/// 3. Aynı söz iki kez okunmamalı — etiketi hem `Semantics`'e hem içindeki
///    `Text`'e yazmak "Metin yaz, Metin yaz" ürettiriyor.
List<String> auditSemantics(
  WidgetTester tester, {
  bool checkTargetSize = true,
}) {
  final issues = <String>[];
  // Voice Control adla çalışıyor: aynı ekranda iki denetim aynı adı taşırsa
  // "Şuna dokun" komutu hangisini kastettiğini bilemiyor.
  final tappableLabels = <String, int>{};
  // Apple'ın alt sınırı 44×44. Sesle ya da titrek elle kullanan biri için
  // küçük hedefe nişan almak işin kendisi kadar zor.
  const minimumTarget = 44.0;

  bool isAtBoundary(Rect child, Rect parent) {
    const gap = 0.001;
    return child.left - parent.left <= gap ||
        parent.right - child.right <= gap ||
        child.top - parent.top <= gap ||
        parent.bottom - child.bottom <= gap;
  }

  /// Flutter'ın kendi iOS hedef denetimi gibi, kaydırılabilir alanın veya
  /// ekranın kenarında kısmen kırpılmış düğümü ölçme. Düğmenin gerçek boyu
  /// küçülmedi; yalnız o karede görünür parçası küçüldü.
  Size? targetSize(SemanticsNode node) {
    var bounds = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) {
        bounds = MatrixUtils.transformRect(transform, bounds);
      }
      if (current.flagsCollection.hasImplicitScrolling &&
          isAtBoundary(bounds, current.rect)) {
        return null;
      }
      current = current.parent;
    }

    final viewBounds = Offset.zero & tester.view.physicalSize;
    if (isAtBoundary(bounds, viewBounds)) return null;
    return bounds.size / tester.view.devicePixelRatio;
  }

  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    final label = data.label.trim();
    final tappable = data.hasAction(SemanticsAction.tap);
    final flags = data.flagsCollection;

    if (tappable && label.isEmpty && !flags.isTextField && !flags.isImage) {
      issues.add('adsız dokunulabilir öğe (${node.rect})');
    }
    // Devre dışı bir düğmenin eylemi olmaması normal; etkin olanınki değil.
    final disabled = flags.isEnabled == Tristate.isFalse;
    if (flags.isButton && !tappable && !disabled) {
      issues.add('çalıştırılamayan düğme: "$label"');
    }

    // Ayarlanabilir bir denetim (renk kadranı gibi) değerini söylüyor ama
    // adını söylemiyorsa ekran okuyucuda "36 derece" diye tek başına duruyor:
    // neyin derecesi olduğu kayıp.
    final adjustable =
        data.hasAction(SemanticsAction.increase) ||
        data.hasAction(SemanticsAction.decrease);
    if (adjustable && label.isEmpty) {
      issues.add('adsız ayarlanabilir denetim (değer: "${data.value}")');
    }

    final parts = label
        .split('\n')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    for (var i = 0; i < parts.length; i++) {
      for (var j = i + 1; j < parts.length; j++) {
        if (parts[i] == parts[j]) {
          issues.add('iki kez okunuyor: "${parts[i]}"');
        }
      }
    }

    if (tappable && label.isNotEmpty) {
      tappableLabels[label] = (tappableLabels[label] ?? 0) + 1;
      if (checkTargetSize) {
        final size = targetSize(node);
        if (size != null &&
            (size.width + 0.5 < minimumTarget ||
                size.height + 0.5 < minimumTarget)) {
          issues.add(
            'küçük dokunma hedefi: "$label" '
            '(${size.width.round()}×${size.height.round()})',
          );
        }
      }
    }

    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) return ['semantik ağaç yok'];
  walk(root);

  for (final entry in tappableLabels.entries) {
    if (entry.value > 1) {
      issues.add('aynı ekranda ${entry.value} kez aynı ad: "${entry.key}"');
    }
  }
  return issues;
}

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository repository;
  late SettingsRepository settings;

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    PackageInfo.setMockInitialValues(
      appName: 'Latermark',
      packageName: 'com.mersev.latermark',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_audit');
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

  void usePhone(WidgetTester tester) {
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

  Future<int> addNote(
    WidgetTester tester,
    String body, {
    bool keepOriginal = false,
  }) async {
    var id = 0;
    await tester.runAsync(() async {
      final file = File(
        '${sandbox.path}/shot-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixel);
      id = await repository.create(
        capture: XFile(file.path),
        body: body,
        retention: RetentionChoice(Retention.threeDays),
        keepOriginal: keepOriginal,
      );
    });
    return id;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
  }

  void expectClean(
    WidgetTester tester,
    String screen, {
    bool checkTargetSize = true,
  }) {
    final issues = auditSemantics(tester, checkTargetSize: checkTargetSize);
    expect(issues, isEmpty, reason: '$screen: ${issues.join(' | ')}');
  }

  /// Sayfayı sonuna kadar kaydırarak denetler.
  ///
  /// Uzun listeler tembel kuruluyor: ekranın altında kalan satırlar ağaçta
  /// hiç yok ve tek karelik bir denetim onları göremez. Ayarlar en büyük
  /// yazıda 3000 pt'yi aşıyor — kusurun ekranın altında saklanması işten
  /// değil.
  Future<void> sweep(
    WidgetTester tester,
    String screen, {
    Finder? scrollTarget,
  }) async {
    expectClean(tester, '$screen (tepe)');

    final scrollable = scrollTarget ?? find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;

    for (var step = 0; step < 30; step++) {
      final before = tester
          .state<ScrollableState>(scrollable.first)
          .position
          .pixels;
      await tester.drag(scrollable.first, const Offset(0, -400));
      await settle(tester);
      // Bir önceki öğe sabit başlığın altında, sonraki öğe de ekranın altında
      // kısmen kalabilir. Bu karelerde yalnız semantik sözleşmeyi denetle;
      // hedef boyu tepedeki kararlı karede ve tekil ekran testlerinde ölçülür.
      expectClean(tester, '$screen (kaydırma $step)', checkTargetSize: false);
      final after = tester
          .state<ScrollableState>(scrollable.first)
          .position
          .pixels;
      if ((after - before).abs() < 1) break;
    }
  }

  testWidgets('boş ana ekran', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpApp(tester);
    expectClean(tester, 'boş ana ekran');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('dolu akış', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otoparkın P10 katı');
    await pumpApp(tester);
    expectClean(tester, 'dolu akış');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('giriş menüsü açık', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);

    expect(find.bySemanticsLabel('Metin yaz'), findsOneWidget);
    expectClean(tester, 'giriş menüsü');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('detay sayfası', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark', keepOriginal: true);
    await pumpApp(tester);
    await tester.tap(find.byType(NoteCard));
    await settle(tester);
    expectClean(tester, 'detay');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('fotoğraf görüntüleyici', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byType(NoteCard));
    await settle(tester);
    await tester.tap(find.byType(PhotoDismissSurface));
    await settle(tester);
    expectClean(tester, 'görüntüleyici');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('ayarlar', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
    await sweep(tester, 'ayarlar');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('hatırlatma planı', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await settings.setProUnlocked(true);
    await settings.setReminderEnabled(true);
    final id = await addNote(tester, 'Otopark');
    await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          AppRoutes.lift(
            ReminderSchedulePage(
              noteId: id,
              initial: const ReminderChoice.off(),
            ),
          ),
        );
    await settle(tester);
    await sweep(tester, 'hatırlatma planı');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('paywall', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          AppRoutes.lift(
            PaywallPage(price: '₺149,99', onPurchase: () {}, onRestore: () {}),
          ),
        );
    await settle(tester);
    await sweep(tester, 'paywall');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('erişilebilirlik sayfası', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    final row = find.byKey(const Key('settings-accessibility'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
    expect(find.byKey(const Key('accessibility-page')), findsOneWidget);
    await sweep(tester, 'erişilebilirlik');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('verilerin sayfası', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(AppRoutes.lift(const YourDataPage()));
    await settle(tester);
    await sweep(tester, 'verilerin');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('yazma ekranı', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpApp(tester);
    final entry = find.byKey(const ValueKey('invite-action-text'));
    await tester.ensureVisible(entry);
    await settle(tester);
    await tester.tap(entry);
    await settle(tester);
    expect(find.byType(ComposePage), findsOneWidget);
    await sweep(tester, 'yazma');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('detay düzenleme kipi', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byType(NoteCard));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('detail-action-edit')));
    await settle(tester);
    expectClean(tester, 'detay düzenleme');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('seçim kipi', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await addNote(tester, 'Fiş');
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(tester);
    await tester.tap(find.byType(NoteCard).first);
    await settle(tester);
    expectClean(tester, 'seçim kipi');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('arama kipi', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);
    expectClean(tester, 'arama kipi');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('silme onayı', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.longPress(find.byType(NoteCard));
    await settle(tester);
    expectClean(tester, 'silme onayı');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('dil paneli', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    final row = find.text('Dil');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
    await sweep(
      tester,
      'dil paneli',
      scrollTarget: find.byType(Scrollable).last,
    );
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('özel renk paneli', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);

    // Şeridi önce görünür alana getir; tepedeki seçili işareti aramak ekran
    // dışındaki başka bir ikona dokunup paneli hiç açmıyordu.
    final wheel = find.byType(AccentRail);
    await tester.ensureVisible(wheel);
    await settle(tester);
    expectClean(tester, 'özel renk paneli (kapalı)');

    await tester.tap(find.byKey(const ValueKey('app-accent-custom')));
    await settle(tester);
    expectClean(tester, 'özel renk paneli');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('özel süre paneli', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await settings.setProUnlocked(true);
    await addNote(tester, 'Otopark');
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);

    final custom = find.text('Özel');
    await tester.ensureVisible(custom.first);
    await settle(tester);
    await tester.tap(custom.first);
    await settle(tester);
    expectClean(tester, 'özel süre paneli');
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('yedekleme', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(AppRoutes.lift(const BackupPage.create()));
    await settle(tester);
    await sweep(tester, 'yedekleme');
    handle.dispose();
    await disposeTree(tester);
  });
}
