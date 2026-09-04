import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:latermark/features/paywall/data/purchase_service.dart';

/// Mağazayı taklit eden en küçük yüzey: yalnız akış ve tamamlama.
///
/// `InAppPurchase` genişletilemiyor (özel yapıcı); eklentinin kendi test dikişi
/// olan platform arayüzü değiştiriliyor.
class _FakeStore extends InAppPurchasePlatform {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];

  /// `buyNonConsumable` cevabı: `false` = ödeme ekranı hiç açılmadı.
  bool launches = true;
  int buys = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      ProductDetails(
        id: PurchaseService.productId,
        title: 'Latermark Pro',
        description: '',
        price: '₺199,99',
        rawPrice: 199.99,
        currencyCode: 'TRY',
      ),
    ],
    notFoundIDs: const [],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    return launches;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID ?? '');
  }

  @override
  Future<bool> isAvailable() async => false;

  Future<void> close() => _controller.close();
}

PurchaseDetails _purchased() => PurchaseDetails(
  purchaseID: 'tx-1',
  productID: PurchaseService.productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'app_store',
  ),
  transactionDate: null,
  status: PurchaseStatus.purchased,
)..pendingCompletePurchase = true;

/// Play'in `queryPurchases` cevabından üretilmiş bir kayıt.
///
/// Eklenti bu yolda durumu **toplu olarak** `restored`'a eziyor; ödenmemiş bir
/// satın alma da öyle geliyor. Gerçek durum yalnız `purchaseState`'te.
GooglePlayPurchaseDetails _play(PurchaseStateWrapper state) =>
    GooglePlayPurchaseDetails(
      purchaseID: 'play-1',
      productID: PurchaseService.productId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'google_play',
      ),
      transactionDate: null,
      status: PurchaseStatus.restored,
      billingClientPurchase: PurchaseWrapper(
        orderId: 'order-1',
        packageName: 'com.mersev.latermark',
        purchaseTime: 0,
        purchaseToken: 'token-1',
        signature: '',
        products: const [PurchaseService.productId],
        isAutoRenewing: false,
        originalJson: '',
        isAcknowledged: false,
        purchaseState: state,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('latermark/purchases');
  late _FakeStore store;
  late PurchaseService service;

  /// StoreKit'in sırayla vereceği cevaplar. `null` = kanal hatası.
  /// Liste tükenirse son cevap tekrarlanır.
  late List<bool?> answers;
  late int asked;

  /// Doluysa ilk sorgu burada bekletilir; uçuşta kalmış sorguyu taklit eder.
  Completer<void>? gate;

  /// Kullanıcının "geri yükle" eylemine StoreKit'in vereceği cevap.
  late bool? restoreAnswer;

  setUp(() {
    asked = 0;
    answers = [];
    gate = null;
    restoreAnswer = null;

    // `InAppPurchase.instance` ilk erişimde hedef platforma göre gerçek
    // eklentiyi kaydediyor ve Android dalı canlı bir BillingClient kanalı
    // açmaya çalışıyor. Kayıt yapılmayan bir hedef seçilince sahte arayüz
    // yerinde kalıyor.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    store = _FakeStore();
    InAppPurchasePlatform.instance = store;
    service = PurchaseService(
      store: InAppPurchase.instance,
      platform: TargetPlatform.iOS,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'restoreProEntitlement') return restoreAnswer;
          if (call.method != 'currentProEntitlement') return null;
          final index = asked < answers.length ? asked : answers.length - 1;
          asked++;
          if (index == 0 && gate != null) await gate!.future;
          final answer = answers[index];
          if (answer == null) throw PlatformException(code: 'unavailable');
          return answer;
        });
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await store.close();
  });

  /// `Transaction.currentEntitlements`, özellikle uygulama dışında kullanılan
  /// bir promosyon kodundan sonra bir an geride kalabiliyor. Tek okumaya bakıp
  /// hakkı kapatmak, kullanıcıyı "Satın alımları geri yükle"ye dokunmaya
  /// mecbur bırakıyordu.
  test(
    'StoreKit geriden gelirse satın alma yeniden sorularak teyit edilir',
    () async {
      // Açılış: hak yok. Teyidin ilk okuması da henüz görmüyor, ikincisi görüyor.
      answers = [false, false, true];

      await service.start();
      expect(service.unlocked.value, isFalse);

      store.emit([_purchased()]);
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(service.unlocked.value, isTrue);
      expect(asked, greaterThan(2), reason: 'tek okumayla yetinilmemeli');
      expect(store.completed, contains('tx-1'));
      expect(service.busy.value, isFalse);

      await service.dispose();
    },
  );

  /// Uygulama öne gelirken başlayan hak sorgusu, satın alma tam o sırada
  /// düştüğünde işlemi henüz görmemiş olabiliyor. Teyit o eski cevabı
  /// devralmamalı; cevap sonradan gelse de üstüne yazmamalı.
  test('uçuştaki eski sorgu teyit edilmiş satın almayı bozmuyor', () async {
    answers = [false, true];
    gate = Completer<void>();

    // Açılış sorgusu kapıda bekliyor; `start` bilinçli olarak beklenmiyor.
    unawaited(service.start());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.unlocked.value, isNull);

    store.emit([_purchased()]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      service.unlocked.value,
      isTrue,
      reason: 'teyit kendi sorgusunu yapar',
    );

    // Eski sorgu şimdi "hak yok" diye dönüyor.
    gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      service.unlocked.value,
      isTrue,
      reason: 'eski cevap yeni teyidin üstüne yazamaz',
    );

    await service.dispose();
  });

  /// Mağaza "satın alındı" derken tek bir `false` okumasıyla hakkı kapatmak,
  /// parasını ödemiş kullanıcıyı uygulamadan mahrum bırakmak olurdu.
  test('teyit hiç gelmezse hak false yazılmaz — bilinmez kalır', () async {
    // Açılış kanal hatası veriyor: hak "bilinmiyor" olarak başlıyor.
    answers = [null, false];

    await service.start();
    expect(service.unlocked.value, isNull);

    store.emit([_purchased()]);
    await Future<void>.delayed(const Duration(seconds: 5));

    expect(service.unlocked.value, isNull);
    expect(service.busy.value, isFalse);

    await service.dispose();
  });

  /// İade edilen bir satın alma hakkı **kapatabilmeli**. Teyit koruması
  /// yalnızca teyit sırasında uçuşta olan sorguları susturuyor; sonradan
  /// başlayan her sorgu gerçeği yine bildirir.
  test('iade sonrası hak kapanıyor', () async {
    answers = [true];

    await service.start();
    expect(service.unlocked.value, isTrue);

    // Kullanıcı iade aldı: mağaza artık sahip değil diyor.
    answers = [false];
    asked = 0;
    await service.refreshEntitlement();

    expect(service.unlocked.value, isFalse, reason: 'iade hakkı kapatmalı');

    await service.dispose();
  });

  /// Teyit edilmiş bir satın almadan *sonra* başlayan sorgu da hakkı
  /// kapatabilmeli — koruma kalıcı bir kilit değil.
  test('teyitten sonraki sorgu iadeyi yine bildirebiliyor', () async {
    answers = [false, true];

    await service.start();
    store.emit([_purchased()]);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(service.unlocked.value, isTrue);

    answers = [false];
    asked = 0;
    await service.refreshEntitlement();

    expect(service.unlocked.value, isFalse);

    await service.dispose();
  });

  /// "Satın alımları geri yükle" yolu `AppStore.sync` sonrası kendi kesin
  /// cevabını yazıyor; teyit sayacı ona karışmıyor.
  test('geri yükleme hakkı açıyor', () async {
    answers = [false];

    await service.start();
    expect(service.unlocked.value, isFalse);

    var syncs = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'restoreProEntitlement') {
            syncs++;
            return true;
          }
          return false;
        });

    final restored = await service.restore();

    expect(restored, isTrue);
    expect(syncs, 1);
    expect(service.unlocked.value, isTrue);
    expect(service.busy.value, isFalse);

    await service.dispose();
  });

  /// Google, `queryPurchases` sonuçlarında ödenmemiş satın almaları da
  /// döndürüyor ve hak yalnız `PURCHASED` durumunda verilmeli. Eklenti bu
  /// yolda durumu toplu olarak `restored`'a ezdiği için `PurchaseStatus`
  /// tek başına kanıt değil.
  test('ödemesi beklenen Play kaydı Pro açmıyor', () async {
    final android = PurchaseService(
      store: InAppPurchase.instance,
      platform: TargetPlatform.android,
    );

    // Akış aboneliği `start` içinde kuruluyor.
    await android.start();
    store.emit([_play(PurchaseStateWrapper.pending)]);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(android.unlocked.value, isFalse);
    // Ödenmemiş kayıt onaylanmaz da: Play bekleyen satın almanın
    // acknowledge edilmesini kabul etmiyor.
    expect(store.completed, isEmpty);

    await android.dispose();
  });

  test('ödemesi tamamlanmış Play kaydı Pro açıyor', () async {
    final android = PurchaseService(
      store: InAppPurchase.instance,
      platform: TargetPlatform.android,
    );

    await android.start();
    store.emit([_play(PurchaseStateWrapper.purchased)]);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(android.unlocked.value, isTrue);
    expect(store.completed, contains('play-1'));

    await android.dispose();
  });

  /// Teyit yolundaki nesil koruması geri yüklemede yoktu: kullanıcı
  /// "geri yükle"ye basıp hakkını açıyor, uçuşta kalmış eski bir sorgu
  /// saniyeler sonra onu kapatıyordu. Kapanış artık gerçek bir downgrade
  /// temizliği demek.
  test('geri yükleme uçuştaki eski sorgunun altında kalmıyor', () async {
    answers = [false];
    gate = Completer<void>();
    restoreAnswer = true;

    unawaited(service.start());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.unlocked.value, isNull);

    expect(await service.restore(), isTrue);
    expect(service.unlocked.value, isTrue);

    // Eski sorgu şimdi "hak yok" diye dönüyor.
    gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      service.unlocked.value,
      isTrue,
      reason: 'eski cevap yeni kararı ezemez',
    );

    await service.dispose();
  });

  /// `buyNonConsumable` dönüşü **satın almanın sonucu değil**, ödeme ekranının
  /// açılıp açılmadığı. Android'de `false` dönebiliyor ve o durumda akışa
  /// hiçbir olay düşmüyor: dönüş yok sayıldığında ekran sonsuza kadar
  /// "işleniyor" durumunda kalıyordu.
  test('ödeme ekranı açılamazsa bekleme durumu kapanıyor', () async {
    store.launches = false;

    await service.buy();

    expect(store.buys, 1);
    expect(service.busy.value, isFalse);

    await service.dispose();
  });

  test('ödeme ekranı açıldıysa sonuç akıştan beklenir', () async {
    // Açılış "hak yok" diyor; teyit sorgusu satın almayı görüyor.
    answers = [false, true];
    await service.start();
    store.launches = true;

    await service.buy();

    // Akış başladı: `busy` kapanışı olaya ait.
    expect(service.busy.value, isTrue);

    store.emit([_purchased()]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(service.busy.value, isFalse);

    await service.dispose();
  });

  /// Debug hakkı aynı oturumda kapatıldığında mağaza akışı yeniden kuruluyor;
  /// o çağrının ikinci bir dinleyici bırakmaması gerekiyor. (Anahtarın kendisi
  /// testlerde kapalı: `DebugEntitlement.available` FLUTTER_TEST altında
  /// bilinçli olarak `false`.)
  test('ikinci start ikinci dinleyici bırakmıyor', () async {
    answers = [false];
    await service.start();
    await service.start();

    store.emit([_purchased()]);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(store.completed, [
      'tx-1',
    ], reason: 'olay iki kez işlenirse tamamlama da ikizlenir');

    await service.dispose();
  });
}
