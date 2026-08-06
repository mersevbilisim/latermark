import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/home_widget/home_widget_bridge.dart';
import '../features/notes/data/notes_database.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/reminders/reminder_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';

/// Uygulamanın çalışan parçalarını ağaca taşıyan kapsam.
///
/// Üç arka plan işini de o yönetir:
/// * "otomatik sil" sözünü tutan zamanlayıcı — açılışta, her öne gelişte ve
///   önplandayken dakikada bir süresi dolmuş notları temizler,
/// * ana ekran widget'ını besleyen köprü,
/// * "bir süredir bakmadın" hatırlatıcıları.
///
/// Bu iş için harici bir durum yönetimi paketine gerek yok.
class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.notes,
    required this.settings,
    required this.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final Widget child;

  static NotesRepository of(BuildContext context) => _scope(context).notes;

  static SettingsRepository settingsOf(BuildContext context) =>
      _scope(context).settings;

  /// Yürürlükteki tercihler. Değiştiğinde dinleyen widget yeniden kurulur.
  static AppSettings preferences(BuildContext context) =>
      _scope(context).preferences;

  static _RepositoryScope _scope(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RepositoryScope>();
    assert(scope != null, 'AppScope, widget ağacında bulunamadı.');
    return scope!;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> with WidgetsBindingObserver {
  static const _sweepInterval = Duration(minutes: 1);

  Timer? _timer;
  HomeWidgetBridge? _widgets;
  final _reminders = ReminderService();

  AppSettings _preferences = const AppSettings();
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<List<Note>>? _notesSub;
  List<Note> _notes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSweeping();
    _widgets = HomeWidgetBridge(widget.notes)..start();

    _settingsSub = widget.settings.watch().listen((value) {
      if (!mounted || value == _preferences) return;
      setState(() => _preferences = value);
      unawaited(_reminders.sync(_notes, value));
    });

    // Hatırlatmalar not listesi her değiştiğinde baştan kurulur: yeni kayıt,
    // silme, düzenleme ve otomatik temizlik hepsi buradan geçiyor.
    _notesSub = widget.notes.watchNotes().listen((notes) {
      _notes = notes;
      unawaited(_reminders.sync(notes, _preferences));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_settingsSub?.cancel());
    unawaited(_notesSub?.cancel());
    unawaited(_widgets?.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startSweeping();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _timer?.cancel();
        _timer = null;
    }
  }

  void _startSweeping() {
    _timer?.cancel();
    unawaited(widget.notes.purgeExpired());
    _timer = Timer.periodic(
      _sweepInterval,
      (_) => unawaited(widget.notes.purgeExpired()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RepositoryScope(
      notes: widget.notes,
      settings: widget.settings,
      reminders: _reminders,
      preferences: _preferences,
      child: widget.child,
    );
  }
}

class _RepositoryScope extends InheritedWidget {
  const _RepositoryScope({
    required this.notes,
    required this.settings,
    required this.reminders,
    required this.preferences,
    required super.child,
  });

  final NotesRepository notes;
  final SettingsRepository settings;
  final ReminderService reminders;
  final AppSettings preferences;

  @override
  bool updateShouldNotify(_RepositoryScope old) =>
      old.notes != notes ||
      old.settings != settings ||
      old.preferences != preferences;
}

/// Bildirim izni istemek için servise erişim.
extension ReminderAccess on BuildContext {
  ReminderService get reminders =>
      dependOnInheritedWidgetOfExactType<_RepositoryScope>()!.reminders;
}
