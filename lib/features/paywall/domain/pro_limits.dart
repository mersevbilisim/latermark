/// Ücretsiz katmanın sınırları.
///
/// Tek yerde toplu duruyorlar: sayılar koda dağılırsa hem değiştirmek zorlaşır
/// hem de paywall'da yazan sayı ile gerçekte uygulanan sayı zamanla ayrışır.
///
/// Sınırların tasarım kuralı:
///
/// * **Kullanıcının yaptığı hiçbir şey paywall yüzünden silinmez veya
///   gizlenmez.** Sınır yalnızca *yeni* kayda uygulanır; mevcut kareler her
///   zaman açılabilir, düzenlenebilir, dışa aktarılabilir.
/// * **Sınır aynı andadır, toplam değil.** Kümülatif sayaç, otomatik silmeyi
///   kullanan kullanıcıyı elinde sıfır kare varken "dolu" durumuna düşürürdü —
///   yani uygulamayı tasarlandığı gibi kullandığı için cezalandırırdı.
/// * **Ücretsiz katman süresiz kullanılabilir kalır.** Bir kare silmek yer
///   açar; kullanıcı ödemeden de uygulamaya devam edebilir.
abstract final class ProLimits {
  /// Ücretsiz katmanda aynı anda tutulabilecek kare sayısı.
  static const freeNotes = 10;

  /// Kullanıcı bu sayıya ulaştığında yeni çekim paywall'a yönlenir.
  static bool blocksNewNote(int noteCount, {required bool isPro}) =>
      !isPro && noteCount >= freeNotes;

  /// Sınıra yaklaşıldı mı? Deklanşörün altında sayaç göstermek için.
  ///
  /// Kullanıcı duvara habersiz toslamamalı; son birkaç karede sayaç görünür.
  static bool showsCounter(int noteCount, {required bool isPro}) =>
      !isPro && noteCount >= freeNotes - 3;
}
