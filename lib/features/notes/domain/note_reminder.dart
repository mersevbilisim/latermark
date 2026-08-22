/// Bir notun hatırlatma isteği; bildirim programının tek girdisi.
///
/// Drift'in `Note` sınıfı yerine bu küçük tip kullanılıyor: buradaki hesabın
/// veritabanıyla hiçbir işi yok ve test edilirken bir veritabanı kurmayı
/// gerektirmemeli.
final class ReminderRequest {
  const ReminderRequest({
    required this.noteId,
    required this.anchorAt,
    required this.remindAfterDays,
    required this.repeats,
    this.expiresAt,
    this.allowNativeRepeat = true,
  });

  final int noteId;

  /// Kullanıcının bu hatırlatma ayarını başlattığı an.
  ///
  /// Fotoğrafın çekildiği andan özellikle ayrıdır. Galeriden yıllar önceki bir
  /// kare seçilse bile "30 gün" bugünden sayılmalıdır.
  final DateTime anchorAt;

  /// Hatırlatma aralığı (gün). `0` ise hatırlatma yok.
  ///
  /// Tekrar kapalıyken "kaç gün sonra", açıkken "kaç günde bir" demek. Tek
  /// sayı, iki mod.
  final int remindAfterDays;

  final bool repeats;

  /// Notun otomatik silinme anı; süresizse `null`. Silinmiş bir notu
  /// hatırlatmanın anlamı yok.
  final DateTime? expiresAt;

  /// Platform ilk kesin tarihi ve aralığı aynı native kayıtta ifade
  /// edebiliyorsa `true`. iOS'taki özel N günlük tekrarlar gibi bunu
  /// yapamayan yollar, fazı koruyan sınırlı tek-atış dizisine açılır.
  final bool allowNativeRepeat;
}

/// İşletim sistemine verilecek tek bir hatırlatma kaydı.
final class ScheduledReminder {
  const ScheduledReminder({
    required this.noteId,
    required this.occurrence,
    required this.at,
    this.repeatInterval,
  });

  final int noteId;

  /// Bu not için ayrılan kimlik aralığındaki sıra numarası (0 tabanlı).
  final int occurrence;

  /// Tek atışta mutlak bildirim anı; native tekrarda ilk beklenen oluşum.
  final DateTime at;

  /// `null` ise [at] anında tek atış. Doluysa işletim sisteminde bu aralıkla
  /// kullanıcı kapatana veya not silinene kadar tekrarlayan tek kayıt.
  final Duration? repeatInterval;

  bool get repeatsIndefinitely => repeatInterval != null;

  /// İşletim sistemine verilecek bildirim kimliği.
  int get notificationId => reminderNotificationId(noteId, occurrence);

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminder &&
      other.noteId == noteId &&
      other.occurrence == occurrence &&
      other.at == at &&
      other.repeatInterval == repeatInterval;

  @override
  int get hashCode => Object.hash(noteId, occurrence, at, repeatInterval);

  @override
  String toString() =>
      'ScheduledReminder(note: $noteId, #$occurrence, $at, '
      'repeat: $repeatInterval)';
}

/// Aynı anda bekleyebilecek toplam bildirim sayısı.
///
/// iOS **64** bekleyen bildirimden fazlasını tutmaz; biraz pay bırakmak başka
/// bir bildirim türünün hatırlatmalar tarafından ezilmesini önler. Süresiz bir
/// tekrar bu bütçeden yalnızca **bir** kayıt kullanır.
const kPendingReminderBudget = 60;

/// Tek bir native tekrarın ifade edemediği fazı korumak için kurulacak kayan
/// tek-atış penceresinin not başına üst sınırı.
///
/// iOS toplamda 64 bekleyen isteğe izin verse de tek bir not için 60 isteği
/// aynı senkronda köprüden geçirmek özellikle Simulator'da uzun süreli UI
/// donmasına yol açabiliyor. Sekiz oluşum günlük/haftalık olmayan tekrarlar
/// için yeterli bir ileri pencere bırakır; uygulama her açılış/resume
/// senkronunda pencereyi ileri taşır.
const kRollingReminderWindowPerNote = 8;

/// Bir notun oluşumlarına ayrılan kimlik aralığı.
///
/// Otomatik silinen bir notun tekrarları native olamaz: işletim sistemi notun
/// silinme tarihini bilmez. Böyle kayıtların silinme sınırına kadar en fazla
/// bütün bildirim bütçesini kullanabilmesi için aralık da bütçeden büyüktür.
const kOccurrenceSpan = 64;

/// Bir oluşumun işletim sistemi tarafındaki kimliği.
///
/// Android bildirim kimlikleri 32-bit; bu çarpım yaklaşık 33 milyon nota kadar
/// güvenli, yani uygulamanın gerçek ömründe erişilemeyecek kadar yüksek.
int reminderNotificationId(int noteId, int occurrence) {
  assert(noteId > 0);
  assert(occurrence >= 0 && occurrence < kOccurrenceSpan);
  return noteId * kOccurrenceSpan + occurrence;
}

/// Güncel kimlik şemasındaki bir bildirim kimliğinin ait olduğu not.
int noteIdFromNotificationId(int notificationId) =>
    notificationId ~/ kOccurrenceSpan;

