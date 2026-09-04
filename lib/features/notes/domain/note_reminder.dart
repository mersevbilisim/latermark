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
  const ReminderChoice({this.at, this.cadence = ReminderCadence.once});

  const ReminderChoice.off() : this();

  /// Hatırlatmanın (tekrarlıda ilk) geleceği mutlak an. `null` ise hatırlatma
  /// yok.
  final DateTime? at;

  /// Yineleme ritmi.
  final ReminderCadence cadence;

  /// Kaydın gün sütununa yazılan değer.
  int get everyDays => cadence.code;

  bool get isOn => at != null;

  bool get repeats => at != null && cadence.repeats;

  /// Takvimde seçilebilecek en uzak gün. Bundan uzağı için hatırlatma değil,
  /// takvim uygulaması doğru araçtır.
  static const maxDays = 365;

  @override
  bool operator ==(Object other) =>
      other is ReminderChoice && other.at == at && other.cadence == cadence;

  @override
  int get hashCode => Object.hash(at, cadence);

  @override
  String toString() => at == null
      ? 'ReminderChoice(kapalı)'
      : 'ReminderChoice($at, her $everyDays günde bir)';
}

/// Hatırlatmanın yineleme ritmi.
///
/// Ritim, seçilen tarihten **bağımsız** bir karar. Eskiden tekrar tek bir
/// anahtardı ve aralık "bugünden seçilen güne kaç gün var" diye hesaplanıyordu:
/// 1 Eylül'ü seçip tekrarı açan biri "her ay" demek isterken kayıt "her 24
/// günde bir" oluyor, sonraki oluşum da 25 Eylül'e kayıyordu. "Her ay" ve "her
/// yıl" zaten sabit gün sayısı değil; gün sayısıyla ifade edilemezler.
///
/// **Depolama gün sütununda kalıyor.** `remind_every_days` bir tam sayı ve
/// eskiden "her N günde bir" demekti; N her zaman takvimin kendi sınırı olan
/// [ReminderChoice.maxDays] içindeydi. Bu yüzden 365'in üstündeki değerler
/// eski kayıtlarla **çakışamaz** ve ritim şema göçü olmadan aynı sütuna
/// sığıyor. Sayılar yedek dosyasının doğrulama aralığında da kaldığı için eski
/// sürümler yeni bir yedeği okumayı reddetmiyor.
enum ReminderCadence {
  once(0),
  daily(1),
  weekly(7),
  monthly(1000),
  yearly(1001);

  const ReminderCadence(this.code);

  /// Kaydın gün sütununda duran değer.
  final int code;

  bool get repeats => this != ReminderCadence.once;

  /// Sütundaki değerin ritmi.
  ///
  /// Bu sürümden önce yazılmış "her N günde bir" kayıtları en yakın gerçek
  /// ritme taşınıyor. Tekrarı tümden düşürmek kullanıcının kurduğu sözü sessizce
  /// bozardı; ritmi biraz kaydırmak, hiç hatırlatmamaktan iyi.
  static ReminderCadence fromCode(int code) => switch (code) {
    <= 0 => once,
    1 => daily,
    1000 => monthly,
    1001 => yearly,
    <= 10 => weekly,
    <= 200 => monthly,
    _ => yearly,
  };

  /// Çıpadan [step] adım ötedeki yerel takvim anı.
  ///
  /// Aylık ve yıllık ritimde hedef ayda aynı gün yoksa o ayın son günü
  /// kullanılır: 31 Ocak → 28/29 Şubat → 31 Mart; 29 Şubat →
  /// artık olmayan yılda 28 Şubat. Hesap her zaman ilk çıpadan yapılır;
  /// Şubat'a kısılmak sonraki ayları kalıcı olarak 28'e kaydırmaz.
  DateTime? advance(DateTime anchor, int step) {
    if (step == 0) return anchor;
    switch (this) {
      case ReminderCadence.once:
        return null;
      case ReminderCadence.daily:
        return shiftLocalCalendarDays(anchor, step);
      case ReminderCadence.weekly:
        return shiftLocalCalendarDays(anchor, 7 * step);
      case ReminderCadence.monthly:
        final months = anchor.year * 12 + (anchor.month - 1) + step;
        return _clamped(months ~/ 12, months % 12 + 1, anchor);
      case ReminderCadence.yearly:
        return _clamped(anchor.year + step, anchor.month, anchor);
    }
  }

