import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../domain/backup_status.dart';
import 'backup_crypto.dart';

/// `.latermark` kabının okunması ve yazılması.
///
/// Dosya şöyle dizilmiş:
///
/// ```
/// "LTRMBK"        6 bayt sihirli imza
/// u16             biçim sürümü
/// u16             başlık uzunluğu
/// JSON            başlık — düz metin
/// [u32][...]      şifreli parçalar, sırayla
/// ```
///
/// Başlık **düz metin** olmak zorunda: anahtarı türetmek için gereken salt ve
/// KDF parametreleri onun içinde, yani onu okumadan hiçbir şey çözülemez.
/// Buradaki tehlike, saldırganın başlığı kurcalayıp KDF'yi zayıflatması ya da
/// salt'ı değiştirmesi. İki karar bunu yapısal olarak kapatıyor:
///
/// * **Başlığın ham baytları her parçaya AAD olarak veriliyor.** Tek bir bit
///   oynatılırsa her parçanın Poly1305 doğrulaması düşer.
/// * **Parça sayısı başlıkta yazılı** ve o da AAD'nin içinde. Dosyanın
///   sonundan parça kırpmak sessizce "kısmi yedek" üretemez; eksik parça
///   fark edilir.
abstract final class BackupCodec {
  static const magic = 'LTRMBK';
  static final _magicBytes = Uint8List.fromList(ascii.encode(magic));

  /// Bu uygulamanın yazdığı ve okuyabildiği en yüksek biçim sürümü.
  static const formatVersion = 1;

  /// 1 MiB. İlerleme çubuğunun akıcı görünmesi ile parça başına 16 baytlık
  /// etiket yükü arasındaki denge.
  static const chunkSize = 1024 * 1024;

  /// Poly1305 etiketi.
  static const macLength = 16;

  static const _prologueFixedLength = 6 + 2 + 2;

  /// Yazılacak dosyanın toplam boyutunu önceden verir.
  ///
  /// Paylaşım sayfası ve disk alanı kontrolü için; ayrıca test bunu gerçek
  /// çıktıyla karşılaştırıyor.
  static int fileLengthFor(int payloadLength, int headerLength) {
    final chunks = chunkCountFor(payloadLength);
    return _prologueFixedLength +
        headerLength +
        payloadLength +
        chunks * (4 + macLength);
  }

  static int chunkCountFor(int payloadLength) =>
      payloadLength <= 0 ? 0 : (payloadLength + chunkSize - 1) ~/ chunkSize;
}

/// Dosyanın başındaki, anahtar gerektirmeden okunabilen kısım.
final class BackupPrologue {
  const BackupPrologue({
    required this.formatVersion,
    required this.header,
    required this.aad,
    required this.payloadOffset,
  });

  final int formatVersion;
  final BackupHeader header;

  /// Sihirli imzadan başlığın sonuna kadar **ham** baytlar.
  ///
  /// Yeniden serileştirilmiş JSON değil, dosyadan okunanın aynısı: anahtar
  /// sırası ya da boşluk farkı AAD'yi değiştirip her şeyi bozardı.
  final Uint8List aad;

  final int payloadOffset;
}

final class BackupHeader {
  const BackupHeader({
    required this.cipher,
    required this.salt,
    required this.noncePrefix,
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.chunkSize,
    required this.chunkCount,
    required this.payloadLength,
  });

