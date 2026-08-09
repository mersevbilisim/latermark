/// Bir not için gerçekten bekleyen hatırlatma anını hesaplar.
///
/// `remindAfterDays > 0` tek başına yeterli değildir: hedef geçmişte kalmış
/// veya not hedefe ulaşmadan silinecek olabilir. Bildirim servisi ile ana
/// ekran aynı hesabı kullanır; aksi hâlde kart "aktif" derken işletim sistemi
/// hiçbir şey planlamayabilirdi.
DateTime? pendingReminderAt({
  required DateTime createdAt,
  required int remindAfterDays,
  required DateTime now,
  DateTime? expiresAt,
}) {
  if (remindAfterDays <= 0) return null;

  final at = createdAt.add(Duration(days: remindAfterDays));
  if (!at.isAfter(now)) return null;
  if (expiresAt != null && !expiresAt.isAfter(at)) return null;
  return at;
}
