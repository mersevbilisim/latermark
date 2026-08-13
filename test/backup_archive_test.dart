import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/backup/data/backup_archive.dart';
import 'package:latermark/features/backup/data/backup_codec.dart';
import 'package:latermark/features/backup/data/backup_crypto.dart';
import 'package:latermark/features/backup/domain/backup_manifest.dart';
import 'package:latermark/features/backup/domain/backup_status.dart';

/// Arşiv katmanının sınavı: yazılan yedek, hiçbir şey kaybetmeden ve hiçbir
/// baytı kaydırmadan geri açılabilmeli. Parça sınırları girişlerin ortasına
/// denk geldiği için buradaki asıl risk şifreleme değil, **bölme aritmetiği**.
void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_archive');
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  // Argon2id her testte ~1 sn yakardı; parametreleri en aza indiriyoruz.
  // Sınanan şey KDF değil, arşivin kendisi.
  const password = 'çok gizli parola';

  BackupNote note(
    String image, {
    String body = '',
    String? photoText,
    DateTime? createdAt,
  }) => BackupNote(
    imageName: image,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 8, 13, 14, 30),
    retention: 0,
    customMinutes: 0,
    photoText: photoText,
  );

  const settings = BackupSettings(
    themeMode: 1,
    accent: 2,
    density: 0,
    reminderEnabled: true,
    locationEnabled: true,
    defaultRetention: 1,
    defaultCustomMinutes: 0,
    locale: 3,
  );

  Future<File> photo(String name, int size, [int seed = 3]) async {
    final random = Random(seed);
    final file = File('${sandbox.path}/src_$name')
      ..writeAsBytesSync(
        Uint8List.fromList(List.generate(size, (_) => random.nextInt(256))),
      );
    return file;
  }

  Future<File> writeArchive({
    required List<BackupNote> notes,
    required Map<String, File> photos,
    String pass = password,
  }) async {
    final destination = File('${sandbox.path}/out.latermark');
    await BackupArchive.write(
      destination: destination,
      password: pass,
      notes: notes,
      settings: settings,
      photos: photos,
      appVersion: '1.0.1+4',
      schemaVersion: 5,
      createdAt: DateTime(2026, 8, 13, 12),
    );
    return destination;
  }

  Future<BackupExtraction> readArchive(
    File file, {
    String pass = password,
  }) async {
    final prologue = await BackupReader.readPrologue(file);
    final key = await BackupCrypto.deriveKey(
      password: pass,
      salt: prologue.header.salt,
      memoryKib: prologue.header.memoryKib,
      iterations: prologue.header.iterations,
      parallelism: prologue.header.parallelism,
    );
    return BackupArchive.extract(
      source: file,
      key: key,
      prologue: prologue,
      staging: Directory('${sandbox.path}/staging')..createSync(),
    );
  }

  test('notlar, kareler ve tercihler eksiksiz geri geliyor', () async {
    final first = await photo('a.jpg', 40000);
    final second = await photo('b.jpg', 90000, 11);

    final notes = [
      note('a.jpg', body: 'Kombi servis', photoText: 'fatura 4521 tutar'),
      note('b.jpg', body: 'Park yeri B2 🚗'),
    ];

    final file = await writeArchive(
      notes: notes,
      photos: {'a.jpg': first, 'b.jpg': second},
    );
    final restored = await readArchive(file);

    expect(restored.manifest.noteCount, 2);
    expect(restored.manifest.photoCount, 2);
    expect(restored.manifest.schemaVersion, 5);
    expect(restored.manifest.settings.accent, 2);
    expect(restored.manifest.settings.reminderEnabled, isTrue);

    expect(restored.notes.map((n) => n.body), [
      'Kombi servis',
      'Park yeri B2 🚗',
    ]);
    // OCR metni yedeğe giriyor: geri yüklenen cihazda arama ilk günkü gibi
    // çalışmalı, yüzlerce kareyi yeniden taramak gerekmemeli.
    expect(restored.notes.first.photoText, 'fatura 4521 tutar');
    expect(restored.notes.last.photoText, isNull);

    expect(
      File('${restored.photos.path}/a.jpg').readAsBytesSync(),
      first.readAsBytesSync(),
    );
    expect(
      File('${restored.photos.path}/b.jpg').readAsBytesSync(),
      second.readAsBytesSync(),
    );
  });

  test('hatırlatmalar tekrar kipiyle birlikte geri geliyor', () async {
    // Hatırlatma iki yerde yaşıyor: not başına süre/tekrar ve tercihlerdeki
    // ana şalter. Üçü birden taşınmazsa geri yüklenen arşiv sessizce sessiz
    // kalır — kullanıcı bildirim beklerken hiçbir şey gelmez.
    final notes = [
      BackupNote(
        imageName: 'once.jpg',
        body: 'Tek atışlık',
        createdAt: DateTime(2026, 8, 1, 9),
        retention: 0,
        customMinutes: 0,
        remindAfterDays: 7,
      ),
      BackupNote(
        imageName: 'repeat.jpg',
        body: 'Her hafta',
        createdAt: DateTime(2026, 8, 2, 10),
        retention: 3,
        customMinutes: 360,
        expiresAt: DateTime(2026, 9, 1),
        lastSeenAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 11),
        latitude: 41.2607,
        longitude: 29.0421,
        remindAfterDays: 7,
        remindRepeats: true,
        photoText: 'fatura 4521',
      ),
      BackupNote(
        imageName: 'silent.jpg',
        body: 'Hatırlatmasız',
        createdAt: DateTime(2026, 8, 3),
        retention: 0,
        customMinutes: 0,
      ),
    ];

    final file = await writeArchive(notes: notes, photos: const {});
    final restored = await readArchive(file);

    final once = restored.notes[0];
    expect(once.remindAfterDays, 7);
    expect(once.remindRepeats, isFalse);

    final repeating = restored.notes[1];
    expect(repeating.remindAfterDays, 7);
    expect(repeating.remindRepeats, isTrue);
    // Tekrarın anlamlı olması için oluşum anını belirleyen alanların da
    // gelmesi gerekiyor: süre createdAt'ten sayılıyor, bitiş expiresAt'te.
    expect(repeating.createdAt, DateTime(2026, 8, 2, 10));
    expect(repeating.expiresAt, DateTime(2026, 9, 1));
    expect(repeating.retention, 3);
    expect(repeating.customMinutes, 360);
    expect(repeating.lastSeenAt, DateTime(2026, 8, 10));
    expect(repeating.updatedAt, DateTime(2026, 8, 11));
    expect(repeating.latitude, closeTo(41.2607, 1e-9));
    expect(repeating.longitude, closeTo(29.0421, 1e-9));
    expect(repeating.photoText, 'fatura 4521');

    final silent = restored.notes[2];
    expect(silent.remindAfterDays, 0);
    expect(silent.remindRepeats, isFalse);

    // Ana şalter tercihlerden geliyor; kapalıysa hiçbir not bildirim göndermez.
    expect(restored.manifest.settings.reminderEnabled, isTrue);
  });

  test('parça sınırını aşan kareler bölünmeden geri geliyor', () async {
    // Girişler kasten parça sınırına denk gelmiyor: bölme aritmetiğinin sınavı.
    final big = await photo('big.jpg', BackupCodec.chunkSize * 2 + 12345);
    final small = await photo('small.jpg', 777, 5);

    final file = await writeArchive(
      notes: [note('big.jpg'), note('small.jpg')],
      photos: {'big.jpg': big, 'small.jpg': small},
    );
    final restored = await readArchive(file);

    expect(
      File('${restored.photos.path}/big.jpg').readAsBytesSync(),
      big.readAsBytesSync(),
    );
    expect(
      File('${restored.photos.path}/small.jpg').readAsBytesSync(),
      small.readAsBytesSync(),
    );
  });

  test('kaydı olmayan kare yedeğe girmiyor', () async {
    final missing = File('${sandbox.path}/yok.jpg');
    final file = await writeArchive(
      notes: [note('yok.jpg')],
      photos: {'yok.jpg': missing},
    );
    final restored = await readArchive(file);

    expect(restored.manifest.photoCount, 0);
    expect(restored.notes, hasLength(1));
  });

  test('hiç kaydı olmayan arşiv de geçerli', () async {
    final file = await writeArchive(notes: const [], photos: const {});
    final restored = await readArchive(file);

    expect(restored.manifest.noteCount, 0);
    expect(restored.notes, isEmpty);
  });

  test('önizleme tüm dosyayı çözmeden manifesti okuyor', () async {
    final big = await photo('big.jpg', BackupCodec.chunkSize * 3);
    final file = await writeArchive(
      notes: [note('big.jpg', body: 'Büyük kare')],
      photos: {'big.jpg': big},
    );

    final prologue = await BackupReader.readPrologue(file);
    final key = await BackupCrypto.deriveKey(
      password: password,
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

    expect(manifest.noteCount, 1);
    expect(manifest.photoCount, 1);
    expect(manifest.createdAt, DateTime(2026, 8, 13, 12));
  });

  test('yanlış parola çözmeye başlamadan düşüyor', () async {
    final file = await writeArchive(
      notes: [note('a.jpg', body: 'gizli')],
      photos: const {},
    );

    await expectLater(
      readArchive(file, pass: 'yanlış'),
      throwsA(
        isA<BackupFailure>().having(
          (e) => e.kind,
          'kind',
          BackupFailureKind.wrongPassword,
        ),
      ),
    );
  });

  test('ilerleme sonunda tam yüke ulaşıyor', () async {
    final big = await photo('big.jpg', BackupCodec.chunkSize + 5000);
    final seen = <BackupProgress>[];

    final destination = File('${sandbox.path}/progress.latermark');
    await BackupArchive.write(
      destination: destination,
      password: password,
      notes: [note('big.jpg')],
      settings: settings,
      photos: {'big.jpg': big},
      appVersion: '1.0.1+4',
      schemaVersion: 5,
      createdAt: DateTime(2026, 8, 13, 12),
      onProgress: seen.add,
    );

    expect(seen.any((p) => p.phase == BackupPhase.preparing), isTrue);
    expect(seen.any((p) => p.phase == BackupPhase.derivingKey), isTrue);

    final last = seen.lastWhere((p) => p.phase == BackupPhase.writing);
    expect(last.processed, last.total);
    expect(last.fraction, 1.0);
  });

  test('yazma hatasında yarım dosya bırakılmıyor', () async {
    // Var olmayan bir klasöre yazmak açılışta patlar; geriye dosya kalmamalı.
    final destination = File('${sandbox.path}/yok/olmayan/out.latermark');

    await expectLater(
      BackupArchive.write(
        destination: destination,
        password: password,
        notes: const [],
        settings: settings,
        photos: const {},
        appVersion: '1.0.1+4',
        schemaVersion: 5,
        createdAt: DateTime(2026, 8, 13, 12),
      ),
      throwsA(isA<Object>()),
    );
    expect(destination.existsSync(), isFalse);
  });

  test('klasör dışına çıkan fotoğraf adı geri yüklemede reddedilir', () async {
    final source = await photo('source.jpg', 128);
    final file = await writeArchive(
      notes: [note('../escape.jpg')],
      photos: {'../escape.jpg': source},
    );

    await expectLater(
      readArchive(file),
      throwsA(
        isA<BackupFailure>().having(
          (error) => error.kind,
          'kind',
          BackupFailureKind.corrupt,
        ),
      ),
    );
    expect(File('${sandbox.parent.path}/escape.jpg').existsSync(), isFalse);
  });
}
