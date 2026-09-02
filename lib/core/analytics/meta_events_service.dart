import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Meta'ya giden ölçüm.
///
/// Kapsam bilerek dar: **kurulum/oturum** ve **doğrulanmış satın alma**.
/// Başka hiçbir davranış izlenmiyor — ekran görüntüleme, not sayısı, kullanım
/// süresi yok. Not, fotoğraf ve konum hiçbir olayın parçası değil; uygulamanın
/// geri kalanı hâlâ ağa çıkmıyor.
///
/// Kurulum ve oturum olayını **SDK kendi gönderiyor** (manifest ve plist'teki
/// otomatik loglama bayrakları). Burada bir init çağrısı yok; olsaydı aynı
/// olayı ikinci kez tetiklerdi.
class MetaEvents {
  MetaEvents({FacebookAppEvents? events})
    : _events = events ?? FacebookAppEvents();

  /// Uygulama boyunca tek örnek. Yapıcı yalnızca bir kanal nesnesi kuruyor,
  /// platforma dokunmuyor; ilk erişimde yaratılması bedava.
  static final MetaEvents instance = MetaEvents();

  final FacebookAppEvents _events;

  /// Testte platform kanalı yok; çağrı `MissingPluginException` atardı.
  /// `PurchaseService` de aynı kapıyı kullanıyor.
  bool get _enabled => !Platform.environment.containsKey('FLUTTER_TEST');

  /// Doğrulanmış satın alma.
  ///
  /// Çağıran taraf iki şeyden emin olmalı: satın alma mağazaca doğrulanmış
  /// olmalı ve **yeni** olmalı. Geri yükleme (`restored`) buraya girmemeli;
  /// cihaz değiştiren kullanıcı Meta panelinde ikinci bir satın alma gibi
  /// görünür ve kampanya bütçesi şişmiş bir rakama göre dağıtılır.
  ///
  /// [orderId] verilirse olaya `fb_order_id` olarak eklenir: Meta aynı
  /// kimlikli olayları tekilleştirebiliyor, yani çift sayıma karşı ikinci
  /// bir emniyet.
  Future<void> logPurchase({
    required double amount,
    required String currency,
    String? orderId,
  }) async {
    if (!_enabled) return;

    // Sıfır değerli ya da para birimsiz olay göndermektense hiç göndermemek
    // daha iyi: değer bazlı tekliflerde ortalamayı aşağı çekiyor ve gerçek
    // satın almaların değerini bozuyor.
    if (amount <= 0 || currency.isEmpty) {
      _log('[Meta] Fiyat gelmedi, satın alma olayı gönderilmedi.');
      return;
    }

    try {
      await _events.logPurchase(
        amount: amount,
        currency: currency,
        parameters: {
          if (orderId != null && orderId.isNotEmpty)
            FacebookAppEvents.paramNameOrderId: orderId,
        },
      );
      _log('[Meta] Satın alma: $amount $currency (sipariş=$orderId)');

      // SDK olayları biriktirip toplu yolluyor. Test ederken en çok vakit
      // kaybettiren şey o; debug'da hemen boşalt. Release'de bu satır ikiliye
      // hiç girmiyor.
      if (kDebugMode) await _events.flush();
    } catch (error) {
      // Ölçüm, satın alma akışını asla kesmemeli: kullanıcı parasını ödedi,
      // hakkı açılmalı. Olayın kaybı katlanılabilir, hak kaybı değil.
      _log('[Meta] Satın alma olayı gönderilemedi: $error');
    }
  }

  /// Debug teşhisi: uygulama kimliği ve cihazın anonim kimliği.
  ///
  /// Events Manager → Olayları Test Etme ekranı cihazı bu anonim kimlikle
  /// eşleştiriyor. Release'de gövde tamamen eleniyor.
  Future<void> logDiagnostics() async {
    if (!kDebugMode || !_enabled) return;
    try {
      final appId = await _events.getApplicationId();
      final anonymousId = await _events.getAnonymousId();
      _log('[Meta] App ID: $appId — anonim kimlik: $anonymousId');
    } catch (error) {
      _log('[Meta] Teşhis okunamadı: $error');
    }
  }
}

/// Yalnız geliştirme yapılarında yazar; [kDebugMode] release'de derleme zamanı
/// sabiti `false`, çağrılar ikiliye hiç girmiyor.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}