/// Bir notun bekleyen hatırlatma anları, en yakından uzağa.
///
/// Tekrar kapalıyken en fazla bir an döner. Açıkken `anchorAt + k·gün`
/// dizisinin gelecekte kalan ilk [limit] tanesi döner.
///
/// Geçmiş oluşumlar döngüyle değil **aritmetikle** atlanıyor: bir yıl önce
/// başlayan günlük tekrar için yüzlerce kez dönmek gerekmesin.
List<DateTime> reminderOccurrences({
  required DateTime anchorAt,
  required int remindAfterDays,
  required DateTime now,
  bool repeats = false,
  DateTime? expiresAt,
  int limit = 1,
}) {
  if (remindAfterDays <= 0 || limit <= 0) return const [];

  var step = repeats
      ? (_localDayNumber(now) - _localDayNumber(anchorAt)) ~/ remindAfterDays
      : 1;
  if (step < 1) step = 1;

  final occurrences = <DateTime>[];
  while (occurrences.length < limit) {
    final at = shiftLocalCalendarDays(anchorAt, remindAfterDays * step);

    // Silinme anındaki veya ondan sonraki bir bildirim hayalet bildirimdir.
    if (expiresAt != null && !expiresAt.isAfter(at)) break;

    if (at.isAfter(now)) {
      occurrences.add(at);
      if (!repeats) break;
    } else if (!repeats) {
      // Tek atış geçmişse yeniden kurulmaz.
      break;
    }

    step++;
  }

  return occurrences;
}

/// Bir not için gerçekten bekleyen ilk hatırlatma anı.
DateTime? pendingReminderAt({
  required DateTime anchorAt,
  required int remindAfterDays,
  required DateTime now,
  bool repeats = false,
  DateTime? expiresAt,
}) {
  final occurrences = reminderOccurrences(
    anchorAt: anchorAt,
    remindAfterDays: remindAfterDays,
    now: now,
    repeats: repeats,
    expiresAt: expiresAt,
  );
  return occurrences.isEmpty ? null : occurrences.first;
}

/// Bütün notların bekleyen hatırlatmalarını sınırlı bütçeye paylaştırır.
///
/// Süresiz ve tekrarlı bir not işletim sisteminde tek kayıt kullanır. Süreli
/// bir not ise silindikten sonra native tekrar üretmesin diye, yalnız silinme
/// anına kadarki oluşumları tek tek alır.
///
/// Sonlu oluşumlarda paylaştırma tur tur yapılır: hiçbir not ikinci oluşumunu,
/// her not birincisini almadan alamaz. İlk tura bile sığmayacak kadar çok
/// istek varsa en yakın zamanlılar kazanır.
List<ScheduledReminder> reminderSchedule({
  required List<ReminderRequest> requests,
  required DateTime now,
  int budget = kPendingReminderBudget,
  int maxPerNote = kPendingReminderBudget,
}) {
  if (budget <= 0 || maxPerNote <= 0) return const [];

  final pending = <int, List<DateTime>>{};
  final nativeIntervals = <int, Duration>{};
  final byId = <int, ReminderRequest>{};
  for (final request in requests) {
    final nativeRepeat =
        request.repeats &&
        request.expiresAt == null &&
        request.allowNativeRepeat;
    final occurrences = reminderOccurrences(
      anchorAt: request.anchorAt,
      remindAfterDays: request.remindAfterDays,
      now: now,
      repeats: request.repeats,
      expiresAt: request.expiresAt,
      limit: nativeRepeat ? 1 : maxPerNote,
    );
    if (occurrences.isEmpty) continue;

    pending[request.noteId] = occurrences;
    byId[request.noteId] = request;
    if (nativeRepeat) {
      nativeIntervals[request.noteId] = Duration(days: request.remindAfterDays);
    }
  }

  final order = pending.keys.toList()
    ..sort((a, b) {
      final byTime = pending[a]!.first.compareTo(pending[b]!.first);
      return byTime != 0 ? byTime : a.compareTo(b);
    });

  final schedule = <ScheduledReminder>[];
  for (var round = 0; round < maxPerNote; round++) {
    for (final noteId in order) {
      final occurrences = pending[noteId]!;
      if (round >= occurrences.length) continue;
      if (schedule.length >= budget) return schedule..sort(_byTime);
      final request = byId[noteId]!;
      final repeatsNatively = nativeIntervals.containsKey(noteId);
      final occurrence = request.repeats && !repeatsNatively
          ? (_stepOf(
                      at: occurrences[round],
                      anchorAt: request.anchorAt,
                      interval: Duration(days: request.remindAfterDays),
                    ) -
                    1) %
                kOccurrenceSpan
          : round;
      schedule.add(
        ScheduledReminder(
          noteId: noteId,
          occurrence: occurrence,
          at: occurrences[round],
          repeatInterval: repeatsNatively && round == 0
              ? nativeIntervals[noteId]
              : null,
        ),
      );
    }
  }

  return schedule..sort(_byTime);
}

int _stepOf({
  required DateTime at,
  required DateTime anchorAt,
  required Duration interval,
}) => (_localDayNumber(at) - _localDayNumber(anchorAt)) ~/ interval.inDays;

/// Yerel takvimde gün ekler; `Duration(days: 1)` gibi 24 saat eklemez.
/// Böylece yaz/kış saati geçişinde kullanıcının seçtiği duvar saati korunur.
DateTime shiftLocalCalendarDays(DateTime at, int days) {
  final local = at.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day + days,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  );
}

int _localDayNumber(DateTime value) {
  final local = value.toLocal();
  return DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

int _byTime(ScheduledReminder a, ScheduledReminder b) {
  final byTime = a.at.compareTo(b.at);
  if (byTime != 0) return byTime;
  final byNote = a.noteId.compareTo(b.noteId);
  return byNote != 0 ? byNote : a.occurrence.compareTo(b.occurrence);
}
