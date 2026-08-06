import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'features/notes/data/notes_database.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/photo_store.dart';
import 'features/settings/data/settings_repository.dart';

/// Yalnızca açılış sırası. Ekran ve iş mantığı `app/` ile `features/` altında.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Türkçe ay ve gün adları için tarih verisi.
  await initializeDateFormatting('tr_TR');

  final database = NotesDatabase();
  final notes = NotesRepository(
    database: database,
    photos: await PhotoStore.open(),
  );

  // Açılışta iki temizlik: süresi dolan kayıtlar ve kaydı kalmamış dosyalar.
  await notes.purgeExpired();
  unawaited(notes.sweepOrphanFiles());

  runApp(
    LatermarkApp(notes: notes, settings: SettingsRepository(database)),
  );
}
