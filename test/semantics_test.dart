import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/domain/retention.dart';
import 'package:latermark/features/notes/presentation/home/widgets/home_header.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_calendar.dart';
import 'package:latermark/features/notes/presentation/widgets/retention_selector.dart';
import 'package:latermark/features/settings/presentation/widgets/settings_pieces.dart';
import 'package:latermark/l10n/app_localizations.dart';
import 'package:latermark/shared/widgets/app_toast.dart';
import 'package:latermark/shared/widgets/choice_rail.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  Widget host(Widget child, {Locale locale = const Locale('tr')}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('seçim rayı her hücrenin durumunu ekran okuyucuya söylüyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        ChoiceRail<String>(
          options: const ['Sistem', 'Açık', 'Koyu'],
          value: 'Koyu',
          labelOf: (option) => option,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Koyu').first),
      isSemantics(
        label: 'Koyu',
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Açık').first),
      isSemantics(
        label: 'Açık',
        isButton: true,
        isSelected: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('seçim rayı kapalıyken hücreler devre dışı okunuyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        ChoiceRail<String>(
          options: const ['Sistem', 'Koyu'],
          value: 'Koyu',
          labelOf: (option) => option,
          onChanged: (_) {},
          enabled: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Koyu').first),
      isSemantics(label: 'Koyu', hasEnabledState: true, isEnabled: false),
    );

    handle.dispose();
  });

  testWidgets('otomatik silme seçenekleri ekran okuyucudan seçilebiliyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    RetentionChoice? picked;
    await tester.pumpWidget(
      host(
        RetentionSelector(
          value: RetentionChoice(Retention.off),
          onChanged: (choice) => picked = choice,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('3 Gün').first),
      isSemantics(isButton: true, isSelected: false, hasTapAction: true),
    );

    // Eylem semantik ağaçtan geçiyor: VoiceOver'ın çift dokunuşuyla aynı yol,
    // dokunma yüzeyinden değil.
    tester.semantics.tap(find.semantics.byLabel('3 Gün').first);
    await tester.pumpAndSettle();
    expect(picked?.retention, Retention.threeDays);

    handle.dispose();
  });

  testWidgets('kapalı zaman bölümü kaç kare sakladığını söylüyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const AgeSeparator(
          label: 'DÜN',
          collapsed: true,
          count: 4,
          onToggle: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sayı ekranda görünüyor; ayracın adında da olmalı.
    expect(find.bySemanticsLabel('DÜN, 4 not'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('açık zaman bölümü sayıyı tekrarlamıyor', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const AgeSeparator(label: 'DÜN', count: 4, onToggle: _noop)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('DÜN'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('bildirim hapı canlı bölge olarak duyuruluyor', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showToast(context, 'Kayıt silindi'),
            child: const Text('bas'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.getSemantics(
        find
            .ancestor(
              of: find.text('Kayıt silindi'),
              matching: find.byType(Semantics),
            )
            .first,
      ),
      isSemantics(isLiveRegion: true),
    );

    handle.dispose();
  });

  testWidgets('ayar adı seçeneklerden önce bağlamıyla okunuyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        SettingsRow(
          title: 'Tema',
          description: 'Sistem görünümünü izle.',
          below: ChoiceRail<String>(
            options: const ['Sistem', 'Karanlık'],
            value: 'Sistem',
            labelOf: (option) => option,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Tema. Sistem görünümünü izle.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('takvim seçili günü ve bugünü ekran okuyucuya söylüyor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final now = DateTime(2026, 8, 8, 10);
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 350,
          child: ReminderCalendar(
            value: DateTime(2026, 8, 10, 11),
            now: now,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('reminder-day-2026-8-10'))),
      isSemantics(
        label: '10 Ağustos 2026',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('reminder-day-2026-8-8'))),
      isSemantics(label: '8 Ağustos 2026', hint: 'Bugün'),
    );
    expect(
      tester.getSize(find.byKey(const Key('reminder-day-2026-8-10'))).height,
      greaterThanOrEqualTo(44),
    );
    handle.dispose();
  });
}

void _noop() {}