  factory BackupHeader.fromJson(Map<String, Object?> json) {
    final kdf = (json['kdf'] as Map?)?.cast<String, Object?>() ?? const {};
    return BackupHeader(
      cipher: (json['cipher'] as String?) ?? '',
      salt: _bytes(json['salt']),
      noncePrefix: _bytes(json['noncePrefix']),
      memoryKib: (kdf['m'] as num?)?.toInt() ?? 0,
      iterations: (kdf['t'] as num?)?.toInt() ?? 0,
      parallelism: (kdf['p'] as num?)?.toInt() ?? 0,
      chunkSize: (json['chunk'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunks'] as num?)?.toInt() ?? 0,
      payloadLength: (json['payload'] as num?)?.toInt() ?? 0,
    );
  }

  final String cipher;
  final Uint8List salt;
  final Uint8List noncePrefix;
  final int memoryKib;
  final int iterations;
  final int parallelism;
  final int chunkSize;
  final int chunkCount;
  final int payloadLength;

  Map<String, Object?> toJson() => {
    'cipher': cipher,
    'salt': base64.encode(salt),
    'noncePrefix': base64.encode(noncePrefix),
    'kdf': {
      'alg': 'argon2id',
      'm': memoryKib,
      't': iterations,
      'p': parallelism,
    },
    'chunk': chunkSize,
    'chunks': chunkCount,
    'payload': payloadLength,
  };

  /// Başlığın kendi içinde tutarlı olup olmadığı.
  ///
  /// Kontrol anahtar türetmeden **önce** yapılıyor: bozuk bir dosya için
  /// kullanıcıyı saniyelerce Argon2id beklettikten sonra "olmadı" demek
  /// gereksiz.
  bool get isCoherent =>
      cipher == BackupCrypto.cipherName &&
      salt.length == BackupCrypto.saltLength &&
      noncePrefix.length == BackupCrypto.noncePrefixLength &&
      memoryKib >= BackupCrypto.minArgonMemoryKib &&
      memoryKib <= BackupCrypto.maxArgonMemoryKib &&
      iterations > 0 &&
      iterations <= BackupCrypto.maxArgonIterations &&
      parallelism > 0 &&
      parallelism <= BackupCrypto.maxArgonParallelism &&
      chunkSize == BackupCodec.chunkSize &&
      payloadLength >= 0 &&
      chunkCount == BackupCodec.chunkCountFor(payloadLength);

  static Uint8List _bytes(Object? value) =>
      value is String ? Uint8List.fromList(base64.decode(value)) : Uint8List(0);
}

/// Düz metin akışını şifreleyip dosyaya yazar.
final class BackupWriter {
  BackupWriter._(this._sink, this._key, this._aad, this._noncePrefix);

  /// [payload] toplam uzunluğu **önceden bilinmeli**: parça sayısı başlığa
  /// yazılıyor ve kırpma tespitinin dayanağı o.
  static Future<BackupWriter> open({
    required File destination,
    required SecretKey key,
    required Uint8List salt,
    required Uint8List noncePrefix,
    required int payloadLength,
    int memoryKib = BackupCrypto.argonMemoryKib,
    int iterations = BackupCrypto.argonIterations,
    int parallelism = BackupCrypto.argonParallelism,
  }) async {
    final header = BackupHeader(
      cipher: BackupCrypto.cipherName,
      salt: salt,
      noncePrefix: noncePrefix,
      memoryKib: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
      chunkSize: BackupCodec.chunkSize,
      chunkCount: BackupCodec.chunkCountFor(payloadLength),
      payloadLength: payloadLength,
    );

    final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(header)));
    if (headerBytes.length > 0xFFFF) {
      throw const BackupFailure(BackupFailureKind.io, 'Başlık fazla uzun.');
    }

    final prologue = BytesBuilder(copy: false)
      ..add(BackupCodec._magicBytes)
      ..add(_u16(BackupCodec.formatVersion))
      ..add(_u16(headerBytes.length))
      ..add(headerBytes);
    final aad = prologue.toBytes();

    final sink = destination.openWrite();
    sink.add(aad);
    return BackupWriter._(sink, key, aad, noncePrefix);
  }

  final IOSink _sink;
  final SecretKey _key;
  final Uint8List _aad;
  final Uint8List _noncePrefix;
  final _pending = BytesBuilder(copy: false);
  int _counter = 0;

  /// Biriktirip tam parça doldukça mühürler. Girişler arasındaki sınır
  /// önemsiz: şifreleme, birleşik düz metin akışı üzerinde dönüyor.
  Future<void> add(List<int> bytes) async {
    _pending.add(bytes);
    while (_pending.length >= BackupCodec.chunkSize) {
      final buffered = _pending.takeBytes();
      var offset = 0;
      while (buffered.length - offset >= BackupCodec.chunkSize) {
        await _seal(
          Uint8List.sublistView(
            buffered,
            offset,
            offset + BackupCodec.chunkSize,
          ),
        );
        offset += BackupCodec.chunkSize;
      }
      if (offset < buffered.length) {
        _pending.add(Uint8List.sublistView(buffered, offset));
      }
    }
  }

  Future<void> finish() async {
    if (_pending.length > 0) await _seal(_pending.takeBytes());
    await _sink.flush();
    await _sink.close();
  }

  /// Yarıda kalan yazımı kapatır. Dosyayı silmek çağıranın işi.
  Future<void> abort() async {
    try {
      await _sink.close();
    } catch (_) {
      // Zaten hata yolundayız.
    }
  }

  Future<void> _seal(Uint8List plain) async {
    final box = await BackupCrypto.cipher.encrypt(
      plain,
      secretKey: _key,
      nonce: BackupCrypto.nonceFor(_noncePrefix, _counter),
      aad: _aad,
    );
    _counter++;

    final body = BytesBuilder(copy: false)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final bytes = body.takeBytes();
    _sink
      ..add(_u32(bytes.length))
      ..add(bytes);
  }
}

/// Şifreli dosyayı parça parça çözer.
///
/// Akış hâlinde okuyor: önizleme yalnızca manifesti alıp durabiliyor, geri
/// yükleme de yüzlerce megabaytı belleğe almadan ilerliyor.
final class BackupReader {
  BackupReader._(this._file, this._prologue, this._key);

