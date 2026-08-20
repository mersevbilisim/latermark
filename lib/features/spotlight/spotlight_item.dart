/// Spotlight indeksine giren tek kayıt.
///
/// Alanlar bilinçli olarak dar. Konum, saklama süresi, fotoğrafın kendisi —
/// hiçbiri buraya girmiyor. Spotlight indeksi cihazdan çıkmasa da uygulamanın
/// kendi kabının **dışında** duran bir kopya; oraya yalnızca aramanın
/// çalışması için gereken kadarı yazılıyor.
final class SpotlightItem {
  const SpotlightItem({
    required this.noteId,
    required this.title,
    required this.photoText,
    required this.createdAt,
  });

  final int noteId;

  /// Sonuç satırında görünecek ad: kullanıcının notu, yazmadıysa kaydın
  /// tarihi.
  final String title;

  /// Karedeki yazının **katlanmış** hâli.
  ///
  /// Ham OCR çıktısı hiçbir yerde saklanmıyor; veritabanında yalnızca aramaya
  /// hazırlanmış katlanmış metin var. Katlanmış metin gösterilemez ama
  /// eşleşmeye yarar, o yüzden Spotlight tarafında da **görünmeyen** alana
  /// yazılıyor.
  final String photoText;

  final DateTime createdAt;

  Map<String, Object?> toArguments() => {
    'id': noteId,
    'title': title,
    'text': photoText,
    'createdAtMilliseconds': createdAt.millisecondsSinceEpoch,
  };
}

/// Bir kaydın indekste hangi hâlde durduğunu özetleyen imza.
///
/// Diff bunun üzerinden yürüyor: imza değişmediyse Spotlight'a hiç
/// gidilmiyor — yani hiçbir şeyin değişmediği bir açılışta indeksleme sıfır
/// iş yapıyor.
///
/// Karedeki yazı imzaya metnin kendisiyle değil, DB'ye yazılırken hesaplanan
/// kararlı özetiyle girer. Böylece OCR `A → B` güncellemesi kaçmaz ama sayfa
/// dolusu metin her açılışta belleğe taşınmaz.
///
/// [localeName] yalnızca notu boş olan kayıtlarda imzaya giriyor: başlığı o
/// zaman tarih üretiyor ve tarihin yazımı dile bağlı. Notu olan kayıtlar dil
/// değişince yeniden indekslenmiyor, çünkü başlıkları zaten değişmiyor.
String spotlightFingerprint({
  required String title,
  required DateTime createdAt,
  required String? photoFingerprint,
  required String localeName,
}) =>
    '${_stableHash(title)}:${createdAt.millisecondsSinceEpoch}:'
    '${photoFingerprint ?? '-'}:${title.isEmpty ? localeName : ''}';

/// İçerikten üretilen, çalışmalar arasında **değişmeyen** özet (FNV-1a).
///
/// `String.hashCode` burada kullanılamaz: değeri diske yazılıp bir sonraki
/// açılışta karşılaştırılıyor ve dil, sürümler arasında o hesabın aynı
/// kalacağına dair bir söz vermiyor. Sözün tutulmadığı gün ya her açılış bütün
/// arşivi yeniden indeksler ya da — çok daha kötüsü — hiçbir değişikliği fark
/// etmez; ikisi de sessizce olur.
int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (var i = 0; i < value.length; i++) {
    hash ^= value.codeUnitAt(i);
    // 32 bit'e sığdır: `*` taşarsa JS ve VM farklı sonuç verir.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
