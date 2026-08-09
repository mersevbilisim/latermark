import '../../notes/domain/retention.dart';

/// Mevcut bir notun free katmana taşınmış saklama durumu.
final class FreeNoteRetention {
  const FreeNoteRetention({required this.choice, required this.expiresAt});

  final RetentionChoice choice;
  final DateTime? expiresAt;
}

/// Custom saklama tercihini veri kaybı yaratmayan en yakın free seçeneğe taşır.
///
/// Hem gelecekteki kayıtların varsayılanında hem de mevcut notları normalize
/// ederken kullanılır. Mevcut notların kesin bitişini koruma kuralı ayrıca
/// [freeNoteRetention] tarafından uygulanır.
RetentionChoice freeRetentionFallback(RetentionChoice current) {
  if (!current.retention.isCustom) {
    // Free bir seçim zaten geçerli; custom'a ait anlamsız eski dakikayı temizle.
    return RetentionChoice(current.retention);
  }

  final minutes = current.customMinutes;
  if (minutes <= 0) return const RetentionChoice.off();

  final threeDays = Retention.threeDays.duration!.inMinutes;
  if (minutes <= threeDays) {
    // Free seçeneklerin içinde yukarı yuvarla: ör. 1 gün 3 güne uzar.
    return const RetentionChoice(Retention.threeDays);
  }

  final oneWeek = Retention.oneWeek.duration!.inMinutes;
  if (minutes <= oneWeek) {
    return const RetentionChoice(Retention.oneWeek);
  }

  // Free katmanda bir haftadan uzun hazır süre yok. Bir haftaya kısaltmak
  // veri kaybı riski yaratacağından en güvenli free karşılık süresizdir.
  return const RetentionChoice.off();
}

/// Mevcut custom notu veri kaybı yaratmadan free saklama seçeneklerine taşır.
///
/// Yeni bitiş zamanı daima notun özgün [createdAt] anından hesaplanır; downgrade
/// anından saymak notun ömrünü yapay biçimde baştan başlatırdı. Seçilen hazır
/// sürenin bitişi yürürlükteki [currentExpiresAt] değerinden erkense bir sonraki
/// uzun free seçeneğe çıkılır. Bir hafta da yetmiyorsa `Off/null` kullanılır.
FreeNoteRetention freeNoteRetention({
  required RetentionChoice current,
  required DateTime createdAt,
  required DateTime? currentExpiresAt,
}) {
  if (!current.retention.isCustom) {
    return FreeNoteRetention(
      choice: RetentionChoice(current.retention),
      expiresAt: currentExpiresAt,
    );
  }

  // Null bitiş hâli fiilen süresizdir; downgrade ona yeni bir silinme tarihi
  // veremez.
  if (currentExpiresAt == null) {
    return const FreeNoteRetention(
      choice: RetentionChoice.off(),
      expiresAt: null,
    );
  }

  var choice = freeRetentionFallback(current);
  var expiresAt = choice.expiryFrom(createdAt);

  while (expiresAt != null && expiresAt.isBefore(currentExpiresAt)) {
    choice = switch (choice.retention) {
      Retention.threeDays => const RetentionChoice(Retention.oneWeek),
      Retention.oneWeek => const RetentionChoice.off(),
      Retention.off || Retention.custom => const RetentionChoice.off(),
    };
    expiresAt = choice.expiryFrom(createdAt);
  }

  return FreeNoteRetention(choice: choice, expiresAt: expiresAt);
}
