import 'dart:math' as math;

/// Ana akıştaki zaman bölümleri, yeniden eskiye doğru.
///
/// Aralıklar saat saymak yerine yerel takvim günlerinden başlar. Böylece yaz
/// saati değişen bir günde "dün" 23 ya da 25 saat sürse de doğru bölümde
/// kalır. Ay sınırları da örneğin 31 Mart'tan bir ay geriye giderken 28/29
/// Şubat'a sıkıştırılır; [Duration] ile yaklaşık 30 gün sayılmaz.
enum NoteAgeGroup {
  today,
  yesterday,
  pastWeek,
  pastMonth,
  pastThreeMonths,
  pastYear,
  older,
}

/// [createdAt] zamanını akıştaki tek bir yaş aralığına yerleştirir.
///
/// Veritabanından UTC bir değer gelirse önce cihazın yerel saatine çevrilir.
/// Gelecek tarihli kayıtlar (yanlış cihaz saati gibi uç durumlar) ayrı ve
/// şaşırtıcı bir bölüm açmak yerine "bugün" altında tutulur.
NoteAgeGroup noteAgeGroupOf(DateTime createdAt, {DateTime? now}) {
  final reference = _asLocal(now ?? DateTime.now());
  final stamp = _asLocal(createdAt);
  final today = DateTime(reference.year, reference.month, reference.day);

  final yesterday = _daysBefore(today, 1);
  final weekAgo = _daysBefore(today, 7);
  final monthAgo = _monthsBefore(today, 1);
  final threeMonthsAgo = _monthsBefore(today, 3);
  final yearAgo = _monthsBefore(today, 12);

  if (!stamp.isBefore(today)) return NoteAgeGroup.today;
  if (!stamp.isBefore(yesterday)) return NoteAgeGroup.yesterday;
  if (!stamp.isBefore(weekAgo)) return NoteAgeGroup.pastWeek;
  if (!stamp.isBefore(monthAgo)) return NoteAgeGroup.pastMonth;
  if (!stamp.isBefore(threeMonthsAgo)) return NoteAgeGroup.pastThreeMonths;
  if (!stamp.isBefore(yearAgo)) return NoteAgeGroup.pastYear;
  return NoteAgeGroup.older;
}

/// Sıralı bir akışı yaş aralıklarına böler.
///
/// Bölümler her zaman [NoteAgeGroup] sırasındadır, boş bölümler üretilmez ve
/// her bölümün içinde girdilerin mevcut sırası aynen korunur.
List<NoteAgeSection<T>> groupNotesByAge<T>(
  Iterable<T> notes, {
  required DateTime Function(T note) createdAtOf,
  DateTime? now,
}) {
  final buckets = <NoteAgeGroup, List<T>>{
    for (final group in NoteAgeGroup.values) group: <T>[],
  };

  for (final note in notes) {
    buckets[noteAgeGroupOf(createdAtOf(note), now: now)]!.add(note);
  }

  return [
    for (final group in NoteAgeGroup.values)
      if (buckets[group]!.isNotEmpty)
        NoteAgeSection(group: group, notes: List.unmodifiable(buckets[group]!)),
  ];
}

class NoteAgeSection<T> {
  const NoteAgeSection({required this.group, required this.notes});

  final NoteAgeGroup group;
  final List<T> notes;
}

DateTime _asLocal(DateTime value) => value.isUtc ? value.toLocal() : value;

DateTime _daysBefore(DateTime day, int count) =>
    DateTime(day.year, day.month, day.day - count);

DateTime _monthsBefore(DateTime day, int count) {
  final monthIndex = day.year * 12 + day.month - 1 - count;
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day.day, lastDay));
}