  static DateTime _clamped(int year, int month, DateTime anchor) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      anchor.day > lastDay ? lastDay : anchor.day,
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    );
  }
}

/// Hatırlatma notun kendi silinme anına yetişemiyor.
final class ReminderAfterExpiryException implements Exception {
  const ReminderAfterExpiryException();
}

/// Hatırlatma çaldıktan sonra nota tanınan pay.
///
/// "Hatırlat, sonra sil" tek bir sözdür; süreyi ayarlanabilir yapmak
/// kullanıcıya ikinci bir karar daha yükler ve planlama ekranını bir forma
/// çevirirdi.
///
/// Payın alt sınırını zevk değil **düzenek** belirliyor: silme bir zamanlayıcı
/// değil, süpürme. `purgeExpired()` açılışta, öne gelişte ve önplandayken
/// dakikada bir koşuyor, yani not süre dolduktan sonraki ilk açılışta gidiyor.
/// Pay, "kullanıcının telefonu eline alması" süresinden kısa olamaz — yoksa
/// bildirime dokunan biri notun olmadığı bir arşive düşer, ya da kart tam
/// bakarken dakikalık süpürmede altından silinir. Beş dakika bu yüzden
/// elendi: odaklanma kipi, cepteki telefon, saatten gelen bildirim hep o
/// aralığa giriyor. Yarım saat boşluğu yutuyor ama kareyi de günlerce
/// bekletmiyor.
///
/// Değeri değiştirirken `reminderDeleteAfterLabel` de on dilde değişmeli:
/// etiket süreyi rakamla söylüyor.
const kReminderExpiryGrace = Duration(minutes: 30);

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
    this.cadence = ReminderCadence.once,
    this.expiresAt,
  });

  final int noteId;

  /// Hatırlatmanın kesin anı; tekrarlıda dizinin ilk halkası.
  ///
  /// Fotoğrafın çekildiği andan bağımsızdır: galeriden yıllar önceki bir kare
  /// seçilse bile kullanıcının seçtiği gün neyse o yazılır.
  final DateTime remindAt;

  final ReminderCadence cadence;

  bool get repeats => cadence.repeats;

  /// Notun otomatik silinme anı; süresizse `null`. Silinmiş bir notu
  /// hatırlatmanın anlamı yok.
  final DateTime? expiresAt;
}

/// İşletim sistemine verilecek tek bir hatırlatma kaydı.
final class ScheduledReminder {
  const ScheduledReminder({
    required this.noteId,
    required this.occurrence,
    required this.at,
    this.repeat,
  });

  final int noteId;

  /// Bu not için ayrılan kimlik aralığındaki sıra numarası (0 tabanlı).
  final int occurrence;

  /// Tek atışta mutlak bildirim anı; native tekrarda ilk beklenen oluşum.
  final DateTime at;

  /// `null` ise [at] anında tek atış. Doluysa işletim sistemi bu ritimde,
  /// kullanıcı kapatana veya not silinene kadar kendi kendine yineleyen tek
  /// kayıt kurar.
  ///
  /// Silinme tarihi olan bir not burada asla ritim taşımaz: işletim sistemi
  /// notun ne zaman gideceğini bilmiyor ve sonsuza kadar çalmaya devam ederdi.
  /// Onlar sınırlı bir tek-atış dizisiyle kuruluyor.
  final ReminderCadence? repeat;

  bool get repeatsIndefinitely => repeat != null;

  /// İşletim sistemine verilecek bildirim kimliği.
  int get notificationId => reminderNotificationId(noteId, occurrence);

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminder &&
      other.noteId == noteId &&
      other.occurrence == occurrence &&
      other.at == at &&
      other.repeat == repeat;

  @override
  int get hashCode => Object.hash(noteId, occurrence, at, repeat);