  /// Anahtar gerektirmeden dosyanın başını okur.
  ///
  /// Kullanıcı yanlış bir dosya seçtiğinde parola sormadan söyleyebilmek için:
  /// "bu bir Latermark yedeği değil" demek, parolayı yazdırıp sonra reddetmekten
  /// iyidir. Uzantıya değil **sihirli baytlara** bakılıyor; uzantı yeniden
  /// adlandırılmış olabilir.
  static Future<BackupPrologue> readPrologue(File file) async {
    final handle = await file.open();
    try {
      final fixed = await handle.read(BackupCodec._prologueFixedLength);
      if (fixed.length < BackupCodec._prologueFixedLength) {
        throw const BackupFailure(BackupFailureKind.notABackup);
      }
      for (var i = 0; i < BackupCodec._magicBytes.length; i++) {
        if (fixed[i] != BackupCodec._magicBytes[i]) {
          throw const BackupFailure(BackupFailureKind.notABackup);
        }
      }

      final view = ByteData.sublistView(Uint8List.fromList(fixed));
      final version = view.getUint16(6, Endian.big);
      final headerLength = view.getUint16(8, Endian.big);
      if (version != BackupCodec.formatVersion) {
        throw const BackupFailure(BackupFailureKind.unsupportedFormat);
      }

      final headerBytes = await handle.read(headerLength);
      if (headerBytes.length < headerLength) {
        throw const BackupFailure(BackupFailureKind.corrupt);
      }

      final BackupHeader header;
      try {
        header = BackupHeader.fromJson(
          (jsonDecode(utf8.decode(headerBytes)) as Map).cast<String, Object?>(),
        );
      } catch (_) {
        throw const BackupFailure(
          BackupFailureKind.corrupt,
          'Başlık okunamadı',
        );
      }
      if (!header.isCoherent) {
        throw const BackupFailure(BackupFailureKind.corrupt, 'Başlık tutarsız');
      }

      // Başlığın söylediği yük/parça sayısı dosyanın fiziksel boyutuyla tam
      // uyuşmalı. Böylece hem kırpılmış hem de sonuna veri eklenmiş dosya,
      // pahalı KDF çalışmadan elenir.
      final expectedLength = BackupCodec.fileLengthFor(
        header.payloadLength,
        headerLength,
      );
      if (await file.length() != expectedLength) {
        throw const BackupFailure(BackupFailureKind.corrupt, 'Boyut tutmuyor');
      }

      final aad = BytesBuilder(copy: false)
        ..add(fixed)
        ..add(headerBytes);

      return BackupPrologue(
        formatVersion: version,
        header: header,
        aad: aad.toBytes(),
        payloadOffset: BackupCodec._prologueFixedLength + headerLength,
      );
    } finally {
      await handle.close();
    }
  }

  static Future<BackupReader> open({
    required File file,
    required BackupPrologue prologue,
    required SecretKey key,
  }) async {
    final handle = await file.open();
    await handle.setPosition(prologue.payloadOffset);
    return BackupReader._(handle, prologue, key);
  }

  final RandomAccessFile _file;
  final BackupPrologue _prologue;
  final SecretKey _key;
  int _counter = 0;

  int get chunkCount => _prologue.header.chunkCount;
  bool get hasMore => _counter < chunkCount;

  /// Sıradaki parçayı çözer.
  ///
  /// Doğrulama düşerse ayrım yapmıyoruz: yanlış parola ile kurcalanmış dosya
  /// kriptografik olarak aynı şeyi üretir. Kullanıcıya "parola yanlış" demek
  /// ikisinin de doğru özeti.
  Future<Uint8List> next() async {
    if (!hasMore) {
      throw const BackupFailure(BackupFailureKind.corrupt, 'Parça kalmadı');
    }

    final lengthBytes = await _file.read(4);
    if (lengthBytes.length < 4) {
      throw const BackupFailure(BackupFailureKind.corrupt, 'Dosya kesilmiş');
    }
    final length = ByteData.sublistView(
      Uint8List.fromList(lengthBytes),
    ).getUint32(0, Endian.big);

    if (length < BackupCodec.macLength ||
        length > BackupCodec.chunkSize + BackupCodec.macLength) {
      throw const BackupFailure(
        BackupFailureKind.corrupt,
        'Parça boyu geçersiz',
      );
    }

    final body = await _file.read(length);
    if (body.length < length) {
      throw const BackupFailure(BackupFailureKind.corrupt, 'Dosya kesilmiş');
    }

    final bytes = Uint8List.fromList(body);
    final box = SecretBox(
      Uint8List.sublistView(bytes, 0, bytes.length - BackupCodec.macLength),
      nonce: BackupCrypto.nonceFor(_prologue.header.noncePrefix, _counter),
      mac: Mac(
        Uint8List.sublistView(bytes, bytes.length - BackupCodec.macLength),
      ),
    );

    final List<int> plain;
    try {
      plain = await BackupCrypto.cipher.decrypt(
        box,
        secretKey: _key,
        aad: _prologue.aad,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupFailure(BackupFailureKind.wrongPassword);
    }

    _counter++;
    return plain is Uint8List ? plain : Uint8List.fromList(plain);
  }

  Future<void> close() => _file.close();
}

Uint8List _u16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.big);

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big);
