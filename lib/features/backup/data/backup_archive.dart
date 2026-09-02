import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/backup_manifest.dart';
import '../domain/backup_status.dart';
import 'backup_codec.dart';
import 'backup_crypto.dart';

/// Şifreli kabın **içine** ne konduğu.
///
/// Yük şöyle dizili:
///
/// ```
/// u32           manifest uzunluğu
/// JSON          manifest — sayımlar, tercihler, giriş tablosu
/// notes.json    notların tamamı
/// photos/...    kareler, manifestteki sırayla
/// ```
///
/// Manifestin **başta** olması bir gereklilik: geri yükleme önizlemesi ("20
/// not, 20 fotoğraf bulundu") yüzlerce megabaytı çözmeden cevap verebilsin
/// diye yalnızca ilk parçalar açılıyor.
abstract final class BackupArchive {
  static const notesEntryName = 'notes.json';
  static const photoPrefix = 'photos/';
  static const maxManifestLength = 16 * 1024 * 1024;

  /// Yedeği yazar. Kareler diskten **iki kez** okunuyor: bir kez özet için,
  /// bir kez şifrelemek için.
  ///
  /// İkinci okumadan kaçınmak için her şeyi belleğe almak gerekirdi; yüzlerce
  /// megabaytlık bir arşivde bu, uygulamayı işletim sistemine öldürtür. Ardışık
  /// okuma ucuz, bellek değil.
  static Future<void> write({
    required File destination,
    required String password,
    required List<BackupNote> notes,
    required BackupSettings settings,
    required Map<String, File> photos,
    required String appVersion,
    required int schemaVersion,
    required DateTime createdAt,
    void Function(BackupProgress) onProgress = _ignore,
  }) async {
    onProgress(const BackupProgress(phase: BackupPhase.preparing));

    final notesBytes = Uint8List.fromList(
      utf8.encode(jsonEncode([for (final note in notes) note.toJson()])),
    );

    final entries = <BackupEntry>[
      BackupEntry(
        name: notesEntryName,
        length: notesBytes.length,
        sha256: await _digestOfBytes(notesBytes),
      ),
    ];

    var index = 0;
    for (final entry in photos.entries) {
      final file = entry.value;
      if (!file.existsSync()) continue;
      entries.add(
        BackupEntry(
          name: '$photoPrefix${entry.key}',
          length: await file.length(),
          sha256: await _digestOfFile(file),
        ),
      );
      index++;
      onProgress(
        BackupProgress(
          phase: BackupPhase.preparing,
          itemsDone: index,
          itemsTotal: photos.length,
        ),
      );
    }

    final manifest = BackupManifest(
      createdAt: createdAt,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      noteCount: notes.length,
      photoCount: entries.length - 1,
      settings: settings,
      entries: entries,
    );
    final manifestBytes = manifest.encode();

    final payloadLength =
        4 +
        manifestBytes.length +
        entries.fold<int>(0, (sum, entry) => sum + entry.length);

    onProgress(const BackupProgress(phase: BackupPhase.derivingKey));
    final salt = BackupCrypto.randomBytes(BackupCrypto.saltLength);
    final key = await BackupCrypto.deriveKey(
      password: password,
      salt: salt,
      memoryKib: BackupCrypto.argonMemoryKib,
      iterations: BackupCrypto.argonIterations,
      parallelism: BackupCrypto.argonParallelism,
    );

    final writer = await BackupWriter.open(
      destination: destination,
      key: key,
      salt: salt,
      noncePrefix: BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength),
      payloadLength: payloadLength,
    );

