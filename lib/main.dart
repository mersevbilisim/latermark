import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/analytics/meta_events_service.dart';
import 'features/notes/data/notes_database.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/notes/data/photo_store.dart';
import 'features/backup/data/backup_repository.dart';
import 'features/backup/data/backup_service.dart';
import 'features/paywall/data/debug_entitlement.dart';
import 'features/review/review_prompt_service.dart';
import 'features/settings/data/settings_repository.dart';

/// Yalnızca açılış sırası. Ekran ve iş mantığı `app/` ile `features/` altında.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Tüm diller için tarih verisi.
  //
  // Tek yerel yüklemek yetmiyor: `flutter_localizations` yalnızca *arayüzün*
  // yereline veri yüklüyor, oysa bildirim ve widget metinleri widget ağacının
  // dışında, elle yüklenmiş bir [L10n] ile biçimleniyor. Orada veri
  // bulunmayan bir yerel `LocaleDataException` atardı.
  await initializeDateFormatting();

  // Geliştirme anahtarı ilk kareden önce okunur; release'de no-op.
  await DebugEntitlement.load();

  final database = NotesDatabase();
  final photos = await PhotoStore.open();
  final notes = NotesRepository(database: database, photos: photos);
  final backups = BackupService(
    BackupRepository(database: database, photos: photos),
  );

  // Açılışta iki temizlik: süresi dolan kayıtlar ve kaydı kalmamış dosyalar.
  await notes.purgeExpired();
  unawaited(notes.sweepOrphanFiles());

  runApp(
    LatermarkApp(
      notes: notes,
      settings: SettingsRepository(database),
      backups: backups,
      reviewPrompts: ReviewPromptService(),
    ),
  );

  // Meta teşhisi: ilk kareden sonra, açılış yolunun dışında. Release'de gövdesi
  // eleniyor. Kurulum ve oturum olayını SDK kendi gönderiyor; burada bir init
  // çağrısı yok.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(MetaEvents.instance.logDiagnostics());
  });
}
