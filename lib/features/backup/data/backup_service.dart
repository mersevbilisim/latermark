import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/backup_manifest.dart';
import '../domain/backup_status.dart';
import 'backup_archive.dart';
import 'backup_codec.dart';
import 'backup_crypto.dart';
import 'backup_repository.dart';

/// Yedekleme ve geri yüklemenin dışa bakan yüzü.
///
/// İş bölümü katı: **veritabanı ana isolate'te, kriptografi arka planda.**
/// Drift bağlantısı taşınamaz, platform kanalları arka plan isolate'inde
/// çalışmaz; buna karşılık Argon2id ve şifreleme saniyeler sürüyor ve ana
/// thread'de dönerlerse arayüz donar. Bu yüzden veriyi ana isolate okuyor,
/// baytları arka plan şifreliyor, sonucu yine ana isolate yerine koyuyor.
class BackupService {
  BackupService(this._repository);

  final BackupRepository _repository;

  static const fileExtension = 'latermark';

  /// Yedek dosyasını üretir ve yolunu döner.
  ///
  /// [onProgress] arka plan isolate'inden geliyor; arayüz bunu doğrudan
  /// çubuğa bağlayabilir.
  Future<CreatedBackup> createBackup({
    required String password,
    required String appVersion,
    required void Function(BackupProgress) onProgress,
  }) async {
    onProgress(const BackupProgress(phase: BackupPhase.preparing));

    // Veritabanı okumaları burada, ana isolate'te.
    final notes = await _repository.exportNotes();
    final settings = await _repository.exportSettings();

    final photos = <String, String>{};
    for (final note in notes) {
      final file = await _repository.photoFile(note.imageName);
      if (file.existsSync()) photos[note.imageName] = file.path;
    }

    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now();
    final name =
        'Latermark-${stamp.year}-${_two(stamp.month)}-${_two(stamp.day)}'
        '-${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}'
        '.$fileExtension';
    final destination = File('${directory.path}/$name');
    if (destination.existsSync()) await destination.delete();

    await _run<void>(
      (port) => _BackupRequest(
        reply: port,
        destinationPath: destination.path,
        password: password,
        notes: [for (final note in notes) note.toJson()],
        settings: settings.toJson(),
        photos: photos,
        appVersion: appVersion,
        schemaVersion: _repository.schemaVersion,
        createdAtMillis: stamp.millisecondsSinceEpoch,
      ),
      _writeEntry,
      onProgress,
    );

    return CreatedBackup(
      file: destination,
      noteCount: notes.length,
      photoCount: photos.length,
    );
  }

  /// Dosyayı okur, parolayı doğrular ve içinde ne olduğunu söyler.
  ///
  /// Türetilmiş anahtar sonuçla birlikte dönüyor: geri yükleme onaylanırsa
  /// Argon2id ikinci kez çalıştırılmasın. Parola zaten bellekte; anahtarı da
  /// tutmak yeni bir risk açmıyor, kullanıcıyı bir saniye daha bekletmek ise
  /// bedavaya alınmış bir maliyet.
  Future<BackupPreview> inspect({
    required File file,
    required String password,
  }) async {
    final prologue = await BackupReader.readPrologue(file);

    final result = await _run<_InspectResult>(
      (port) => _InspectRequest(
        reply: port,
        sourcePath: file.path,
        password: password,
      ),
      _inspectEntry,
      (_) {},
    );

    final manifest = BackupManifest.decode(result.manifestBytes);
    if (manifest.schemaVersion > _repository.schemaVersion) {
      throw const BackupFailure(BackupFailureKind.unsupportedSchema);
    }

    return BackupPreview(
      file: file,
      manifest: manifest,
      keyBytes: result.keyBytes,
      formatVersion: prologue.formatVersion,
    );
  }

  /// Onaylanmış geri yüklemeyi uygular.
  ///
  /// Sıralama bu işin can damarı: her şey önce geçici bir klasöre çözülüp
  /// **özetleri doğrulanıyor**, mevcut veriye ancak ondan sonra dokunuluyor.
  /// Yarıda kalan bir geri yükleme kullanıcının elindekini götürmez.
  Future<void> restore({
    required BackupPreview preview,
    required void Function(BackupProgress) onProgress,
  }) async {
    final temp = await getTemporaryDirectory();
    final staging = Directory(
      '${temp.path}/restore-${DateTime.now().millisecondsSinceEpoch}',
    );
    await staging.create(recursive: true);

    try {
      final result = await _run<_RestoreResult>(
        (port) => _RestoreRequest(
          reply: port,
          sourcePath: preview.file.path,
          keyBytes: preview.keyBytes,
          stagingPath: staging.path,
        ),
        _restoreEntry,
        onProgress,
      );

      onProgress(const BackupProgress(phase: BackupPhase.applying));

      await _repository.replaceAll(
        notes: [
          for (final item in result.notes)
            BackupNote.fromJson(item.cast<String, Object?>()),
        ],
        settings: preview.manifest.settings,
        stagedPhotos: Directory(result.photosPath),
      );

      onProgress(const BackupProgress(phase: BackupPhase.done));
    } finally {
      if (staging.existsSync()) {
        try {
          await staging.delete(recursive: true);
        } on FileSystemException {
          // Geçici klasör; sistem er geç topluyor.
        }
      }
    }
  }

