/// Kullanıcının verdiği hatırlatma kararı.
///
/// Karar **bir andır**, bir gün sayısı değil. Eskiden "kaç gün sonra"
/// saklanıyor, gerçek an her okumada bir çıpaya gün eklenerek yeniden
/// hesaplanıyordu. Takvimden bir gün seçilebildiği anda o hesap yalan
/// söylemeye başlar: kullanıcı "6 Eylül" der, kayıt "32 gün sonra" tutar ve
/// ikisi yedekten dönüşte, yaz saati geçişinde ya da ertelemede birbirinden
/// kayar. Artık kaydın tuttuğu şey doğrudan anın kendisi.
///
/// Tekrar da ayrı bir bayrak değil: [everyDays] sıfırsa hatırlatma tek
/// atışlıktır. Böylece "tekrar açık ama aralık yok" gibi anlamsız bir durum
/// yapısal olarak kurulamıyor.
final class ReminderChoice {
  const ReminderChoice({this.at, this.everyDays = 0});

  const ReminderChoice.off() : this();

  /// Hatırlatmanın (tekrarlıda ilk) geleceği mutlak an. `null` ise hatırlatma
  /// yok.
  final DateTime? at;

  /// Tekrar aralığı (gün). `0` ise tek atış.
  final int everyDays;

  bool get isOn => at != null;

  bool get repeats => at != null && everyDays > 0;

  /// Takvimde seçilebilecek en uzak gün. Bundan uzağı için hatırlatma değil,
  /// takvim uygulaması doğru araçtır.
  static const maxDays = 365;

  @override
  bool operator ==(Object other) =>
      other is ReminderChoice && other.at == at && other.everyDays == everyDays;

  @override
  int get hashCode => Object.hash(at, everyDays);

  @override
  String toString() => at == null
      ? 'ReminderChoice(kapalı)'
      : 'ReminderChoice($at, her $everyDays günde bir)';
}

/// Hatırlatma çaldıktan sonra nota tanınan pay.
///
/// "Hatırlat, sonra sil" tek bir sözdür; süreyi ayarlanabilir yapmak
/// kullanıcıya ikinci bir karar daha yükler ve planlama ekranını bir forma
/// çevirirdi. Bir saat, bildirimi görüp kareye dönmeye yeter — ama notu
/// süresiz bekletmez.
const kReminderExpiryGrace = Duration(hours: 1);

/// Hatırlatmadan türetilen silinme anı.
DateTime reminderExpiryFor(DateTime remindAt) =>
    remindAt.add(kReminderExpiryGrace);

/// Notun silinme anı hatırlatmasından mı türetilmiş?
///
/// Ayrı bir sütun tutulmuyor: silinme anı zaten kayıtta ve hatırlatmanın tam
/// [kReminderExpiryGrace] sonrasına düşmesi bu kararın kendi imzası. Böylece
/// hatırlatma kaldırıldığında ona bağlı silinme sözünün de kalkması gerektiği
/// anlaşılıyor — kullanıcı hiç çalmayacak bir bildirimin ardından notunu
/// kaybetmiyor.
bool isReminderExpiry({
  required DateTime? remindAt,
  required DateTime? expiresAt,
}) =>
    remindAt != null &&
    expiresAt != null &&
    expiresAt == reminderExpiryFor(remindAt);

/// Bir notun hatırlatma isteği; bildirim programının tek girdisi.
///
/// Drift'in `Note` sınıfı yerine bu küçük tip kullanılıyor: buradaki hesabın
/// veritabanıyla hiçbir işi yok ve test edilirken bir veritabanı kurmayı
/// gerektirmemeli.
final class ReminderRequest {
  const ReminderRequest({
    required this.noteId,
    required this.remindAt,
    this.everyDays = 0,
    this.expiresAt,
    this.allowNativeRepeat = true,
  });

  final int noteId;

  /// Hatırlatmanın kesin anı; tekrarlıda dizinin ilk halkası.
  ///
  /// Fotoğrafın çekildiği andan bağımsızdır: galeriden yıllar önceki bir kare
  /// seçilse bile kullanıcının seçtiği gün neyse o yazılır.
  final DateTime remindAt;

  /// Tekrar aralığı (gün). `0` ise tek atış.
  final int everyDays;

  bool get repeats => everyDays > 0;

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
/// Tek atışta en fazla bir an döner ve o an geçmişse hiçbir şey dönmez. Tekrar
/// açıkken `remindAt + k·aralık` dizisinin gelecekte kalan ilk [limit] tanesi
/// döner.
///
/// Geçmiş oluşumlar döngüyle değil **aritmetikle** atlanıyor: bir yıl önce
/// başlayan günlük tekrar için yüzlerce kez dönmek gerekmesin.
List<DateTime> reminderOccurrences({
  required DateTime remindAt,
  required DateTime now,
  int everyDays = 0,
  DateTime? expiresAt,
  int limit = 1,
}) {
  if (limit <= 0) return const [];
  final repeats = everyDays > 0;

  // Sıfırıncı adım anın kendisidir: kayıt artık "çıpa + aralık" değil, doğrudan
  // hatırlatmanın anı.
  var step = repeats
      ? (localDayNumber(now) - localDayNumber(remindAt)) ~/ everyDays
      : 0;
  if (step < 0) step = 0;

  final occurrences = <DateTime>[];
  while (occurrences.length < limit) {
    final at = shiftLocalCalendarDays(remindAt, everyDays * step);

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
  required DateTime? remindAt,
  required DateTime now,
  int everyDays = 0,
  DateTime? expiresAt,
}) {
  if (remindAt == null) return null;
  final occurrences = reminderOccurrences(
    remindAt: remindAt,
    everyDays: everyDays,
    now: now,
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
      remindAt: request.remindAt,
      everyDays: request.everyDays,
      now: now,
      expiresAt: request.expiresAt,
      limit: nativeRepeat ? 1 : maxPerNote,
    );
    if (occurrences.isEmpty) continue;

    pending[request.noteId] = occurrences;
    byId[request.noteId] = request;
    if (nativeRepeat) {
      nativeIntervals[request.noteId] = Duration(days: request.everyDays);
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
          ? _stepOf(
                  at: occurrences[round],
                  remindAt: request.remindAt,
                  everyDays: request.everyDays,
                ) %
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
  required DateTime remindAt,
  required int everyDays,
}) => (localDayNumber(at) - localDayNumber(remindAt)) ~/ everyDays;

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

/// İki anın kaç **takvim günü** ayrı olduğu; saatler yok sayılır.
///
/// Aralık hesabı buradan geçiyor: bu akşam 23:00'te seçilen "yarın" bir gündür,
/// 25 saat sonrası olması onu iki gün yapmaz.
int localCalendarDaysBetween(DateTime from, DateTime to) =>
    localDayNumber(to) - localDayNumber(from);

/// Yerel takvimde günün sıra numarası. Aynı güne düşen iki an için eşittir.
int localDayNumber(DateTime value) {
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
