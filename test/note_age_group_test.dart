import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/domain/note_age_group.dart';
import 'package:latermark/features/notes/presentation/home/widgets/home_header.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 3, 31, 12);

  test('yerel takvim ve ay sonu sınırları doğru yaş grubunu verir', () {
    expect(noteAgeGroupOf(DateTime(2026, 3, 31), now: now), NoteAgeGroup.today);
    expect(
      noteAgeGroupOf(DateTime(2026, 3, 30, 23, 59), now: now),
      NoteAgeGroup.yesterday,
    );
    expect(
      noteAgeGroupOf(DateTime(2026, 3, 24), now: now),
      NoteAgeGroup.pastWeek,
    );
    expect(
      noteAgeGroupOf(DateTime(2026, 3, 23, 23, 59), now: now),
      NoteAgeGroup.pastMonth,
    );
    // 31 Mart'ın bir ay öncesi, taşarak Mart'a dönmek yerine Şubat sonudur.
    expect(
      noteAgeGroupOf(DateTime(2026, 2, 28), now: now),
      NoteAgeGroup.pastMonth,
    );
    expect(
      noteAgeGroupOf(DateTime(2026, 2, 27, 23, 59), now: now),
      NoteAgeGroup.pastThreeMonths,
    );
    expect(
      noteAgeGroupOf(DateTime(2025, 12, 31), now: now),
      NoteAgeGroup.pastThreeMonths,
    );
    expect(
      noteAgeGroupOf(DateTime(2025, 12, 30, 23, 59), now: now),
      NoteAgeGroup.pastYear,
    );
    expect(
      noteAgeGroupOf(DateTime(2025, 3, 31), now: now),
      NoteAgeGroup.pastYear,
    );
    expect(
      noteAgeGroupOf(DateTime(2025, 3, 30, 23, 59), now: now),
      NoteAgeGroup.older,
    );
  });

  test('UTC damgaları cihazın yerel takvim gününe çevrilir', () {
    final localNow = DateTime(2026, 8, 8, 0, 15);
    final localStamp = DateTime(2026, 8, 7, 23, 45);

    expect(
      noteAgeGroupOf(localStamp.toUtc(), now: localNow.toUtc()),
      NoteAgeGroup.yesterday,
    );
  });

  test('boş bölümleri atlar ve bölüm içindeki sırayı korur', () {
    final entries = [
      _Entry('bugün-2', DateTime(2026, 3, 31, 11)),
      _Entry('bugün-1', DateTime(2026, 3, 31, 9)),
      _Entry('üç-ay', DateTime(2026, 1, 8)),
      _Entry('eski', DateTime(2024, 1, 1)),
    ];

    final sections = groupNotesByAge(
      entries,
      createdAtOf: (entry) => entry.at,
      now: now,
    );

    expect(sections.map((section) => section.group), [
      NoteAgeGroup.today,
      NoteAgeGroup.pastThreeMonths,
      NoteAgeGroup.older,
    ]);
    expect(sections.first.notes.map((entry) => entry.id), [
      'bugün-2',
      'bugün-1',
    ]);
  });

  test('tarih grubu çevirileri hedef dili doğal biçimde kullanır', () async {
    final tr = await L10n.delegate.load(const Locale('tr'));
    final de = await L10n.delegate.load(const Locale('de'));
    final ja = await L10n.delegate.load(const Locale('ja'));

    expect(tr.dateGroupPastWeek, 'Son 7 gün');
    expect(tr.dateGroupOlder, '1 yıldan eski');
    expect(de.dateGroupOlder, 'Vor mehr als einem Jahr');
    expect(ja.dateGroupPastThreeMonths, '過去3か月');
  });

  testWidgets('editoryal ayraç dar ekranda ve büyük yazıda taşmaz', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 300);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AgeSeparator(label: 'VOR MEHR ALS EINEM JAHR'),
        ),
      ),
    );

    expect(find.text('VOR MEHR ALS EINEM JAHR'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Entry {
  const _Entry(this.id, this.at);

  final String id;
  final DateTime at;
}
