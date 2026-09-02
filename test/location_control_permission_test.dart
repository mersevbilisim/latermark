import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/app/app_scope.dart';
import 'package:latermark/core/theme/app_theme.dart';
import 'package:latermark/features/notes/data/location_service.dart';
import 'package:latermark/features/notes/data/notes_database.dart';
import 'package:latermark/features/notes/data/notes_repository.dart';
import 'package:latermark/features/notes/data/photo_store.dart';
import 'package:latermark/features/notes/presentation/widgets/location_control.dart';
import 'package:latermark/features/notes/presentation/widgets/note_option_label.dart';
import 'package:latermark/shared/widgets/ember_switch.dart';
import 'package:latermark/features/settings/data/settings_repository.dart';
import 'package:latermark/l10n/app_localizations.dart';

void main() {
  late Directory sandbox;
  late NotesDatabase database;
  late NotesRepository notes;
  late SettingsRepository settings;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('lm_location_control');
    database = NotesDatabase.forExecutor(NativeDatabase.memory());
    notes = NotesRepository(
      database: database,
      photos: await PhotoStore.openIn(sandbox),
    );
    settings = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  testWidgets('izin yoksa kayıtlı açık tercih ekranda açık kalmaz', (
    tester,
  ) async {
    await settings.setLocationEnabled(true);
    final location = _FakeLocationService(
      permission: false,
      permissionAfterRequest: true,
      fix: const NoteLocation(latitude: 41.0082, longitude: 28.9784),
    );
    NoteLocation? resolved;

    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        location: location,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: _LocationHarness(
              initialEnabled: true,
              settings: settings,
              onResolved: (value) => resolved = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const ValueKey('compose-location-switch')))
          .value,
      isFalse,
    );
    expect(location.permissionRequests, 0);
    expect((await settings.read()).locationEnabled, isFalse);
    expect(find.byKey(const ValueKey('compose-location-blocked')), findsOne);

    // Kullanıcı açıkça açtığında izin istenir; olumlu sonuçtan sonra hem
    // anahtar hem koordinat hem de kalıcı tercih birlikte etkinleşir.
    await tester.tap(find.byKey(const ValueKey('compose-location-switch')));
    await tester.pumpAndSettle();

    expect(location.permissionRequests, 1);
    expect(
      tester
          .widget<EmberSwitch>(find.byKey(const ValueKey('compose-location-switch')))
          .value,
      isTrue,
    );
    expect(resolved, const NoteLocation(latitude: 41.0082, longitude: 28.9784));
    expect((await settings.read()).locationEnabled, isTrue);
    expect(find.text('Konum bu kare için hazır.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  /// İzin istemi ve konum sabitlemesi anlık değil. Metnin değişmesi tek başına
  /// "çalışıyor" demiyordu; satırın kendi işareti dönüyor.
  testWidgets('konum çözülürken satır bekleme gösteriyor', (tester) async {
    final location = _FakeLocationService(
      permission: true,
      permissionAfterRequest: true,
      fix: const NoteLocation(latitude: 41.0082, longitude: 28.9784),
      holdFix: true,
    );

    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        location: location,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: _LocationHarness(
              initialEnabled: false,
              settings: settings,
              onResolved: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    NoteOptionLabel label() =>
        tester.widget<NoteOptionLabel>(find.byType(NoteOptionLabel));
    expect(label().busy, isFalse);

    await tester.tap(find.byKey(const ValueKey('compose-location-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(label().busy, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Gösterge sonsuz döndüğü için `pumpAndSettle` burada asla oturmaz.
    location.releaseFix();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(label().busy, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Ağaç sökülmezse Drift akışının timer'ı askıda kalıyor.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });


  /// İzin verildi ama sabitleme gelmedi. Anahtarı açık bırakmak kaydın konumlu
  /// olduğunu söylemek olurdu; oysa koordinat yok.
  testWidgets('sabitleme gelmezse anahtar açık kalmıyor', (tester) async {
    final location = _FakeLocationService(
      permission: true,
      permissionAfterRequest: true,
      // İzin var, konum yok: kapalı mekânda zaman aşımının hâli.
      fix: null,
    );

    await tester.pumpWidget(
      AppScope(
        notes: notes,
        settings: settings,
        location: location,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: _LocationHarness(
              initialEnabled: false,
              settings: settings,
              onResolved: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('compose-location-switch')));
    await tester.pumpAndSettle();

    // Anahtar gerçeği gösteriyor.
    expect(
      tester
          .widget<EmberSwitch>(
            find.byKey(const ValueKey('compose-location-switch')),
          )
          .value,
      isFalse,
    );
    // Ve sebebini söylüyor — izin uyarısı değil, sabitleme uyarısı.
    expect(find.byKey(const ValueKey('compose-location-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-location-blocked')), findsNothing);
    expect(find.text('Konum alınamadı'), findsOneWidget);
    // Çözüm Ayarlar değil, yeniden denemek.
    expect(find.byKey(const ValueKey('compose-location-retry')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

}

class _LocationHarness extends StatefulWidget {
  const _LocationHarness({
    required this.initialEnabled,
    required this.settings,
    required this.onResolved,
  });

  final bool initialEnabled;
  final SettingsRepository settings;
  final ValueChanged<NoteLocation?> onResolved;

  @override
  State<_LocationHarness> createState() => _LocationHarnessState();
}

class _LocationHarnessState extends State<_LocationHarness> {
  late bool _enabled = widget.initialEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: LocationControl(
        enabled: _enabled,
        onChanged: (value) {
          setState(() => _enabled = value);
          unawaited(widget.settings.setLocationEnabled(value));
        },
        onResolved: widget.onResolved,
      ),
    );
  }
}

class _FakeLocationService extends LocationService {
  _FakeLocationService({
    required this.permission,
    required this.permissionAfterRequest,
    required this.fix,
    this.holdFix = false,
  });

  bool permission;
  final bool permissionAfterRequest;
  final NoteLocation? fix;
  int permissionRequests = 0;

  /// Sabitleme gerçek hayatta anlık değil; bekleme durumunu sınamak için
  /// burada elle serbest bırakılıyor.
  final bool holdFix;
  Completer<NoteLocation?>? _held;

  void releaseFix() => _held?.complete(fix);

  @override
  bool get supported => true;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<NoteLocation?> current() {
    if (!holdFix) return Future.value(fix);
    return (_held = Completer<NoteLocation?>()).future;
  }
}
