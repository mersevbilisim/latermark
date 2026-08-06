/// Bir notun ne kadar yaşayacağı.
///
/// UYARI: Veritabanında `index` olarak saklanır. Sıralamayı değiştirmeyin;
/// yeni seçenekleri yalnızca sona ekleyin.
enum Retention {
  off(null, 'Kapalı', 'Kapalı'),
  threeDays(Duration(days: 3), '3 Gün', '3 gün sonra silinir'),
  oneWeek(Duration(days: 7), '1 Hafta', '1 hafta sonra silinir');

  const Retention(this.duration, this.label, this.description);

  /// Not oluşturulduktan sonraki yaşam süresi. `null` ise süresiz.
  final Duration? duration;

  /// Seçim kontrolünde görünen kısa etiket.
  final String label;

  /// Detay ekranında görünen açıklama.
  final String description;

  bool get isTimed => duration != null;

  /// Verilen oluşturma anına göre son kullanma zamanı.
  DateTime? expiryFrom(DateTime createdAt) =>
      duration == null ? null : createdAt.add(duration!);
}