    try {
      var written = 0;
      void advance(int bytes, int itemsDone) {
        written += bytes;
        onProgress(
          BackupProgress(
            phase: BackupPhase.writing,
            processed: written,
            total: payloadLength,
            itemsDone: itemsDone,
            itemsTotal: entries.length,
          ),
        );
      }

      await writer.add(_u32(manifestBytes.length));
      await writer.add(manifestBytes);
      advance(4 + manifestBytes.length, 0);

      await writer.add(notesBytes);
      advance(notesBytes.length, 1);

      var done = 1;
      for (final entry in entries.skip(1)) {
        final name = entry.name.substring(photoPrefix.length);
        final file = photos[name]!;
        await for (final block in file.openRead()) {
          await writer.add(block);
          written += block.length;
        }
        done++;
        advance(0, done);
      }

      await writer.finish();
    } catch (error) {
      await writer.abort();
      if (destination.existsSync()) {
        try {
          await destination.delete();
        } on FileSystemException {
          // Yarım dosyayı silemedik; en azından hatayı yukarı taşıyoruz.
        }
      }
      rethrow;
    }
  }

  /// Yalnızca manifesti çözer — önizleme için.
  ///
  /// Koca dosyayı açmadan duruyor: kullanıcı parolayı doğru girdiğinde ne
  /// bulduğunu saniyeler içinde görmeli, gigabaytı beklemeden.
  static Future<BackupManifest> readManifest({
    required File source,
    required SecretKey key,
    required BackupPrologue prologue,
  }) async {
    final reader = await BackupReader.open(
      file: source,
      prologue: prologue,
      key: key,
    );
    try {
      final buffer = BytesBuilder(copy: false);
      int? manifestLength;

      while (reader.hasMore) {
        buffer.add(await reader.next());
        final bytes = buffer.toBytes();
        manifestLength ??= bytes.length >= 4
            ? ByteData.sublistView(bytes).getUint32(0, Endian.big)
            : null;
        if (manifestLength != null) {
          _validateManifestLength(
            manifestLength,
            prologue.header.payloadLength,
          );
        }
        if (manifestLength != null && bytes.length >= 4 + manifestLength) {
          final manifest = _decodeManifest(
            Uint8List.sublistView(bytes, 4, 4 + manifestLength),
          );
          _validateManifest(
            manifest,
            manifestLength: manifestLength,
            payloadLength: prologue.header.payloadLength,
          );
          return manifest;
        }
      }
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Manifest tamamlanmadan dosya bitti',
      );
    } finally {
      await reader.close();
    }
  }

  /// Yükün tamamını [staging] altına çözer ve her girişin özetini doğrular.
  ///
  /// Kareler `staging/photos/` altına, notlar bellekte dönüyor. Hiçbir şey
  /// yerine konmuyor — bu adım bittiğinde mevcut veri hâlâ el değmemiş
  /// durumda. Yerine koyma ayrı ve son adım.
  static Future<BackupExtraction> extract({
    required File source,
    required SecretKey key,
    required BackupPrologue prologue,
    required Directory staging,
    void Function(BackupProgress) onProgress = _ignore,
  }) async {
    final photoDir = Directory('${staging.path}/photos');
    await photoDir.create(recursive: true);

    final reader = await BackupReader.open(
      file: source,
      prologue: prologue,
      key: key,
    );

    final pending = BytesBuilder(copy: false);
    Uint8List buffered = Uint8List(0);
    var offset = 0;
    var consumed = 0;
    final total = prologue.header.payloadLength;

    Future<void> fill(int need) async {
      while (buffered.length - offset < need && reader.hasMore) {
        pending
          ..add(Uint8List.sublistView(buffered, offset))
          ..add(await reader.next());
        buffered = pending.takeBytes();
        offset = 0;
      }
      if (buffered.length - offset < need) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Dosya beklenenden kısa',
        );
      }
    }

    try {
      await fill(4);
      final manifestLength = ByteData.sublistView(
        buffered,
        offset,
      ).getUint32(0, Endian.big);
      offset += 4;
      consumed += 4;

      _validateManifestLength(manifestLength, total);
      await fill(manifestLength);
      final manifest = _decodeManifest(
        Uint8List.sublistView(buffered, offset, offset + manifestLength),
      );
      _validateManifest(
        manifest,
        manifestLength: manifestLength,
        payloadLength: total,
      );
      offset += manifestLength;
      consumed += manifestLength;

      Uint8List? notesBytes;
      var done = 0;

      for (final entry in manifest.entries) {
        final isNotes = entry.name == notesEntryName;
        final sink = isNotes
            ? null
            : File(
                '${photoDir.path}/${entry.name.substring(photoPrefix.length)}',
              ).openWrite();
        final collected = isNotes ? BytesBuilder(copy: false) : null;
        final digest = _IncrementalDigest();

        var remaining = entry.length;
        while (remaining > 0) {
          if (buffered.length - offset == 0) await fill(1);
          final take = remaining < buffered.length - offset
              ? remaining
              : buffered.length - offset;
          final slice = Uint8List.sublistView(buffered, offset, offset + take);
          digest.add(slice);
          if (sink != null) {
            sink.add(slice);
          } else {
            collected!.add(slice);
          }
          offset += take;
          remaining -= take;
          consumed += take;

          onProgress(
            BackupProgress(
              phase: BackupPhase.reading,
              processed: consumed,
              total: total,
              itemsDone: done,
              itemsTotal: manifest.entries.length,
            ),
          );
        }

        if (sink != null) {
          await sink.flush();
          await sink.close();
        } else {
          notesBytes = collected!.takeBytes();
        }

        // Özet AEAD'nin yedeği değil — kendi bölme hesabımızın sınavı. Doğru
        // çözülmüş ama yanlış bölünmüş baytlar buradan geçemez.
        final actual = await digest.hex();
        if (actual != entry.sha256) {
          throw BackupFailure(
            BackupFailureKind.corrupt,
            '${entry.name} özeti tutmuyor',
          );
        }

        done++;
        onProgress(
          BackupProgress(
            phase: BackupPhase.verifying,
            processed: consumed,
            total: total,
            itemsDone: done,
            itemsTotal: manifest.entries.length,
          ),
        );
      }

      if (notesBytes == null) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Yedekte not listesi yok',
        );
      }

      final List<Object?> decoded;
      try {
        decoded = (jsonDecode(utf8.decode(notesBytes)) as List).cast<Object?>();
      } catch (_) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Not listesi okunamadı',
        );
      }
      if (decoded.length != manifest.noteCount) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Not sayısı manifestle uyuşmuyor',
        );
      }
      if (consumed != total) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Yük uzunluğu manifestle uyuşmuyor',
        );
      }

      final List<BackupNote> notes;
      try {
        notes = [
          for (final item in decoded)
            BackupNote.fromJson((item as Map).cast<String, Object?>()),
        ];
      } catch (_) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Not alanları geçersiz',
        );
      }
      final imageNames = <String>{};
      for (final note in notes) {
        // Karesiz kayıtta `image` boş string. Dosya adı denetimi ve teklik
        // denetimi ona uygulanamaz: boş ad geçerli bir dosya adı değil (ve
        // olmamalı), üstelik birden çok karesiz kayıt aynı boş adı taşır.
        // İkisi de yalnız gerçek dosya adlarına sorulur.
        // Saklanan orijinal de arşivde kendi girişi olarak duruyor ve o da
        // kayıtlı sayılmalı — yoksa aşağıdaki döngü onu "kayıtsız fotoğraf"
        // sanıp bütün dosyayı reddediyor. Kullanıcı açısından bu, sağlam bir
        // yedeğin "bozuk" görünmesi demek.
        final named = note.imageName.isNotEmpty;
        final original = note.originalName;
        if ((named && !_isSafeFileName(note.imageName)) ||
            (named && !imageNames.add(note.imageName)) ||
            (original != null &&
                (!_isSafeFileName(original) || !imageNames.add(original))) ||
            note.customMinutes < 0 ||
            note.remindEveryDays < 0 ||
            note.remindEveryDays > 36500 ||
            note.legacyRemindAfterDays < 0 ||
            note.legacyRemindAfterDays > 36500 ||
            (note.latitude != null &&
                (note.latitude! < -90 || note.latitude! > 90)) ||
            (note.longitude != null &&
                (note.longitude! < -180 || note.longitude! > 180))) {
          throw const BackupFailure(
            BackupFailureKind.corrupt,
            'Not içeriği geçersiz',
          );
        }
      }
      for (final entry in manifest.entries.skip(1)) {
        final name = entry.name.substring(photoPrefix.length);
        if (!imageNames.contains(name)) {
          throw const BackupFailure(
            BackupFailureKind.corrupt,
            'Kayıtsız fotoğraf girişi',
          );
        }
      }
      return BackupExtraction(
        manifest: manifest,
        notes: notes,
        photos: photoDir,
      );
    } finally {
      await reader.close();
    }
  }

  static void _ignore(BackupProgress _) {}

  static BackupManifest _decodeManifest(Uint8List bytes) {
    try {
      return BackupManifest.decode(bytes);
    } catch (_) {
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Manifest okunamadı',
      );
    }
  }

  static void _validateManifestLength(int length, int payloadLength) {
    if (length <= 0 ||
        length > maxManifestLength ||
        length > payloadLength - 4) {
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Manifest uzunluğu geçersiz',
      );
    }
  }

  static void _validateManifest(
    BackupManifest manifest, {
    required int manifestLength,
    required int payloadLength,
  }) {
    final entries = manifest.entries;
    if (manifest.noteCount < 0 ||
        manifest.photoCount < 0 ||
        entries.isEmpty ||
        entries.first.name != notesEntryName ||
        entries.where((entry) => entry.name == notesEntryName).length != 1 ||
        manifest.photoCount != entries.length - 1) {
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Manifest girişleri tutarsız',
      );
    }

    final names = <String>{};
    var entryBytes = 0;
    final digestPattern = RegExp(r'^[0-9a-f]{64}$');
    for (final entry in entries) {
      if (!names.add(entry.name) ||
          entry.length < 0 ||
          !digestPattern.hasMatch(entry.sha256)) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Geçersiz veya yinelenen giriş',
        );
      }
      entryBytes += entry.length;
      if (entry.name == notesEntryName) continue;

      if (!entry.name.startsWith(photoPrefix)) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Bilinmeyen yedek girişi',
        );
      }
      final name = entry.name.substring(photoPrefix.length);
      if (!_isSafeFileName(name)) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Geçersiz fotoğraf adı',
        );
      }
    }

    if (4 + manifestLength + entryBytes != payloadLength) {
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Manifest yük uzunluğuyla uyuşmuyor',
      );
    }
  }

  static bool _isSafeFileName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains(r'\') &&
      !name.contains('\u0000');

  static Future<String> _digestOfBytes(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    return _hex(digest.bytes);
  }

  static Future<String> _digestOfFile(File file) async {
    final digest = _IncrementalDigest();
    await for (final block in file.openRead()) {
      digest.add(block);
    }
    return digest.hex();
  }

  static String _hex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final class BackupExtraction {
  const BackupExtraction({
    required this.manifest,
    required this.notes,
    required this.photos,
  });

  final BackupManifest manifest;
  final List<BackupNote> notes;
  final Directory photos;
}

/// Akış hâlinde SHA-256.
///
/// `cryptography` paketinin sink API'si parça parça besleme için var; tüm
/// dosyayı belleğe alıp özetlemek yüzlerce megabaytlık bir karede uygulamayı
/// düşürürdü.
final class _IncrementalDigest {
  final _sink = Sha256().newHashSink();

  void add(List<int> bytes) => _sink.add(bytes);

  Future<String> hex() async {
    _sink.close();
    final hash = await _sink.hash();
    return BackupArchive._hex(hash.bytes);
  }
}

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big);
