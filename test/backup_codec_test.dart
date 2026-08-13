import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latermark/features/backup/data/backup_codec.dart';
import 'package:latermark/features/backup/data/backup_crypto.dart';
import 'package:latermark/features/backup/domain/backup_status.dart';

/// Kabın sözü tek cümle: parolayı bilmeyen biri için dosya rastgele
/// baytlardan ayırt edilemez, bilen biri için baytı baytına aynı geri gelir.
/// Buradaki testler o cümlenin her yarısını ayrı ayrı zorluyor.
void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('latermark_backup');
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  /// Testlerde Argon2id yerine sabit bir anahtar: KDF'nin kendisi burada
  /// sınanmıyor ve her testte bir saniye yakmanın anlamı yok.
  SecretKey keyFor(String password) => SecretKey(
    Uint8List.fromList(
      List.generate(32, (i) => (password.hashCode + i * 31) & 0xFF),
    ),
  );

  Future<File> writeBackup(
    List<int> payload, {
    SecretKey? key,
    Uint8List? salt,
    Uint8List? noncePrefix,
  }) async {
    final file = File('${sandbox.path}/test.latermark');
    final writer = await BackupWriter.open(
      destination: file,
      key: key ?? keyFor('doğru parola'),
      salt: salt ?? BackupCrypto.randomBytes(BackupCrypto.saltLength),
      noncePrefix:
          noncePrefix ??
          BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength),
      payloadLength: payload.length,
    );
    await writer.add(payload);
    await writer.finish();
    return file;
  }

  Future<Uint8List> readAll(File file, SecretKey key) async {
    final prologue = await BackupReader.readPrologue(file);
    final reader = await BackupReader.open(
      file: file,
      prologue: prologue,
      key: key,
    );
    final out = BytesBuilder(copy: false);
    while (reader.hasMore) {
      out.add(await reader.next());
    }
    await reader.close();
    return out.takeBytes();
  }

  Uint8List noise(int length, [int seed = 7]) {
    final random = Random(seed);
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  group('gidiş-dönüş', () {
    test('küçük yük baytı baytına geri gelir', () async {
      final payload = noise(1234);
      final file = await writeBackup(payload);
      expect(await readAll(file, keyFor('doğru parola')), payload);
    });

    test('parça sınırını aşan yük geri gelir', () async {
      // Üç tam parça + artık: parçalama mantığının asıl sınavı.
      final payload = noise(BackupCodec.chunkSize * 3 + 4321);
      final file = await writeBackup(payload);
      expect(await readAll(file, keyFor('doğru parola')), payload);
    });

    test('tam parça katı olan yük geri gelir', () async {
      final payload = noise(BackupCodec.chunkSize * 2);
      final file = await writeBackup(payload);
      final restored = await readAll(file, keyFor('doğru parola'));
      expect(restored.length, payload.length);
      expect(restored, payload);
    });

    test('boş yük geçerli bir dosya üretir', () async {
      final file = await writeBackup(const []);
      expect(await readAll(file, keyFor('doğru parola')), isEmpty);
    });

    test(
      'parça parça eklemek tek seferde eklemekle aynı sonucu verir',
      () async {
        final payload = noise(BackupCodec.chunkSize + 999);
        final file = File('${sandbox.path}/streamed.latermark');
        final writer = await BackupWriter.open(
          destination: file,
          key: keyFor('doğru parola'),
          salt: BackupCrypto.randomBytes(BackupCrypto.saltLength),
          noncePrefix: BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength),
          payloadLength: payload.length,
        );
        // Düzensiz dilimler: girişler arası sınır ile parça sınırı çakışmıyor.
        var offset = 0;
        for (final size in [1, 4095, 300000, 700000, 111]) {
          final end = min(offset + size, payload.length);
          await writer.add(Uint8List.sublistView(payload, offset, end));
          offset = end;
        }
        if (offset < payload.length) {
          await writer.add(Uint8List.sublistView(payload, offset));
        }
        await writer.finish();

        expect(await readAll(file, keyFor('doğru parola')), payload);
      },
    );

    test('dosya boyutu önceden hesaplanabiliyor', () async {
      final payload = noise(BackupCodec.chunkSize + 7);
      final file = await writeBackup(payload);
      final prologue = await BackupReader.readPrologue(file);
      final headerLength = prologue.payloadOffset - 10;

      expect(
        file.lengthSync(),
        BackupCodec.fileLengthFor(payload.length, headerLength),
      );
    });
  });

  group('gizlilik', () {
    test('düz metin dosyada görünmüyor', () async {
      final secret = 'kombi servis 4521 Ahmet';
      final payload = Uint8List.fromList(secret.codeUnits);
      final file = await writeBackup(payload);

      final raw = await file.readAsBytes();
      expect(
        String.fromCharCodes(raw).contains(secret),
        isFalse,
        reason: 'not metni şifreli dosyada düz görünüyor',
      );
    });

    test('aynı yük iki kez yedeklenince farklı baytlar üretir', () async {
      // Salt ve nonce ön eki her yedekte yeni; aksi hâlde iki dosyayı
      // karşılaştıran biri "içerik değişmemiş" sonucunu çıkarabilirdi.
      final payload = noise(5000);
      final first = await (await writeBackup(payload)).readAsBytes();
      final second = await (await writeBackup(payload)).readAsBytes();
      expect(first, isNot(second));
    });
  });

  group('saldırılar', () {
    test('başlık aşırı KDF belleği isteyemez', () async {
      final file = File('${sandbox.path}/expensive.latermark');
      final writer = await BackupWriter.open(
        destination: file,
        key: keyFor('doğru parola'),
        salt: BackupCrypto.randomBytes(BackupCrypto.saltLength),
        noncePrefix: BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength),
        payloadLength: 1,
        memoryKib: BackupCrypto.maxArgonMemoryKib + 1,
      );
      await writer.add([1]);
      await writer.finish();

      await expectLater(
        BackupReader.readPrologue(file),
        throwsA(
          isA<BackupFailure>().having(
            (error) => error.kind,
            'kind',
            BackupFailureKind.corrupt,
          ),
        ),
      );
    });

    test('yanlış parola doğrulamada düşer', () async {
      final file = await writeBackup(noise(4096));
      expect(
        () => readAll(file, keyFor('yanlış parola')),
        throwsA(
          isA<BackupFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.wrongPassword,
          ),
        ),
      );
    });

    test('gövdede tek bayt değişince doğrulama düşer', () async {
      final file = await writeBackup(noise(4096));
      final bytes = await file.readAsBytes();
      // Son parçanın ortasında bir yer.
      bytes[bytes.length - 40] ^= 0x01;
      await file.writeAsBytes(bytes);

      expect(
        () => readAll(file, keyFor('doğru parola')),
        throwsA(isA<BackupFailure>()),
      );
    });

    test('başlıkta tek bayt değişince doğrulama düşer', () async {
      // Başlığın AAD olmasının asıl sınavı: düz metin olduğu için okunabilir,
      // ama değiştirilemez olmalı.
      final file = await writeBackup(noise(4096));
      final bytes = await file.readAsBytes();
      final prologue = await BackupReader.readPrologue(file);

      // Salt'ın base64'ü başlığın içinde; oradaki bir karakteri bozalım.
      final headerStart = 10;
      var flipped = false;
      for (var i = headerStart; i < prologue.payloadOffset; i++) {
        // JSON'u ayrıştırılabilir bırakmak için yalnızca base64 gövdesini boz.
        if (bytes[i] >= 0x41 && bytes[i] <= 0x5A) {
          bytes[i] = bytes[i] == 0x41 ? 0x42 : 0x41;
          flipped = true;
          break;
        }
      }
      expect(flipped, isTrue, reason: 'başlıkta bozulacak bayt bulunamadı');
      await file.writeAsBytes(bytes);

      expect(
        () => readAll(file, keyFor('doğru parola')),
        throwsA(isA<BackupFailure>()),
      );
    });

    test('sondan parça kırpmak yakalanıyor', () async {
      // Kırpma saldırısı: dosya sonundan bir parça atılınca kalanlar hâlâ
      // geçerli şifreli metin. Yakalanmasının tek dayanağı başlıktaki parça
      // sayısı — o da AAD'nin içinde olduğu için değiştirilemiyor.
      final payload = noise(BackupCodec.chunkSize * 2 + 10);
      final file = await writeBackup(payload);
      final bytes = await file.readAsBytes();

      // Son parçayı (4 bayt uzunluk + gövde) at.
      final trimmed = Uint8List.sublistView(
        bytes,
        0,
        bytes.length - (10 + BackupCodec.macLength + 4),
      );
      await file.writeAsBytes(trimmed);

      expect(
        () => readAll(file, keyFor('doğru parola')),
        throwsA(
          isA<BackupFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.corrupt,
          ),
        ),
      );
    });

    test('parçaların yerini değiştirmek yakalanıyor', () async {
      // Her parçanın nonce'u sayacından türüyor; yer değiştiren parça yanlış
      // nonce ile çözülmeye çalışılır ve doğrulama düşer.
      final payload = noise(BackupCodec.chunkSize * 2);
      final salt = BackupCrypto.randomBytes(BackupCrypto.saltLength);
      final prefix = BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength);
      final file = await writeBackup(payload, salt: salt, noncePrefix: prefix);

      final bytes = await file.readAsBytes();
      final prologue = await BackupReader.readPrologue(file);
      final start = prologue.payloadOffset;
      final sealed = BackupCodec.chunkSize + BackupCodec.macLength;

      final first = Uint8List.sublistView(bytes, start, start + 4 + sealed);
      final second = Uint8List.sublistView(
        bytes,
        start + 4 + sealed,
        start + 2 * (4 + sealed),
      );
      final swapped = BytesBuilder(copy: false)
        ..add(Uint8List.sublistView(bytes, 0, start))
        ..add(second)
        ..add(first);
      await file.writeAsBytes(swapped.takeBytes());

      expect(
        () => readAll(file, keyFor('doğru parola')),
        throwsA(isA<BackupFailure>()),
      );
    });

    test('Latermark yedeği olmayan dosya parola sorulmadan eleniyor', () async {
      final file = File('${sandbox.path}/random.bin');
      await file.writeAsBytes(noise(4096));

      expect(
        () => BackupReader.readPrologue(file),
        throwsA(
          isA<BackupFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.notABackup,
          ),
        ),
      );
    });

    test('çok kısa dosya yedek sayılmıyor', () async {
      final file = File('${sandbox.path}/tiny.bin');
      await file.writeAsBytes([1, 2, 3]);

      expect(
        () => BackupReader.readPrologue(file),
        throwsA(
          isA<BackupFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.notABackup,
          ),
        ),
      );
    });
  });

  group('nonce türetme', () {
    test('sayaç arttıkça nonce değişiyor, ön ek sabit kalıyor', () {
      final prefix = BackupCrypto.randomBytes(BackupCrypto.noncePrefixLength);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final nonce = BackupCrypto.nonceFor(prefix, i);
        expect(nonce.length, BackupCrypto.nonceLength);
        expect(
          Uint8List.sublistView(nonce, 0, BackupCrypto.noncePrefixLength),
          prefix,
        );
        expect(seen.add(nonce.join(',')), isTrue, reason: 'nonce tekrarladı');
      }
    });
  });
}
