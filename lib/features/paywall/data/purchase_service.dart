import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Mağaza bağlantısı: fiyat, satın alma ve geri yükleme.
///
/// Ürün **tek seferlik** (non-consumable). Bu, sunucusuz çalışmayı mümkün
/// kılan şey: abonelik olsaydı yenileme, ödeme başarısızlığı ve iptal
/// durumlarını izlemek için bir arka uç gerekirdi. Tek seferlik satın alma ise
/// kullanıcının mağaza hesabına bağlı kalıcı bir haktır; doğrulamayı işletim
/// sistemi yapar, biz yalnızca sorarız.
///
/// **Doğruluk kaynağı her zaman mağazadır.** Yereldeki kopya sadece önbellek —
/// uygulama açılışında arayüz titremesin diye. Bkz. [unlocked].
class PurchaseService {
  PurchaseService({@visibleForTesting InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  /// Apple ve Google'da aynı kimlik kullanılıyor.
  ///
  /// Abonelikte bu mümkün olmazdı: Apple her plana ayrı kimlik ister. Tek
  /// seferlik üründe iki mağaza da tek kimlikle çalışıyor.
  static const productId = 'latermarkpro';

  static const _storeTimeout = Duration(seconds: 6);
  static const _productAttempts = 3;
  static const _retryBackoff = Duration(milliseconds: 700);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Mağazadan gelen, kullanıcının ülkesine göre biçimlendirilmiş fiyat.
  ///
  /// Kendimiz `'$14.99'` yazamayız: App Store her bölgede farklı bir tutar ve
  /// para birimi gösterir, üstelik biçim de yerele göre değişir (`14,99 €`).
  final price = ValueNotifier<String?>(null);

  /// Ürünün hakkı açık mı.
  ///
  /// `null` = henüz sorulmadı. Ağ hatasında **asla `false`'a düşürülmez**:
  /// bilinmezliği "satın almamış" saymak, parasını ödemiş bir kullanıcıyı
  /// uygulamadan mahrum bırakır. Yalnızca mağaza "sahip değil" dediğinde
  /// kapanır.
  final unlocked = ValueNotifier<bool?>(null);

  /// Mağaza akışı sürerken arayüz bekleme durumuna geçer.
  final busy = ValueNotifier<bool>(false);

  /// Satın alma tamamlandığında haber verir (arayüz kutlama/kapanış için).
  final _purchased = StreamController<void>.broadcast();
  Stream<void> get onPurchased => _purchased.stream;

  bool get _supported => Platform.isIOS || Platform.isAndroid;

  ProductDetails? _product;
  Future<void>? _productLoad;

  /// Açılışta bir kez çağrılır.
  Future<void> start() async {
    if (!_supported) return;

    // Akış dinlemesi sorgudan *önce* kurulmalı: uygulama kapalıyken tamamlanan
    // ya da askıda kalmış bir satın alma, bağlanır bağlanmaz buraya düşer.
    _subscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('Satın alma akışı hatası: $error'),
    );

    try {
      if (!await _store.isAvailable().timeout(_storeTimeout)) {
        // Sessizce dönmek teşhisi imkânsız kılıyordu. Bu satırı görüyorsan
        // sorun bizde değil: simülatörde StoreKit kum havuzu yok, ya da
        // cihazda satın alma kısıtlanmış (Ekran Süresi → İçerik ve Gizlilik).
        debugPrint('[IAP] Mağaza kullanılamıyor (isAvailable=false).');
        return;
      }
    } catch (error) {
      debugPrint('[IAP] Mağazaya ulaşılamadı: $error');
      return;
    }
    // Çalışan ikilinin gerçek paket kimliği. Proje dosyasında doğru görünüp
    // imzalamada başka bir kimlikle çıkan durumları eler; ürün bulunamadığında
    // ilk bakılacak yer burasıdır.
    final info = await PackageInfo.fromPlatform();
    debugPrint(
      '[IAP] paket=${info.packageName} sürüm=${info.version}+${info.buildNumber}',
    );
    debugPrint('[IAP] Mağaza hazır, ürün sorgulanıyor: $productId');
    await _loadProduct();
    await refreshEntitlement();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _purchased.close();
    price.dispose();
    unlocked.dispose();
    busy.dispose();
  }

  Future<void> _loadProduct() {
    if (_product != null) return Future.value();

    final activeLoad = _productLoad;
    if (activeLoad != null) return activeLoad;

    final load = _loadProductWithRetry();
    _productLoad = load;
    return load.whenComplete(() {
      if (identical(_productLoad, load)) _productLoad = null;
    });
  }

  Future<void> _loadProductWithRetry() async {
    for (var attempt = 0; attempt < _productAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryBackoff * attempt);
      }

      try {
        final response = await _store
            .queryProductDetails({productId})
            .timeout(_storeTimeout);

        if (response.notFoundIDs.contains(productId)) {
          // Kesin bir mağaza yanıtı; tekrar denemek sonucu değiştirmez.
          //
          // En sık sebepler, sıklık sırasıyla:
          //  1. App Store Connect'te "Paid Applications" sözleşmesi etkin değil
          //     — bu durumda hata değil, boş liste döner.
          //  2. Ürün henüz "Ready to Submit" durumuna gelmemiş ya da yeni
          //     oluşturulmuş (yayılması saatler alabiliyor).
          //  3. Ürün kimliği veya paket kimliği eşleşmiyor.
          debugPrint(
            '[IAP] Ürün bulunamadı: $productId '
            '(hata=${response.error}, gelen=${response.productDetails.length})',
          );
          return;
        }

        ProductDetails? match;
        for (final product in response.productDetails) {
          if (product.id == productId) {
            match = product;
            break;
          }
        }

        if (match != null) {
          _product = match;
          price.value = match.price;
          debugPrint('[IAP] Ürün geldi: ${match.id} — ${match.price}');
          return;
        }

        final error = response.error;
        if (error != null) {
          debugPrint(
            '[IAP] Ürün okunamadı (${attempt + 1}/$_productAttempts): $error',
          );
        } else {
          debugPrint(
            '[IAP] Sorgu boş döndü (${attempt + 1}/$_productAttempts).',
          );
        }
      } catch (error) {
        debugPrint(
          'Ürün sorgusu başarısız (${attempt + 1}/$_productAttempts): $error',
        );
      }
    }
  }

  /// Mağazaya "bu ürüne sahip mi" diye sorar.
  ///
  /// İade edilmiş bir satın alma mağaza tarafından geri alınır ve burada
  /// kendiliğinden kapanır — arka uç ya da webhook gerekmiyor. Uygulama her
  /// öne geldiğinde çağrılması bu yüzden yeterli.
  Future<void> refreshEntitlement() async {
    if (!_supported) return;
    try {
      // Açılıştaki geçici StoreKit hatası fiyatı kalıcı olarak boş bırakmasın.
      if (_product == null) await _loadProduct();
      await _store.restorePurchases();
    } catch (error) {
      // Ağ yoksa bilinmezlik korunur; önceki değer olduğu gibi kalır.
      debugPrint('Haklar tazelenemedi: $error');
    }
  }

  /// Satın alma akışını başlatır.
  Future<void> buy() async {
    final product = _product;
    if (product == null) {
      await _loadProduct();
      if (_product == null) return;
    }

    busy.value = true;
    try {
      await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
    } catch (error) {
      debugPrint('Satın alma başlatılamadı: $error');
      busy.value = false;
    }
    // Başarı/iptal `purchaseStream` üzerinden gelir; `busy` orada kapanır.
  }

  /// "Satın alımları geri yükle".
  Future<void> restore() async {
    busy.value = true;
    try {
      await _store.restorePurchases();
    } catch (error) {
      debugPrint('Geri yükleme başarısız: $error');
    }
    busy.value = false;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var owned = false;

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == productId) owned = true;

        case PurchaseStatus.error:
          debugPrint('Satın alma hatası: ${purchase.error}');

        case PurchaseStatus.canceled:
          break;
      }

      // ZORUNLU: tamamlanmayan satın alma Android'de üç gün sonra Google
      // tarafından **otomatik iade edilir**, iOS'ta ise kuyrukta kalıp her
      // açılışta yeniden gelir. Hata durumunda bile çağrılmalı.
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }

    busy.value = false;
    if (owned) {
      unlocked.value = true;
      _purchased.add(null);
    } else if (unlocked.value == null) {
      // İlk sorgudan hiçbir sahiplik dönmediyse: satın almamış.
      unlocked.value = false;
    }
  }
}