  @override
  String toString() =>
      'ScheduledReminder(note: $noteId, #$occurrence, $at, '
      'repeat: ${repeat?.name})';
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
  ReminderCadence cadence = ReminderCadence.once,
  DateTime? expiresAt,
  int limit = 1,
}) {
  if (limit <= 0) return const [];
  if (!cadence.repeats) {
    // Tek atış: geçmişse yeniden kurulmaz.
    if (expiresAt != null && !expiresAt.isAfter(remindAt)) return const [];
    return remindAt.isAfter(now) ? [remindAt] : const [];
  }

  // Geçmiş oluşumlar tek tek dolaşılmıyor: bir yıl önce başlayan günlük bir
  // tekrar için yüzlerce adım gerekirdi. Ritmin kendi biriminde kaba bir
  // sıçrama yapılıp oradan yürünüyor.
  var step = switch (cadence) {
    ReminderCadence.daily => localDayNumber(now) - localDayNumber(remindAt),
    ReminderCadence.weekly =>
      (localDayNumber(now) - localDayNumber(remindAt)) ~/ 7,
    ReminderCadence.monthly =>
      (now.year * 12 + now.month) - (remindAt.year * 12 + remindAt.month),
    ReminderCadence.yearly => now.year - remindAt.year,
    ReminderCadence.once => 0,
  };
  if (step < 0) step = 0;

  final occurrences = <DateTime>[];
  while (occurrences.length < limit) {
    final at = cadence.advance(remindAt, step);
    step++;
    if (at == null) continue;

    // Silinme anındaki veya ondan sonraki bir bildirim hayalet bildirimdir.
    if (expiresAt != null && !expiresAt.isAfter(at)) break;
    if (at.isAfter(now)) occurrences.add(at);
  }

  return occurrences;
}

/// Native takvim eşleşmesinin [now] sonrasındaki ilk anı.
///
/// iOS ve Android tekrar kaydına gelecekteki bir "başlama tarihi" değil,
/// yalnız eşleşecek takvim bileşenleri veriyor. Bu an, saklanan ilk halkayla
/// aynı değilse native kayıt erken çalar; zamanlayıcı o durumda kesin
/// tek-atış penceresine döner.
DateTime nextNativeRepeatAt({
  required DateTime pattern,
  required DateTime now,
  required ReminderCadence cadence,
}) {
  assert(cadence.repeats);
  final localNow = now.toLocal();
  final localPattern = pattern.toLocal();
  DateTime candidate(int year, int month, int day) => DateTime(
    year,
    month,
    day,
    localPattern.hour,
    localPattern.minute,
    localPattern.second,
    localPattern.millisecond,
    localPattern.microsecond,
  );

  switch (cadence) {
    case ReminderCadence.once:
      return pattern;
    case ReminderCadence.daily:
      var at = candidate(localNow.year, localNow.month, localNow.day);
      if (!at.isAfter(localNow)) at = shiftLocalCalendarDays(at, 1);
      return at;
    case ReminderCadence.weekly:
      var at = candidate(localNow.year, localNow.month, localNow.day);
      final daysAhead = (localPattern.weekday - localNow.weekday + 7) % 7;
      at = shiftLocalCalendarDays(at, daysAhead);
      if (!at.isAfter(localNow)) at = shiftLocalCalendarDays(at, 7);
      return at;
    case ReminderCadence.monthly:
      var month = localNow.year * 12 + localNow.month - 1;
      while (true) {
        final year = month ~/ 12;
        final monthOfYear = month % 12 + 1;
        final at = candidate(year, monthOfYear, localPattern.day);
        if (at.month == monthOfYear &&
            at.day == localPattern.day &&
            at.isAfter(localNow)) {
          return at;
        }
        month++;
      }
    case ReminderCadence.yearly:
      var year = localNow.year;
      while (true) {
        final at = candidate(year, localPattern.month, localPattern.day);
        if (at.month == localPattern.month &&
            at.day == localPattern.day &&
            at.isAfter(localNow)) {
          return at;
        }
        year++;
      }
  }
}

