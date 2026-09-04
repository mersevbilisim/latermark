import 'dart:async';

import 'package:flutter/material.dart';

import '../features/backup/data/backup_repository.dart';
import '../features/backup/data/backup_service.dart';
import '../features/notes/data/archive_recovery.dart';
import '../features/notes/data/notes_database.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/data/photo_store.dart';
import '../features/review/review_prompt_service.dart';
import '../features/settings/data/settings_repository.dart';
import 'app.dart';

/// Uygulamanın veri yığınına sahip olan kök.
///
/// Tek sebebi onarım. Bozuk bir veritabanı **aynı** [NotesDatabase] nesnesiyle
/// kurtarılamıyor: Drift açılış hatasını önbelleğe alıyor ve o bağlantı, dosya
/// yana alınsa bile ölü kalıyor (ölçüldü). Onarım bu yüzden yığını baştan
/// kurmak zorunda ve bunu yapabilecek tek yer, yığına sahip olan yer.
///
/// Açılış yolu değişmiyor: ilk yığın hâlâ `main()` içinde, ilk kareden önce
/// kuruluyor. Buradaki durum yalnızca onarımdan sonra değişiyor.
class LatermarkBoot extends StatefulWidget {
  const LatermarkBoot({
    super.key,
    required this.photos,
    required this.initialDatabase,
    this.recovery,
    this.openDatabase,
    this.reviewPrompts,
  });

  final PhotoStore photos;

  /// `main()` içinde zaten açılmış olan veritabanı. Onarıma kadar kullanılan.
  final NotesDatabase initialDatabase;

  /// Testlerde veritabanı dosyasının yerini sabitlemek için.
  final ArchiveRecovery? recovery;

  /// Onarımın kuracağı taze veritabanı. Varsayılan gerçek yolu açıyor;
  /// testler `path_provider` olmadan koşabilsin diye bu dikiş var.
  final NotesDatabase Function()? openDatabase;

  final ReviewPromptService? reviewPrompts;

  @override
  State<LatermarkBoot> createState() => _LatermarkBootState();
}

class _LatermarkBootState extends State<LatermarkBoot> {
  late NotesDatabase _database = widget.initialDatabase;
  late _Stack _stack = _Stack.around(_database, widget.photos);
  late final ArchiveRecovery _recovery =
      widget.recovery ?? ArchiveRecovery(photos: widget.photos);

  /// Aynı anda iki onarım koşarsa ikincisi taze veritabanını yana alırdı.
  bool _repairing = false;

  @override
  Widget build(BuildContext context) => LatermarkApp(
    notes: _stack.notes,
    settings: _stack.settings,
    backups: _stack.backups,
    reviewPrompts: widget.reviewPrompts,
    countRecoverableFrames: _countRecoverable,
    onRepairArchive: _repair,
  );

  Future<int> _countRecoverable() async => _recovery.scan().length;

  /// Bozuk arşivi bırakıp taze bir veritabanı kurar ve karelerin kaydını geri
  /// açar. Kurtarılan kare sayısını döner.
  ///
  /// Sıra önemli: **önce** eski bağlantı kapatılıyor, sonra dosya yana
  /// alınıyor, sonra yeni bağlantı açılıyor. Ters sırada taze veritabanı ölü
  /// dosyanın yardımcı dosyalarını devralırdı.
  Future<int> _repair() async {
    if (_repairing) return 0;
    _repairing = true;
    try {
      // Kapanış istisnası onarımı durduramaz: kapatmaya çalıştığımız şey zaten
      // açılamamış olabilir.
      try {
        await _database.close();
      } on Object catch (error) {
        debugPrint('Bozuk veritabanı kapatılamadı: $error');
      }

      final frames = _recovery.scan();
      await _recovery.setAsideDatabase();

      final database = (widget.openDatabase ?? NotesDatabase.new)();
      final stack = _Stack.around(database, widget.photos);
      final adopted = await stack.notes.adoptFrames(frames);

      if (!mounted) {
        await database.close();
        return adopted;
      }
      setState(() {
        _database = database;
        _stack = stack;
      });
      return adopted;
    } finally {
      _repairing = false;
    }
  }
}

/// Tek bir veritabanının çevresindeki depolar. Onarım bunların hepsini birden
/// tazeliyor: biri eskide kalırsa ölü bağlantıyı taşımaya devam eder.
final class _Stack {
  _Stack.around(NotesDatabase database, PhotoStore photos)
    : notes = NotesRepository(database: database, photos: photos),
      settings = SettingsRepository(database),
      backups = BackupService(
        BackupRepository(database: database, photos: photos),
      );

  final NotesRepository notes;
  final SettingsRepository settings;
  final BackupService backups;
}
