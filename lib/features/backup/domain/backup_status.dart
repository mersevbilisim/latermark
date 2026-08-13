/// Yedekleme ve geri yükleme akışlarının dışarıya gösterdiği durum.
library;

enum BackupPhase {
  /// Notlar okunuyor, kareler ölçülüp özetleniyor.
  preparing,

  /// Argon2id çalışıyor. Tek başına bir evre, çünkü saniyeler sürüyor ve
  /// bu sırada ilerleme çubuğu kıpırdamıyor — kullanıcı takıldığını sanmasın.
  derivingKey,

  writing,
  reading,

  /// Çözülen girişlerin SHA-256'sı doğrulanıyor.
  verifying,

  /// Doğrulanmış veri yerine taşınıyor. Buradan sonra iptal yok.
  applying,

  done,
}

final class BackupProgress {
  const BackupProgress({
    required this.phase,
    this.processed = 0,
    this.total = 0,
    this.itemsDone = 0,
    this.itemsTotal = 0,
  });

  final BackupPhase phase;

  /// İşlenen ve toplam bayt. Anahtar türetme evresinde ikisi de sıfır:
  /// Argon2id'nin ilerlemesi ölçülemiyor.
  final int processed;
  final int total;

  /// "12/20 kare" gibi insanca bir sayaç için.
  final int itemsDone;
  final int itemsTotal;

  double? get fraction =>
      total <= 0 ? null : (processed / total).clamp(0.0, 1.0);
}

/// Ayırt edilebilir başarısızlıklar.
///
/// Tek bir "yedek açılamadı" mesajı kullanıcıyı çaresiz bırakır: yanlış parola
/// mı yazdı, dosya mı bozuk, yoksa yedek bu sürümden yeni mi — üçünün cevabı
/// bambaşka.
enum BackupFailureKind {
  /// Dosya Latermark yedeği değil (sihirli baytlar tutmuyor).
  notABackup,

  /// Biçim sürümü bu uygulamadan yeni.
  unsupportedFormat,

  /// Yedek daha yeni bir veritabanı şemasıyla alınmış.
  unsupportedSchema,

  /// Parola yanlış — ya da dosya kurcalanmış. İkisi kriptografik olarak
  /// ayırt edilemez; AEAD doğrulaması her iki durumda da düşer.
  wrongPassword,

  /// Dosya kesilmiş, eksik ya da içi tutarsız.
  corrupt,

  cancelled,

  /// Disk dolu, izin yok, okunamadı.
  io,
}

final class BackupFailure implements Exception {
  const BackupFailure(this.kind, [this.detail]);

  final BackupFailureKind kind;
  final String? detail;

  @override
  String toString() =>
      'BackupFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
