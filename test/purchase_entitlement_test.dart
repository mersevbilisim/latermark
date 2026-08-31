import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:latermark/features/paywall/data/purchase_service.dart';

/// Mağazayı taklit eden en küçük yüzey: yalnız akış ve tamamlama.
///
/// `InAppPurchase` genişletilemiyor (özel yapıcı); eklentinin kendi test dikişi
/// olan platform arayüzü değiştiriliyor.
class _FakeStore extends InAppPurchasePlatform {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

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

  setUp(() {
    asked = 0;
    answers = [];
    gate = null;

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
  test('StoreKit geriden gelirse satın alma yeniden sorularak teyit edilir',
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
  });

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
    expect(service.unlocked.value, isTrue, reason: 'teyit kendi sorgusunu yapar');

    // Eski sorgu şimdi "hak yok" diye dönüyor.
    gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(service.unlocked.value, isTrue,
        reason: 'eski cevap yeni teyidin üstüne yazamaz');

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
}
