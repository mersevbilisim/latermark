import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Yedek dosyasının kriptografik temeli.
///
/// Tek bir sözü var: dosya bilgisayara kopyalandığında, parolayı bilmeyen biri
/// için rastgele baytlardan ayırt edilemez olmalı. Bunu iki katman kuruyor —
/// paroladan anahtar türeten yavaş bir KDF ve içeriği hem gizleyip hem
/// bütünlüğünü imzalayan bir AEAD.
abstract final class BackupCrypto {
  /// İçerik şifresi: XChaCha20-Poly1305.
  ///
  /// AES-GCM yerine bu seçildi çünkü şifreleme arka plan isolate'inde **saf
  /// Dart** ile dönüyor. `cryptography_flutter`'ın native hızlandırması
  /// platform kanalı üzerinden çalışıyor ve isolate'te kanal yok; donanım
  /// AES'i devre dışı kalınca ChaCha yazılımda açık ara önde. Ölçüm (AOT,
  /// 16 MiB): XChaCha20-Poly1305 31,6 MB/s, AES-256-GCM 19,4 MB/s.
  ///
  /// 24 baytlık nonce'u ayrıca rahatlık: sayaçlı türetmede taşma endişesi yok.
  static const cipherName = 'xchacha20-poly1305';

  /// Parametreler dosyanın başlığında yazılı; buradakiler yalnızca **yeni**
  /// yedeklerin varsayılanı. Eski bir yedek kendi parametreleriyle açılır,
  /// yani bu sayılar ileride yükseltilebilir.
  ///
  /// OWASP'ın Argon2id alt sınırı m=19 MiB, t=2. Buradaki 64 MiB / 3 tur onun
  /// belirgin üstünde ve ölçülen maliyeti AOT'ta 353 ms (telefonda ~1-1,5 sn) —
  /// kullanıcının bir kez beklediği bir işlem için kabul edilebilir, kaba
  /// kuvvet denemesi yapan biri içinse her deneme o kadar sürüyor.
  static const argonMemoryKib = 65536;
  static const argonIterations = 3;
  static const argonParallelism = 1;

  /// Başlık parola doğrulanmadan okunur; dolayısıyla içindeki KDF değerleri
  /// güvenilir değildir. Bu sınırlar, kurcalanmış bir dosyanın gigabaytlarca
  /// bellek veya saatlerce CPU istemesini engellerken gelecekte parametreleri
  /// makul ölçüde yükseltmeye alan bırakır.
  static const minArgonMemoryKib = 8192;
  static const maxArgonMemoryKib = 262144;
  static const maxArgonIterations = 12;
  static const maxArgonParallelism = 8;

  static const keyLength = 32;
  static const saltLength = 16;

  /// XChaCha20 nonce'u 24 bayt: 16 baytı dosya başına rastgele ön ek,
  /// 8 baytı parça sayacı.
  static const noncePrefixLength = 16;
  static const nonceLength = 24;

  static final _random = SecureRandom.fast;

  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextUint32() & 0xFF;
    }
    return bytes;
  }

  static Cipher get cipher => Xchacha20.poly1305Aead();

  /// Paroladan içerik anahtarını türetir. **Pahalı** — çağıran bunu bir kez
  /// yapıp anahtarı taşımalı.
  ///
  /// İki adım: önce Argon2id parolayı yavaşça bir ana anahtara çeviriyor,
  /// sonra HKDF ondan içerik anahtarını çıkarıyor. İkinci adım alan ayrımı
  /// için: ileride imza ya da başlık anahtarı gerekirse aynı ana anahtardan
  /// birbirine karışmayan alt anahtarlar üretilebilir, biçim kırılmaz.
  static Future<SecretKey> deriveKey({
    required String password,
    required Uint8List salt,
    required int memoryKib,
    required int iterations,
    required int parallelism,
  }) async {
    final argon2 = Argon2id(
      memory: memoryKib,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: keyLength,
    );

    final master = await argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    return hkdf.deriveKey(
      secretKey: master,
      nonce: salt,
      info: _contentKeyInfo,
    );
  }

  static final _contentKeyInfo = Uint8List.fromList(
    'latermark-backup-v1-content'.codeUnits,
  );

  /// Parça sayacından nonce üretir.
  ///
  /// Ön ek dosya başına rastgele ve anahtar her yedekte yeni bir salt'tan
  /// türüyor; sayaç da dosya içinde tekrar etmiyor. Yani aynı (anahtar, nonce)
  /// çiftinin iki kez kullanılması yapısal olarak imkânsız — ChaCha'da bu
  /// çiftin tekrarı akış anahtarını açığa çıkarırdı.
  static Uint8List nonceFor(Uint8List prefix, int counter) {
    assert(prefix.length == noncePrefixLength);
    final nonce = Uint8List(nonceLength)
      ..setRange(0, noncePrefixLength, prefix);
    ByteData.view(
      nonce.buffer,
    ).setUint64(noncePrefixLength, counter, Endian.big);
    return nonce;
  }
}
