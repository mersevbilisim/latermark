/// Bir notun ne kadar yaşayacağı.
///
/// UYARI: Veritabanında `index` olarak saklanır. Sıralamayı değiştirmeyin;
/// yeni seçenekleri yalnızca sona ekleyin.
enum Retention {
  off(null),
  threeDays(Duration(days: 3)),
  oneWeek(Duration(days: 7)),

  /// Kullanıcının kendi belirlediği süre (Pro).
  ///
  /// Süresi burada değil, [RetentionChoice.customMinutes] içinde taşınır —
  /// bir enum sabiti çalışma anında değişen bir değeri tutamaz.
  custom(null);

  const Retention(this.duration);

  /// Hazır seçeneklerin yaşam süresi. `null` ise süresiz ya da özel.
  final Duration? duration;

  bool get isCustom => this == Retention.custom;
}

/// Saklama tercihinin tam hâli: hazır seçenek + özel süre.
///
/// [Retention] tek başına yetmiyor çünkü "özel" seçildiğinde süre kullanıcıdan
/// geliyor. İkisini tek bir değer nesnesinde taşımak, çağrı yerlerinde
/// "hangisi geçerli" sorusunu ortadan kaldırıyor.
class RetentionChoice {
  const RetentionChoice(this.retention, {this.customMinutes = 0});

  const RetentionChoice.off() : this(Retention.off);

  /// Dakika cinsinden özel süre. Yalnızca [Retention.custom] için anlamlı.
  factory RetentionChoice.custom(int minutes) =>
      RetentionChoice(Retention.custom, customMinutes: minutes);

  final Retention retention;
  final int customMinutes;

  /// Özel sürenin makul sınırları: bir saatten kısa bir "otomatik sil" pratik
  /// olarak kullanıcının kaydı açmasına bile vakit bırakmaz; bir yıldan uzağı
  /// ise "kapalı"dan ayırt edilemez.
  static const minCustomMinutes = 60;
  static const maxCustomMinutes = 525600;

  /// Yürürlükteki yaşam süresi. `null` ise süresiz.
  Duration? get duration {
    if (retention.isCustom) {
      if (customMinutes <= 0) return null;
      return Duration(minutes: customMinutes);
    }
    return retention.duration;
  }

  bool get isTimed => duration != null;

  /// Verilen oluşturma anına göre son kullanma zamanı.
  DateTime? expiryFrom(DateTime createdAt) {
    final life = duration;
    return life == null ? null : createdAt.add(life);
  }

  RetentionChoice copyWith({Retention? retention, int? customMinutes}) =>
      RetentionChoice(
        retention ?? this.retention,
        customMinutes: customMinutes ?? this.customMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is RetentionChoice &&
      other.retention == retention &&
      other.customMinutes == customMinutes;

  @override
  int get hashCode => Object.hash(retention, customMinutes);
}
