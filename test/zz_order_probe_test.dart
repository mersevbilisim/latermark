import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/app/app.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/home/widgets/note_card.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/features/settings/domain/app_locale.dart';

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
    sandbox = await Directory.systemTemp.createTemp('latermark_order');
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

  String dump(WidgetTester tester, String tag) {
    // `visitChildren` çocuk (boyama) sırasını veriyor; VoiceOver'ın izlediği
    // sıra `traversalOrder`. Ölçüt bu.
    final root = tester
        .binding
        .renderViews
        .single
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    final tree = root.toStringDeep(
      childOrder: DebugSemanticsDumpOrder.traversalOrder,
    );
    debugPrint('##### $tag');
    for (final line in tree.split('\n')) {
      if (line.contains('label:') || line.contains('SemanticsNode#')) {
        debugPrint('@@ ${line.trimRight()}');
      }
    }
    return tree;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('sıra', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      for (final body in ['Otopark P10', 'Fiş']) {
        final file = File('${sandbox.path}/$body.png');
        await file.writeAsBytes(_pixel);
        await repository.create(
          capture: XFile(file.path),
          body: body,
          retention: RetentionChoice(Retention.threeDays),
        );
      }
    });
    await tester.pumpWidget(
      LatermarkApp(notes: repository, settings: settings),
    );
    await settle(tester);
    final home = dump(tester, 'ANA EKRAN');
    expect(
      home.indexOf('label: "Notlar"'),
      lessThan(home.indexOf('label: "Ara"')),
    );

    await tester.tap(find.byType(NoteCard).first);
    await settle(tester);
    final detail = dump(tester, 'DETAY');
    expect(
      detail.indexOf('label: "Geri"'),
      lessThan(detail.indexOf('label: "Otopark P10"')),
    );

    await tester.tap(find.byKey(const ValueKey('detail-action-back')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await settle(tester);
    final settingsTree = dump(tester, 'AYARLAR');
    expect(settingsTree, contains('label: "Tema. Sistem görünümünü izle'));
    expect(
      settingsTree.indexOf('label: "Tema.'),
      lessThan(settingsTree.indexOf('label: "Sistem"')),
    );

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
