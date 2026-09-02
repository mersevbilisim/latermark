// Yedek dosyasının neden açılmadığını söyleyen tanı aracı.
//
// Uygulama bütün başarısızlıkları tek cümleye indiriyor ("Bu dosya bozuk ya
// da eksik"), oysa kod içeride hangi adımda ne olduğunu biliyor. Bu araç o
// ayrıntıyı olduğu gibi yazdırır ve arşivi geri yükleme yapmadan bir klasöre
// çözer — mevcut veriye hiç dokunmadan.
//
//   dart run tool/backup_doctor.dart <yedek.latermark> [cikis-klasoru]
//
// Parola ortam değişkeninden ya da terminalden okunur; komut satırına
// yazılmaz, kabuk geçmişine düşmez.
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:latermark/features/backup/data/backup_archive.dart';
import 'package:latermark/features/backup/data/backup_codec.dart';
import 'package:latermark/features/backup/data/backup_crypto.dart';
import 'package:latermark/features/backup/domain/backup_status.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'kullanım: dart run tool/backup_doctor.dart <yedek.latermark> '
      '[cikis-klasoru]',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('dosya yok: ${file.path}');
    exitCode = 66;
    return;
  }

  final size = await file.length();
  stdout.writeln('dosya   : ${file.path}');
  stdout.writeln('boyut   : $size bayt');

  final password = _readPassword();
  if (password == null || password.isEmpty) {
    stderr.writeln('parola girilmedi');
    exitCode = 64;
    return;
  }

  try {
    final prologue = await BackupReader.readPrologue(file);
    stdout.writeln('biçim   : v${prologue.formatVersion}');
    stdout.writeln('şifre   : ${prologue.header.cipher}');
    stdout.writeln('yük     : ${prologue.header.payloadLength} bayt '
        '(${prologue.payloadOffset} ofsetinden)');

    // Dosyanın gerçek uzunluğu başlığın vaat ettiğini karşılıyor mu? Kesilmiş
    // bir aktarımın en sık belirtisi bu ve başka her hata onun peşinden gelir.
    final expected = prologue.payloadOffset + prologue.header.payloadLength;
    if (size < expected) {
      stdout.writeln(
        'UYARI   : dosya eksik — $expected bayt bekleniyordu, $size var '
        '(${expected - size} bayt kayıp)',
      );
    }

    final key = await BackupCrypto.deriveKey(
      password: password,
      salt: prologue.header.salt,
      memoryKib: prologue.header.memoryKib,
      iterations: prologue.header.iterations,
      parallelism: prologue.header.parallelism,
    );
    stdout.writeln('anahtar : türetildi');

    final manifest = await BackupArchive.readManifest(
      source: file,
      key: key,
      prologue: prologue,
    );
    stdout.writeln('manifest: okundu');
    stdout.writeln('  şema     : ${manifest.schemaVersion}');
    stdout.writeln('  not      : ${manifest.noteCount}');
    stdout.writeln('  fotoğraf : ${manifest.photoCount}');

    final outDir = Directory(
      args.length > 1 ? args[1] : '${file.parent.path}/backup_doctor_out',
    );
    await outDir.create(recursive: true);

    final extraction = await BackupArchive.extract(
      source: file,
      key: key,
      prologue: prologue,
      staging: outDir,
    );
    stdout.writeln('çözüldü : ${extraction.notes.length} not, '
        'kareler → ${extraction.photos.path}');
    stdout.writeln('SONUÇ   : dosya sağlam, geri yüklenebilir');
  } on BackupFailure catch (failure) {
    stdout.writeln('SONUÇ   : başarısız');
    stdout.writeln('  tür    : ${failure.kind.name}');
    stdout.writeln('  ayrıntı: ${failure.detail ?? "(yok)"}');
    exitCode = 1;
  } on SecretBoxAuthenticationError {
    // Parola yanlışsa da, dosya kurcalanmışsa da aynı hata gelir: şifreleme
    // ikisini ayırt etmiyor ve ayırt etmemeli.
    stdout.writeln('SONUÇ   : çözülemedi — parola yanlış ya da dosya bozulmuş');
    exitCode = 1;
  } on Object catch (error, stack) {
    stdout.writeln('SONUÇ   : beklenmeyen hata');
    stdout.writeln('  $error');
    stdout.writeln(stack.toString().split('\n').take(6).join('\n'));
    exitCode = 1;
  }
}

String? _readPassword() {
  final fromEnv = Platform.environment['LATERMARK_BACKUP_PASSWORD'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  stdout.write('parola: ');
  stdin.echoMode = false;
  try {
    return stdin.readLineSync();
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }
}
