import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/presentation/widgets/reminder_field.dart';
import 'package:latermark/l10n/app_localizations.dart';

/// Tekrar kipi artık ikonla ima edilmiyor; tam genişlikteki satır durumunu
/// cümleyle söylüyor. Uzun çeviriler ile büyük yazı ölçeğinin dar telefonda
/// taşmadığı ve satırın tamamının dokunulabilir olduğu ölçülmeli.
void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required Locale locale,
    required int days,
    required bool repeats,
    required double width,
    double textScale = 1,
    bool prominent = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Padding(
            // Compose satıra iki yanda 22 px veriyor.
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ReminderField(
              days: days,
              repeats: repeats,
              prominent: prominent,
              onChanged: (_) {},
              onRepeatsChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tekrar satırı bütün dillerde dar ekrana sığar', (tester) async {
    for (final locale in L10n.supportedLocales) {
      await pumpField(
        tester,
        locale: locale,
        days: 7,
        repeats: true,
        width: 320,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${locale.toLanguageTag()} dilinde satır taştı',
      );
    }
  });

  testWidgets('en dar ekran ve en büyük yazı ölçeği birlikte taşmaz', (
    tester,
  ) async {
    await pumpField(
      tester,
      locale: const Locale('de'),
      days: 30,
      repeats: true,
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('tekrar satırı parmak ölçüsünde bir hedef', (tester) async {
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: false,
      width: 390,
    );

    // Simge yalnızca ipucu; asıl hedef metin ve durumla birlikte tüm satır.
    final box = tester.getRect(
      find.byKey(const Key('reminder-repeat-control')),
    );
    expect(box.width, greaterThanOrEqualTo(44));
    expect(box.height, greaterThanOrEqualTo(44));
  });

  testWidgets('süre sıfırken tekrar açılamaz', (tester) async {
    var repeats = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: ReminderField(
            days: 0,
            repeats: repeats,
            prominent: true,
            onChanged: (_) {},
            onRepeatsChanged: (value) => repeats = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('reminder-repeat-control')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repeats, isFalse);
    expect(find.text('Enter the number of days first.'), findsOneWidget);
  });

  testWidgets('son ek kipe göre değişir', (tester) async {
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: false,
      width: 390,
    );
    expect(find.text('days from now'), findsOneWidget);
    expect(find.text('Reminds once.'), findsOneWidget);

    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: true,
      width: 390,
    );
    expect(find.text('days · repeating'), findsOneWidget);
    expect(find.text('Reminds every 7 days.'), findsOneWidget);

    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 0,
      repeats: false,
      width: 390,
    );
    expect(find.text('days — off'), findsOneWidget);
    expect(find.text('Enter the number of days first.'), findsOneWidget);
  });

  testWidgets('açık tekrar satırı dinamik aralığı doğrudan söyler', (
    tester,
  ) async {
    await pumpField(
      tester,
      locale: const Locale('tr'),
      days: 3,
      repeats: true,
      width: 390,
    );

    expect(find.text('Her 3 günde bir hatırlatılır.'), findsOneWidget);
    expect(find.text('Hatırlatmayı tekrarla'), findsOneWidget);
    expect(find.text('AÇIK'), findsOneWidget);
  });

  testWidgets('tekrar satırının tamamı kipi değiştirir', (tester) async {
    bool? changedTo;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: ReminderField(
            days: 3,
            repeats: false,
            prominent: true,
            onChanged: (_) {},
            onRepeatsChanged: (value) => changedTo = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder-repeat-control')));
    expect(changedTo, isTrue);
  });

  testWidgets('etiket telefon eninde kontrolle sıkışmaz', (tester) async {
    // Kullanıcının gördüğü sorun buydu: "Hatırlat" ve altındaki açıklama, geniş
    // kontrolün yanında üç dört sütuna bölünmüş gibi kırılıyordu.
    await pumpField(
      tester,
      locale: const Locale('en'),
      days: 7,
      repeats: true,
      width: 390,
    );

    final label = tester.getRect(find.text('Remind me'));
    final control = tester.getRect(find.byIcon(Icons.repeat_rounded));

    // Yığılmış yerleşim: kontrol etiketin altında, etiket satırın tamamında.
    expect(control.top, greaterThanOrEqualTo(label.bottom));

    final detail = tester.getRect(
      find.text('Bring this frame back on the day you choose.'),
    );
    // Açıklama en az yarım satır genişliğinde; eskiden ~97 px'e sıkışıyordu.
    expect(detail.width, greaterThan(200));
    expect(tester.takeException(), isNull);
  });
}
