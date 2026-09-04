import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ücretsiz hatırlatma hakkının silinmeyen sayacı.
///
/// Veritabanı uygulamayla birlikte gidiyor. Latermark'ı yalnız hatırlatma için
/// kullanan birinin kaybedecek arşivi yok; onun için silip yeniden kurmak
/// bedelsiz ve kota hiçbir şeye bağlanmamış oluyor. iOS'ta Keychain kayıtları
/// uygulama silindiğinde cihazda kaldığı için bu kapının tek yerel dayanağı o.
///
/// **Yalnız bir sayı** taşınıyor, kayıt kimlikleri değil: kimlikler kuruluma
/// özel, yeniden kurulumdan sonra baştan başlıyor ve eski bir kimlik yeni bir
/// kayda denk gelip ona bedava hak verirdi.
///
/// Android'de karşılığı yok — Keystore uygulama kaldırılınca gidiyor. Orada
/// sayaç yalnız veritabanında; kanal sessizce `null` dönüyor ve davranış
/// eskisi gibi kalıyor.
///
/// Pro açıkken buraya **hiç uğranmıyor**: karar hak kontrolü başlamadan
/// veriliyor.
class ReminderQuotaStore {
  ReminderQuotaStore({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('latermark/reminder_quota');

  final MethodChannel _channel;

  /// Kayıtlı sayı; yoksa ya da okunamazsa `null`.
  ///
  /// Okunamama **sıfır değil**. Sıfır dönmek "hiç hak kullanılmamış" demek
  /// olurdu ve geçici bir hata kullanıcıya üç hak daha verirdi; `null` görende
  /// çağıran yalnız veritabanına güveniyor.
  Future<int?> read() async {
    // Kanal yalnız Runner'ın iOS tarafında kayıtlı. Android/masaüstü/testte
    // messenger'a istek bırakmak ya MissingPlugin üretir ya da başsız test
    // ortamında cevapsız kalabilir; bu platformlarda tasarım gereği taban yok.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    // Her hata yutuluyor ve bu bilinçli. Bu sayaç bir **sertleştirme**;
    // Keychain'e ulaşamamak not kaydetmeyi ya da uygulamayı açmayı
    // bozamaz. Okunamayan sayı `null` dönüyor, çağıran da yalnız
    // veritabanına güveniyor — yani hata hâli kullanıcının lehine.
    try {
      return await _channel.invokeMethod<int>('read');
    } on MissingPluginException {
      // Android, test ve masaüstü: bu platformda silinmeyen sayaç yok.
      return null;
    } on Object catch (error) {
      debugPrint('Hatırlatma kotası okunamadı: $error');
      return null;
    }
  }

  /// Sayıyı yükseltir. Native taraf asla küçültmüyor.
  Future<void> write(int value) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<bool>('write', {'value': value});
    } on MissingPluginException {
      // Sessiz: bu platformda silinmeyen sayaç yok.
    } on Object catch (error) {
      // Yazamamak da kaydı düşüremez; veritabanı doğruyu taşımaya devam
      // ediyor ve bir sonraki yakma aynı sayıyı yeniden gönderiyor.
      debugPrint('Hatırlatma kotası yazılamadı: $error');
    }
  }
}
