import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'debug_entitlement.dart';

/// Teşhis kaydı — yalnız geliştirme yapılarında.
///
/// `debugPrint` adının aksine release'de de yazar: mağaza akışının paket
/// kimliği, sürümü ve hata metinleri üretimde cihaz loglarına düşüyordu.
/// Kimse için sır değil ama ödeme akışının teşhisini bedavaya dağıtmanın da
/// bir sebebi yok. [kDebugMode] release'de derleme zamanı sabiti `false`;
/// çağrılar ikiliye hiç girmiyor.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

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
  PurchaseService({
    @visibleForTesting InAppPurchase? store,
    @visibleForTesting TargetPlatform? platform,
  }) : _storeInjected = store != null,
       _storeOverride = store,
       _platformOverride = platform;

  final InAppPurchase? _storeOverride;
  final bool _storeInjected;

  /// Mağaza dalı iki platformda farklı: iOS hakkı StoreKit'e teyit ettirir,
  /// Android restore listesine bakar. Test bu dalı seçebilsin diye ayrıldı;
  /// üretimde her zaman gerçek platform okunur.
  final TargetPlatform? _platformOverride;

  bool get _isIos => _platformOverride == null
      ? Platform.isIOS
      : _platformOverride == TargetPlatform.iOS;

  bool get _isAndroid => _platformOverride == null
      ? Platform.isAndroid
      : _platformOverride == TargetPlatform.android;

  // `InAppPurchase.instance` Android'de oluşturulurken BillingClient
  // bağlantısını başlatabilir. Test/desteklenmeyen platform kapısından önce
  // dokunmamak, yalnız sorguları değil eklentinin kendisini de gerçekten lazy
  // tutar.
  InAppPurchase get _store => _storeOverride ?? InAppPurchase.instance;

  /// Apple ve Google'da aynı kimlik kullanılıyor.
  ///
  /// Abonelikte bu mümkün olmazdı: Apple her plana ayrı kimlik ister. Tek
  /// seferlik üründe iki mağaza da tek kimlikle çalışıyor.
  static const productId = 'latermarkpro';

  static const _storeTimeout = Duration(seconds: 6);
  static const _productAttempts = 3;
  static const _retryBackoff = Duration(milliseconds: 700);

  /// Satın alma sonrası StoreKit'in kendi kaydına yetişmesi için verilen pay.
  static const _confirmAttempts = 4;
  static const _confirmBackoff = Duration(milliseconds: 450);
  static const _entitlementChannel = MethodChannel('latermark/purchases');

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Kaç kez satın alma teyit edildi.
  ///
  /// Sıradan bir hak sorgusu sürerken bir satın alma teyit edilebiliyor. O
  /// sorgu sonuçlandığında elindeki fotoğraf artık eski; `false` yazarsa az
  /// önce açılan hakkı kapatır. Sayaç, cevabın hangi çağa ait olduğunu söyler.
  int _confirmations = 0;
  Future<bool?>? _entitlementRefresh;
  Completer<bool?>? _androidRestoreResult;
  Future<bool?>? _restoreOperation;

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

  bool get _supported =>
      (_storeInjected || !Platform.environment.containsKey('FLUTTER_TEST')) &&
      (_isIos || _isAndroid);

  ProductDetails? _product;
  Future<void>? _productLoad;

  /// Açılışta bir kez çağrılır.
  Future<void> start() async {
    // Debug anahtarı açıksa hak daha ilk kareden önce açılır; mağaza akışını
    // yine de kurmanın anlamı yok, cevabı zaten kullanılmayacak.
    if (_debugEntitlement() != null) return;
    if (!_supported) return;

    // Akış dinlemesi sorgudan *önce* kurulmalı: uygulama kapalıyken tamamlanan
    // ya da askıda kalmış bir satın alma, bağlanır bağlanmaz buraya düşer.
    _subscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => _log('Satın alma akışı hatası: $error'),
    );

    // Fiyat kataloğu ve ödeme kullanılabilirliği, mevcut hakkı okumaktan ayrı
    // konular. Özellikle iOS'ta satın alma kısıtlı olsa bile StoreKit 2'nin
    // doğrulanmış currentEntitlements sonucu stale/elle değiştirilmiş cache'i
    // düzeltebilir.
    await _refreshPlatformEntitlement();

    try {
      if (!await _store.isAvailable().timeout(_storeTimeout)) {
        // Sessizce dönmek teşhisi imkânsız kılıyordu. Bu satırı görüyorsan
        // sorun bizde değil: simülatörde StoreKit kum havuzu yok, ya da
        // cihazda satın alma kısıtlanmış (Ekran Süresi → İçerik ve Gizlilik).
        _log('[IAP] Mağaza kullanılamıyor (isAvailable=false).');
        return;
      }
    } catch (error) {
      _log('[IAP] Mağazaya ulaşılamadı: $error');
      return;
    }
    // Çalışan ikilinin gerçek paket kimliği. Proje dosyasında doğru görünüp
    // imzalamada başka bir kimlikle çıkan durumları eler; ürün bulunamadığında
    // ilk bakılacak yer burasıdır.
    final info = await PackageInfo.fromPlatform();
    _log(
      '[IAP] paket=${info.packageName} sürüm=${info.version}+${info.buildNumber}',
    );
    _log('[IAP] Mağaza hazır, ürün sorgulanıyor: $productId');
    await _loadProduct();
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
          _log(
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
          _log('[IAP] Ürün geldi: ${match.id} — ${match.price}');
          return;
        }

        final error = response.error;
        if (error != null) {
          _log(
            '[IAP] Ürün okunamadı (${attempt + 1}/$_productAttempts): $error',
          );
        } else {
          _log('[IAP] Sorgu boş döndü (${attempt + 1}/$_productAttempts).');
        }
      } catch (error) {
        _log(
          'Ürün sorgusu başarısız (${attempt + 1}/$_productAttempts): $error',
        );
      }
    }
  }

  /// Mağazaya "bu ürüne sahip mi" diye sorar.
  ///
  /// iOS'ta StoreKit 2'nin doğrulanmış `currentEntitlements` dizisi kesin bir
  /// bool verir; böylece hiç hak olmaması da (boş dizi) yerel cache'i kapatır.
  /// Android'de restore sorgusunun tam listesi aynı işi görür. Mağaza/kanal
  /// hatası `false` değildir: son doğrulanmış çevrimdışı cache korunur.
  Future<void> refreshEntitlement() async {
    if (_debugEntitlement() != null) return;
    if (!_supported) return;
    await checkEntitlement();
    // Açılıştaki geçici mağaza hatası fiyatı kalıcı olarak boş bırakmasın.
    if (_product == null) await _loadProduct();
  }

  /// Yalnızca güncel hakkı doğrular ve kesin sonucu çağırana döndürür.
  ///
  /// Widget gibi uygulama dışından gelen Pro eylemleri, açılıştaki yerel
  /// önbelleği kullanmadan önce bu sonucu bekler. `null`, mağazaya o anda
  /// ulaşılamadığı ve son doğrulanmış cache'in korunması gerektiği anlamına
  /// gelir. Eşzamanlı açılış sorgusu varsa aynı future paylaşılır.
  Future<bool?> checkEntitlement() async {
    final forced = _debugEntitlement();
    if (forced != null) return forced;
    if (!_supported) return null;
    return _refreshPlatformEntitlement();
  }

  /// Geliştirme anahtarı açıksa mağazayı atlayan kesin cevap; kapalıysa `null`.
  ///
  /// Cevap dönerken [unlocked] da tazeleniyor: hakkı okuyan her yol (açılış,
  /// öne gelme, widget'tan gelen Pro eylemi) buradan geçtiği için tek noktada
  /// uzlaştırmak, "bir yerde açık bir yerde kapalı" durumunu imkânsız kılıyor.
  bool? _debugEntitlement() {
    if (!DebugEntitlement.forced) return null;
    unlocked.value = true;
    return true;
  }

  /// Debug derlemesinde Pro hakkını mağazayı atlayarak açar veya kapatır.
  ///
  /// Kapatırken son mağaza cevabı da unutuluyor (`null`). `false` yazmak yanlış
  /// olurdu: gerçekten satın almış bir cihazda bu, bir sonraki ayar yayınında
  /// hakkın kapalı olarak önbelleğe alınması demekti. `null` "bilinmiyor"
  /// demek; bir sonraki [refreshEntitlement] gerçek cevabı yine getirir.
  Future<void> setDebugPro(bool value) async {
    if (!DebugEntitlement.available) return;
    await DebugEntitlement.set(value);
    unlocked.value = value ? true : null;
  }

  Future<bool?> _refreshPlatformEntitlement() {
    final forced = _debugEntitlement();
    if (forced != null) return Future<bool?>.value(forced);

    final activeRefresh = _entitlementRefresh;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _isIos ? _readIosEntitlement() : _readAndroidEntitlement();
    _entitlementRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_entitlementRefresh, refresh)) {
        _entitlementRefresh = null;
      }
    });
  }

  /// StoreKit'e sorar ve **hiçbir şeyi değiştirmez**.
  ///
  /// Yazma işi çağırana bırakılıyor: açılış ve öne gelme yollarında bir `false`
  /// cevabı hakkı kapatmalı, satın alma doğrulamasında ise kapatmamalı.
  Future<bool?> _queryIosEntitlement() async {
    try {
      final owned = await _entitlementChannel
          .invokeMethod<bool>('currentProEntitlement')
          .timeout(_storeTimeout);
      if (owned == null) {
        throw const FormatException('StoreKit hak sonucu boş döndü.');
      }
      return owned;
    } catch (error) {
      // Kanal/StoreKit doğrulama hatası sahip değil demek değildir. Son kesin
      // değere ve Drift cache'ine dokunma; çevrimdışı ödeyen kullanıcı düşmez.
      _log('iOS Pro hakkı doğrulanamadı: $error');
      return null;
    }
  }

  Future<bool?> _readIosEntitlement() async {
    final era = _confirmations;
    final owned = await _queryIosEntitlement();
    // Sorgu sürerken bir satın alma teyit edildiyse bu cevap ondan eski.
    // Sonradan başlayan sorgular etkilenmez: iade gibi gerçek bir kapanışı
    // yine bildirebilirler.
    if (owned != null && era == _confirmations) unlocked.value = owned;
    return owned;
  }

  /// Mağazanın onayladığı bir satın almayı StoreKit'e teyit ettirir.
  ///
  /// Ayrı durmasının iki sebebi var, ikisi de gerçek bir hatadan geliyor.
  ///
  /// **Uçuştaki sorguya ortak olmuyor.** `_refreshPlatformEntitlement` aynı anda
  /// süren sorguyu paylaşıyor; uygulama öne gelirken başlayan sorgu işlem daha
  /// ulaşmadan fotoğrafını çektiyse, satın alma o eski `false` cevabını
  /// devralıyordu.
  ///
  /// **Tek bir `false` cevabını son söz saymıyor.** `currentEntitlements`,
  /// özellikle uygulama dışında kullanılan bir promosyon kodundan sonra bir an
  /// geride kalabiliyor. Mağaza "satın alındı" derken tek okumaya bakıp hakkı
  /// kapatmak, kullanıcıyı "Satın alımları geri yükle"ye dokunmaya mecbur
  /// bırakıyordu.
  ///
  /// Doğrulanamazsa [unlocked] **olduğu gibi bırakılır**. `false` yazmak,
  /// mağazanın az önce onayladığı bir satın alımı silmek olurdu.
  Future<bool> _confirmIosPurchase() async {
    for (var attempt = 0; attempt < _confirmAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_confirmBackoff * attempt);
      }
      if (await _queryIosEntitlement() == true) {
        _confirmations++;
        unlocked.value = true;
        return true;
      }
    }
    _log('[IAP] Satın alma StoreKit tarafından teyit edilemedi.');
    return false;
  }

  /// Kullanıcının açık "geri yükle" eylemi için App Store ile zorunlu
  /// senkronizasyon yapar ve ardından güncel hakkı döndürür.
  ///
  /// Genel `in_app_purchase.restorePurchases()` StoreKit 2 yolunda yalnızca
  /// cihazdaki `currentEntitlements` listesini yeniden yayıyor; `AppStore.sync`
  /// çağırmıyor. Kullanıcı yeni bir cihaza geçtiğinde yerel liste henüz güncel
  /// olmayabilir. Senkron native kanalda yapılır; olası Apple hesabı istemi
  /// kullanıcı tarafından yanıtlanacağı için açılış sorgusundaki altı saniyelik
  /// timeout burada bilinçli olarak kullanılmaz.
  Future<bool?> _restoreIosEntitlement() async {
    try {
      final owned = await _entitlementChannel.invokeMethod<bool>(
        'restoreProEntitlement',
      );
      if (owned == null) {
        throw const FormatException('StoreKit geri yükleme sonucu boş döndü.');
      }
      unlocked.value = owned;
      return owned;
    } catch (error) {
      // İptal, bağlantı ve doğrulama hataları "satın almamış" değildir. Son
      // kesin önbelleği koru ve arayüzün hata sonucunu göstermesine izin ver.
      _log('iOS Pro geri yükleme doğrulanamadı: $error');
      return null;
    }
  }

  Future<bool?> _readAndroidEntitlement() async {
    final activeRestore = _androidRestoreResult;
    if (activeRestore != null) return activeRestore.future;

    final result = Completer<bool?>();
    _androidRestoreResult = result;
    try {
      // Android eklentisi sorgu başarılıysa mevcut satın alımların tamamını,
      // hiç satın alım yoksa da boş listeyi purchaseStream'e gönderir.
      await _store.restorePurchases().timeout(_storeTimeout);
      return await result.future.timeout(_storeTimeout);
    } catch (error) {
      _log('Android Pro hakkı doğrulanamadı: $error');
      return null;
    } finally {
      if (identical(_androidRestoreResult, result)) {
        _androidRestoreResult = null;
      }
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
      _log('Satın alma başlatılamadı: $error');
      busy.value = false;
    }
    // Başarı/iptal `purchaseStream` üzerinden gelir; `busy` orada kapanır.
  }

  /// "Satın alımları geri yükle".
  ///
  /// `true` Pro hakkının bulunduğunu, `false` mağazanın kesin olarak önceki
  /// bir satın alma bulamadığını, `null` ise sonucun mağaza/kanal hatası
  /// yüzünden doğrulanamadığını anlatır. Arayüz bu ayrımı kullanır; aksi hâlde
  /// hızlı dönen boş ve hatalı sonuçların ikisi de "dokunmadı" gibi görünür.
  Future<bool?> restore() {
    final active = _restoreOperation;
    if (active != null) return active;

    late final Future<bool?> operation;
    operation = _performRestore().whenComplete(() {
      if (identical(_restoreOperation, operation)) {
        _restoreOperation = null;
      }
    });
    _restoreOperation = operation;
    return operation;
  }

  Future<bool?> _performRestore() async {
    busy.value = true;
    try {
      if (_isIos) {
        return await _restoreIosEntitlement();
      }
      return await _refreshPlatformEntitlement();
    } catch (error) {
      _log('Geri yükleme başarısız: $error');
      return null;
    } finally {
      busy.value = false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var owned = false;
    var hasError = false;

    final androidRestore = _isAndroid ? _androidRestoreResult : null;

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == productId) {
            owned = true;
          }

        case PurchaseStatus.error:
          hasError = true;
          _log('Satın alma hatası: ${purchase.error}');

        case PurchaseStatus.canceled:
          break;
      }

      // ZORUNLU: tamamlanmayan satın alma Android'de üç gün sonra Google
      // tarafından **otomatik iade edilir**, iOS'ta ise kuyrukta kalıp her
      // açılışta yeniden gelir. Hata durumunda bile çağrılmalı.
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } catch (error) {
          // Tamamlama/acknowledge hatası satın alımın sahte olduğunu göstermez;
          // sonraki açılışta tekrar teslim edilir. Hak sonucunu kaybetme.
          _log('Satın alma tamamlanamadı: $error');
        }
      }
    }

    if (_isIos) {
      // StoreKit satın alma sonucu `VerificationResult` taşır; genel Flutter
      // akışı bunun doğrulanmış olup olmadığını burada garanti etmez. Ürünü
      // ancak native currentEntitlements sorgusu doğruladıktan sonra aç.
      //
      // Teyit boyunca `busy` açık kalıyor: aksi hâlde ödeme biter bitmez ekran
      // bir an "kilitli" hâline dönüyor, hak birkaç yüz milisaniye sonra
      // geliyordu.
      if (owned) {
        final verified = await _confirmIosPurchase();
        busy.value = false;
        if (verified) {
          // Ölçüm ancak StoreKit hakkı teyit ettikten sonra: doğrulanmamış
          // ya da iade edilmiş bir makbuz Meta'ya gerçek gelir gibi görünür.
          _purchased.add(null);
        }
        return;
      }
      busy.value = false;
      return;
    }

    busy.value = false;

    if (androidRestore != null && !androidRestore.isCompleted) {
      if (hasError) {
        // Hatalı liste kesin bir sahiplik cevabı değildir; cache korunur.
        androidRestore.complete(null);
      } else {
        unlocked.value = owned;
        androidRestore.complete(owned);
      }
      return;
    }

    if (owned) {
      unlocked.value = true;
      _purchased.add(null);
    } else if (unlocked.value == null) {
      // İlk sorgudan hiçbir sahiplik dönmediyse: satın almamış.
      unlocked.value = false;
    }
  }
}
