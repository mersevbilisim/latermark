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
          .widget<Switch>(find.byKey(const ValueKey('compose-location-switch')))
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
          .widget<Switch>(find.byKey(const ValueKey('compose-location-switch')))
          .value,
      isTrue,
    );
    expect(resolved, const NoteLocation(latitude: 41.0082, longitude: 28.9784));
    expect((await settings.read()).locationEnabled, isTrue);
    expect(find.text('Konum bu kare için hazır.'), findsOneWidget);

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
  });

  bool permission;
  final bool permissionAfterRequest;
  final NoteLocation? fix;
  int permissionRequests = 0;

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
  Future<NoteLocation?> current() async => fix;
}