/// Bir not için gerçekten bekleyen ilk hatırlatma anı.
DateTime? pendingReminderAt({
  required DateTime? remindAt,
  required DateTime now,
  ReminderCadence cadence = ReminderCadence.once,
  DateTime? expiresAt,
}) {
  if (remindAt == null) return null;
  final occurrences = reminderOccurrences(
    remindAt: remindAt,
    cadence: cadence,
    now: now,
    expiresAt: expiresAt,
  );
  return occurrences.isEmpty ? null : occurrences.first;
}

/// Bütün notların bekleyen hatırlatmalarını sınırlı bütçeye paylaştırır.
///
/// Günlük/haftalık bir not, saklanan ilk halka native eşleşmenin ilk
/// halkasıysa işletim sisteminde tek kayıt kullanır. Gelecekte ayrıca bir
/// başlangıç tarihi varsa erken çalmaması için kesin tek-atış dizisine döner.
///
/// Ayın 1–28'indeki aylık ve 29 Şubat dışındaki yıllık ritimler de native
/// takvim kaydı olabilir. 29/30/31 aylık ve 29 Şubat yıllık ise kesin
/// tarihler halinde kurulur; native bileşen eşleşmesi olmayan tarihi atlayarak
/// ürünün "son geçerli gün" sözünü bozar.
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
  final nativeRepeats = <int, ReminderCadence>{};
  final byId = <int, ReminderRequest>{};
  for (final request in requests) {
    final first = reminderOccurrences(
      remindAt: request.remindAt,
      cadence: request.cadence,
      now: now,
      expiresAt: request.expiresAt,
      limit: 1,
    );
    if (first.isEmpty) continue;

    final localAnchor = request.remindAt.toLocal();
    final nativeCadence = switch (request.cadence) {
      ReminderCadence.once => false,
      ReminderCadence.daily || ReminderCadence.weekly => true,
      ReminderCadence.monthly => localAnchor.day <= 28,
      ReminderCadence.yearly =>
        localAnchor.month != DateTime.february || localAnchor.day != 29,
    };
    final nativeRepeat =
        request.expiresAt == null &&
        nativeCadence &&
        first.single ==
            nextNativeRepeatAt(
              pattern: request.remindAt,
              now: now,
              cadence: request.cadence,
            );
    final occurrences = nativeRepeat
        ? first
        : reminderOccurrences(
            remindAt: request.remindAt,
            cadence: request.cadence,
            now: now,
            expiresAt: request.expiresAt,
            limit: maxPerNote,
          );

    pending[request.noteId] = occurrences;
    byId[request.noteId] = request;
    if (nativeRepeat) nativeRepeats[request.noteId] = request.cadence;
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
      final repeatsNatively = nativeRepeats.containsKey(noteId);
      final occurrence = request.repeats && !repeatsNatively
          ? _stepOf(
                  at: occurrences[round],
                  remindAt: request.remindAt,
                  cadence: request.cadence,
                ) %
                kOccurrenceSpan
          : round;
      schedule.add(
        ScheduledReminder(
          noteId: noteId,
          occurrence: occurrence,
          at: occurrences[round],
          repeat: repeatsNatively && round == 0 ? nativeRepeats[noteId] : null,
        ),
      );
    }
  }

  return schedule..sort(_byTime);
}

/// Bir oluşumun çıpadan kaçıncı adım olduğu.
///
/// Kimlik üretiminde kullanılıyor: aynı oluşum iki senkronda aynı bildirim
/// kimliğini almalı, yoksa `sync` her turda kaydı yeniden kurar.
int _stepOf({
  required DateTime at,
  required DateTime remindAt,
  required ReminderCadence cadence,
}) => switch (cadence) {
  ReminderCadence.once => 0,
  ReminderCadence.daily => localDayNumber(at) - localDayNumber(remindAt),
  ReminderCadence.weekly =>
    (localDayNumber(at) - localDayNumber(remindAt)) ~/ 7,
  ReminderCadence.monthly =>
    (at.year * 12 + at.month) - (remindAt.year * 12 + remindAt.month),
  ReminderCadence.yearly => at.year - remindAt.year,
};

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