  /// Arka plan isolate'ini kurar, ilerlemeyi aktarır, sonucu döner.
  ///
  /// Hatalar isolate'ten taşınabilir olsun diye [BackupFailure]'a çevrilip
  /// kind + detay olarak geçiriliyor: keyfi bir exception nesnesi port
  /// üzerinden her zaman geçemez.
  static Future<T> _run<T>(
    Object Function(SendPort) buildRequest,
    void Function(Object) entry,
    void Function(BackupProgress) onProgress,
  ) async {
    final receive = ReceivePort();
    final completer = Completer<T>();
    late final Isolate isolate;

    final subscription = receive.listen((message) {
      if (message is BackupProgress) {
        onProgress(message);
      } else if (message is _Failed) {
        if (!completer.isCompleted) {
          completer.completeError(BackupFailure(message.kind, message.detail));
        }
      } else if (!completer.isCompleted) {
        completer.complete(message as T);
      }
    });

    try {
      isolate = await Isolate.spawn(entry, buildRequest(receive.sendPort));
    } catch (error) {
      await subscription.cancel();
      receive.close();
      throw BackupFailure(BackupFailureKind.io, '$error');
    }

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
      receive.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Parola doğrulandıktan sonra elde kalanlar.
final class BackupPreview {
  const BackupPreview({
    required this.file,
    required this.manifest,
    required this.keyBytes,
    required this.formatVersion,
  });

  final File file;
  final BackupManifest manifest;

  /// Türetilmiş içerik anahtarı. Onay gelirse Argon2id yeniden çalışmasın diye.
  final Uint8List keyBytes;

  final int formatVersion;

  /// Önizleme iptal edildiğinde ya da geri yükleme bittiğinde türetilmiş
  /// anahtarın bellekte gereksiz yere kalmasını önler.
  void dispose() => keyBytes.fillRange(0, keyBytes.length, 0);
}

final class CreatedBackup {
  const CreatedBackup({
    required this.file,
    required this.noteCount,
    required this.photoCount,
  });

  final File file;
  final int noteCount;
  final int photoCount;
}

// ---------------------------------------------------------------------------
// Isolate tarafı. Buradaki hiçbir şey platform kanalı kullanamaz.
// ---------------------------------------------------------------------------

final class _BackupRequest {
  const _BackupRequest({
    required this.reply,
    required this.destinationPath,
    required this.password,
    required this.notes,
    required this.settings,
    required this.photos,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAtMillis,
  });

  final SendPort reply;
  final String destinationPath;
  final String password;
  final List<Map<String, Object?>> notes;
  final Map<String, Object?> settings;
  final Map<String, String> photos;
  final String appVersion;
  final int schemaVersion;
  final int createdAtMillis;
}

final class _InspectRequest {
  const _InspectRequest({
    required this.reply,
    required this.sourcePath,
    required this.password,
  });

  final SendPort reply;
  final String sourcePath;
  final String password;
}

final class _InspectResult {
  const _InspectResult(this.manifestBytes, this.keyBytes);

  final Uint8List manifestBytes;
  final Uint8List keyBytes;
}

final class _RestoreRequest {
  const _RestoreRequest({
    required this.reply,
    required this.sourcePath,
    required this.keyBytes,
    required this.stagingPath,
  });

  final SendPort reply;
  final String sourcePath;
  final Uint8List keyBytes;
  final String stagingPath;
}

final class _RestoreResult {
  const _RestoreResult(this.notes, this.photosPath);

  final List<Map<Object?, Object?>> notes;
  final String photosPath;
}

final class _Failed {
  const _Failed(this.kind, this.detail);

  final BackupFailureKind kind;
  final String? detail;
}

Future<void> _guard(SendPort reply, Future<void> Function() body) async {
  try {
    await body();
  } on BackupFailure catch (failure) {
    reply.send(_Failed(failure.kind, failure.detail));
  } catch (error) {
    reply.send(_Failed(BackupFailureKind.io, '$error'));
  }
}

Future<void> _writeEntry(Object message) async {
  final request = message as _BackupRequest;
  await _guard(request.reply, () async {
    await BackupArchive.write(
      destination: File(request.destinationPath),
      password: request.password,
      notes: [for (final item in request.notes) BackupNote.fromJson(item)],
      settings: BackupSettings.fromJson(request.settings),
      photos: {
        for (final entry in request.photos.entries)
          entry.key: File(entry.value),
      },
      appVersion: request.appVersion,
      schemaVersion: request.schemaVersion,
      createdAt: DateTime.fromMillisecondsSinceEpoch(request.createdAtMillis),
      onProgress: request.reply.send,
    );
    request.reply.send(null);
  });
}

Future<void> _inspectEntry(Object message) async {
  final request = message as _InspectRequest;
  await _guard(request.reply, () async {
    final file = File(request.sourcePath);
    final prologue = await BackupReader.readPrologue(file);
    final key = await BackupCrypto.deriveKey(
      password: request.password,
      salt: prologue.header.salt,
      memoryKib: prologue.header.memoryKib,
      iterations: prologue.header.iterations,
      parallelism: prologue.header.parallelism,
    );

    final manifest = await BackupArchive.readManifest(
      source: file,
      key: key,
      prologue: prologue,
    );

    request.reply.send(
      _InspectResult(
        manifest.encode(),
        Uint8List.fromList(await key.extractBytes()),
      ),
    );
  });
}

Future<void> _restoreEntry(Object message) async {
  final request = message as _RestoreRequest;
  await _guard(request.reply, () async {
    final file = File(request.sourcePath);
    final prologue = await BackupReader.readPrologue(file);

    final extraction = await BackupArchive.extract(
      source: file,
      key: SecretKey(request.keyBytes),
      prologue: prologue,
      staging: Directory(request.stagingPath),
      onProgress: request.reply.send,
    );

    request.reply.send(
      _RestoreResult([
        for (final note in extraction.notes) note.toJson(),
      ], extraction.photos.path),
    );
  });
}
