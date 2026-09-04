> **ARŞİV — 2 Eylül 2026'da entegrasyon projeden çıkarıldı.**
>
> Kod, bağımlılık ve native yapılandırma tamamen söküldü; mağaza sayfası
> yeniden "Veri Toplanmıyor" diyor. Sebep gizlilik kaygısı değil **aritmetik**:
> Meta'nın optimizasyonu haftalık belirli sayıda dönüşüm görmeden öğrenmiyor
> ve o hacmi üretecek bütçe yoktu. SDK'nın tek işi reklamı doğru kişiye
> göstermek; reklam yoksa ödediği tek şey gizlilik etiketi oluyordu.
>
> **Bu belge duruyor çünkü karar geri alınabilir.** Reklam vermeye gerçekten
> karar verildiği gün buradaki her şey — iki şalter ayrımı, ATT'nin bedeli,
> platformlar arası fark, çift sayma tuzakları — yeniden gerekecek. Geri
> takmak yarım saatlik iş: iki çağrı yeri, bir `pubspec` satırı, plist ve
> manifest anahtarları.
>
> Geri takılırsa `test/meta_sdk_config_test.dart` de geri gelmeli; yer
> tutucuların sessizce yayınlanmasını engelleyen tek şey oydu.

---

# Meta SDK Playbook

Kaynak: Howl'daki kurulumun kaydı (1 Eylül 2026, Meta App ID `2035684263756792`).
Bu belge o kurulumu **Latermark'a uyarlanmış** hâliyle tutar.

**Durum: tamamlandı (1 Eylül 2026).** Kod, yapılandırma ve gerçek değerler
yerinde; `test/meta_sdk_config_test.dart` yeşil.

App ID girilirken `fb<APPID>` URL şeması yer tutucu kalmıştı ve testi bu
yakaladı — üç yerin de aynı kimliği taşıması gerektiğinin canlı örneği.

**Kapsam:** yalnızca **install** ve **purchase**. Howl'daki `InitiatedCheckout`
sinyali bu uygulamada yok; paywall düğmesine kasten bağlanmadı.

### Yer tutucuyu değiştirmek

İki dosya, üç yer. Üçü de aynı App ID'yi taşımalı, yoksa test kırmızı kalır.

| Dosya | Anahtar |
| --- | --- |
| `android/app/src/main/res/values/facebook.xml` | `facebook_app_id` |
| `android/app/src/main/res/values/facebook.xml` | `facebook_client_token` |
| `ios/Runner/Info.plist` | `FacebookAppID` |
| `ios/Runner/Info.plist` | `FacebookClientToken` |
| `ios/Runner/Info.plist` | `CFBundleURLSchemes` → `fb<APPID>` |

Sonra `flutter test test/meta_sdk_config_test.dart` — yeşil kalmalı.

---

## 0. Latermark'ta Howl'dan farklı olan üç şey

Playbook'u olduğu gibi kopyalamayı engelleyen farklar ve her birine ne yapıldığı.

### 0.1 Uygulama başka hiçbir sebeple ağa çıkmıyor

`AndroidManifest.xml` içinde **INTERNET izni yoktu**; yalnız
`src/debug/AndroidManifest.xml` içinde, Flutter aracı için duruyordu. Yayınlanan
APK gerçekten ağa çıkmıyordu.

İzin artık yayın manifestinde, gerekçesiyle birlikte açıkça duruyor. Aynı
manifestte `RECORD_AUDIO`'yu "mahremiyet iddiasını zedeliyor" diye çıkaran blok
var; bu değişiklik onun tersi yönde, o yüzden niyet yorumda yazılı bırakıldı.
Play sayfasındaki izin listesi ve veri güvenliği formu ilk kez değişiyor
(bkz. §6).

### 0.2 Uygulama içindeki metin bunun aksini söylüyordu

`yourDataSafetyAnswer` (Ayarlar → *Latermark & Your Data*) 10 dilde şunu
diyordu:

> "…your content never leaves it—not for analytics, crash reports, or usage
> statistics."

SDK eklendiği an bu cümle yanlış olurdu. **10 dilde yeniden yazıldı:** cihazda
kalma iddiası korundu, istisna açıkça adlandırıldı — Meta'ya yalnız kurulum ve
satın alma bildiriliyor, ikisi de notu/fotoğrafı/konumu içermiyor.

Aynı cümle gizlilik politikası sayfasında da geçiyorsa orası elle
güncellenmeli; site metni mağaza formundan bağımsız kontrol ediliyor.

### 0.3 Satın alma tek seferlik — restore çift sayım riski

Howl abonelik satıyor; Latermark tek seferlik Pro satıyor. `PurchaseStatus.
restored` kullanıcı her cihaz değiştirdiğinde yeniden geliyor.

`onPurchased` stream'ine bağlanmak yanlış olurdu: o stream restore'da da
tetikleniyor (`owned` bayrağı iki durumda da `true`). Bu yüzden
`_onPurchases` içinde ayrı bir `fresh` değişkeni tutuluyor — yalnız
`PurchaseStatus.purchased` onu dolduruyor, ölçüm de yalnız ondan geçiyor.

İkinci emniyet: olaya `fb_order_id` olarak `PurchaseDetails.purchaseID`
ekleniyor; Meta aynı kimlikli olayları tekilleştirebiliyor.

---

## 1. Temel karar: iki platform bilerek farklı

Bütün yapılandırmayı belirleyen tek soru: **reklam kimliğini topluyor muyuz?**
Cevap platforma göre değişiyor, çünkü bedeli platforma göre değişiyor.

iOS'ta reklam kimliğinin (IDFA) bedeli ATT istemi — kullanıcıya gösterilen
izleme diyaloğu, tipik kabul oranı %25–40. Ödenmiyor: satın alma olayları
IDFA'dan bağımsız olarak Meta'ya ulaşıyor ve modellenmiş atıfta kullanılıyor,
kurulum eşleşmesi SKAdNetwork üzerinden sürüyor. Kaybedilen ölçümün varlığı
değil, çözünürlüğü — kullanıcı kırılımı yok.

Android'de ATT yok. Reklam kimliği toplamanın kullanıcıya maliyeti sıfır,
karşılığında tam attribution geliyor; bırakmak için sebep yok.

Bayraklar her platformda ayrı yazıldığı için (manifest ve plist) bu ayrım
ifade edilebiliyor.

| Ayar | iOS | Android |
| --- | --- | --- |
| Otomatik olay loglama | Açık | Açık |
| Reklam kimliği toplama | **Kapalı** | **Açık** |
| ATT istemi | Yok | Yok — platformda mevcut değil |
| `AD_ID` izni | — | Tanımlı |
| SKAdNetwork kimlikleri | Tanımlı | — |

**Değiştirirsen ikisi birlikte değişir.** iOS'ta reklam kimliğini açarsan
`NSUserTrackingUsageDescription` ve bir ATT isteği **aynı değişiklikte**
eklenmeli; Apple istemsiz IDFA erişimini reddediyor. Yapılandırma testi bu iki
yarıyı birbirine bağlı tutar: birini açıp diğerini unutursan kırmızı yanar.

### Karıştırılan iki şalter

Bu karar düzenli olarak yeniden tartışmaya açılıyor ve her seferinde aynı
yerden: **reklam kimliği** ile **olayların kendisi** tek şey sanılıyor. Değil,
ve ikisini ayırmadan verilen hiçbir cevap tutarlı olmuyor.

| | Şalter | Bugünkü hâli | Kapatırsan ne olur |
| --- | --- | --- | --- |
| **1** | `FacebookAdvertiserIDCollectionEnabled` (iOS) | Kapalı | Zaten elde olmayan bir sinyal gider — ATT istemi hiç gösterilmediği için IDFA hâlihazırda yok |
| **2** | `FacebookAutoLogAppEventsEnabled` + `logPurchase` | Açık | **Ölçüm biter.** Satın almaya optimize kampanya kurulamaz, SKAdNetwork'ün dönüşüm değeri beslenemez |

"Anonim kurulum/satın alma toplamanın reklam performansına etkisi yok" cümlesi
**2. şalter için yanlıştır**; 1. şalter için söylendiğinde doğruya yakındır.
Aynı cümlenin bir gün doğru bir gün yanlış görünmesinin sebebi bu — hangi
şalterden bahsedildiği söylenmiyor.

Yürürlükteki bileşim bilinçli: **kimlik kapalı, sinyal açık.** Kullanıcıya
izleme diyaloğu gösterilmiyor ama Meta ölçebileceği tek şeyi ölçmeye devam
ediyor. Yapılacak asıl hata, "nasılsa anonim" deyip 2. şalteri de kapatmak
olurdu.

İkisi de teste bağlı — `test/meta_sdk_config_test.dart` → "iOS: otomatik
loglama açık, reklam kimliği kapalı". Yani bu bir niyet beyanı değil: biri
sessizce değişirse takım kırmızı yanar.

**Bu soruyu bir daha bir dil modeline sorma — Events Manager'a sor.** Olaylar
geliyor mu, satın almalar görünüyor mu; cevap orada. Reklam tarafı hızlı
değişiyor ve modelin bilgisi her zaman geçmişte kalıyor.

Ayrıca: bu yapılandırmada kurulum atfının yürüdüğü asıl yol SKAdNetwork.
`SKAdNetworkItems` listesi Meta'nın yayımladığı güncel listeyle karşılaştırılmalı
— IDFA tartışmasından daha çok işe yarar ve tahminle doğrulanamaz.

---

## 2. Sinyaller — Meta'ya ne, ne zaman gidiyor

| Olay | Kaynak | Tetiklenme anı |
| --- | --- | --- |
| Kurulum + oturum | SDK otomatik | uygulama açılışı |
| `Purchase` | elle | satın alma doğrulandıktan sonra |

Satın alma olayı **elle** gönderiliyor, SDK'nın örtük takibine bırakılmıyor.
İki bağımsız sebep var: örtük takip Play Billing Library ve StoreKit 2 ile
zaten tetiklenmiyor; tetiklense bile mağaza "satın alındı" der demez çalışıyor,
yani doğrulamadan önce — iade edilen ya da sahte makbuz Meta'ya gerçek gelir
gibi görünürdü. Kampanya bütçesi o rakama göre dağıtıldığı için bu, eksik
veriden pahalı bir hata.

Latermark'ta doğrulanmış dal net biçimde ayrılmış durumda:

- **iOS:** native `currentEntitlements` sorgusu (`_confirmIosPurchase()`);
  olay yalnız `verified == true` iken gönderilir.
- **Android:** `PurchaseStatus.purchased` dalı — `restored` **hariç**
  (bkz. §0.3). Android restore sorgusunun erken dönen yolu da olay
  göndermemeli.

Tutar ve para birimi mağaza önbelleğinden okunur, sabit yazılmaz: Latermark'ta
`PurchaseService.price` ve `ProductDetails` üzerinden geliyor. Fiyat gelmemişse
olay hiç gönderilmez — sıfır değerli satın alma, değer bazlı tekliflerde
ortalamayı aşağı çeker.

---

## 3. Dosyalar — Latermark'ta şu an ne var

| Dosya | Ne yapıyor |
| --- | --- |
| `pubspec.yaml` | `facebook_app_events: ^0.30.5` — Meta SDK 18.x, iki platformda da. Sürüm **elle** yazıldı: `flutter pub add` lock dosyasını baştan yazıyor ve projede bilerek sabitlenmiş sürümler var. |
| `android/app/src/main/res/values/facebook.xml` | **yeni** — App ID ve Client Token, `translatable="false"`. Manifeste doğrudan yazılamıyor: SDK sayısal app id'yi string kaynağı olmadan `int` sanıp yanlış ayrıştırıyor. |
| `android/app/src/main/AndroidManifest.xml` | SDK meta-data'ları, iki toplama bayrağı `true`, `AD_ID` + `INTERNET` izinleri. |
| `ios/Runner/Info.plist` | App ID, Client Token, görünen ad, `fb<APPID>` şeması (mevcut `latermark` şemasının yanına), otomatik loglama açık, reklam kimliği kapalı, SKAdNetwork kimlikleri. |
| `lib/core/analytics/meta_events_service.dart` | **yeni** — `MetaEvents`: satın alma olayı ve debug teşhisi. **Init çağrısı yok**; kurulum/oturumu SDK kendi gönderiyor. |
| `lib/features/paywall/data/purchase_service.dart` | `_reportPurchase` — doğrulanmış ve *yeni* satın alma dalında. |
| `lib/main.dart` | Debug teşhisi, ilk kareden sonra (`addPostFrameCallback`), açılış yolunun dışında. |
| `lib/l10n/app_*.arb` | `yourDataSafetyAnswer` — 10 dilde yeniden yazıldı (§0.2). |
| `test/meta_sdk_config_test.dart` | **yeni** — yapılandırma kapısı. |

### Yapılandırma testi ne kilitliyor

- App ID ve Client Token iki platformda **aynı** mı
- iOS URL şeması App ID ile eşleşiyor mu (`fb<APPID>`), uygulamanın kendi
  `latermark` şeması duruyor mu
- Yer tutucular değiştirilmiş mi — **tek kırmızı test bu**
- App Secret yanlışlıkla pakete girmiş mi
- Android: otomatik loglama ve reklam kimliği açık mı, meta-data'lar string
  kaynağını gösteriyor mu
- iOS: otomatik loglama açık, reklam kimliği kapalı mı
- **Reklam kimliği ile ATT istemi birlikte mi değişiyor** — biri açılıp diğeri
  unutulursa kırmızı yanar (Apple istemsiz IDFA erişimini reddediyor)
- `AD_ID` izni tanımlı ve `tools:node="remove"` ile düşürülmemiş mi
- `INTERNET` izni **yayın** manifestinde mi (debug'da zaten var, orada olması
  yanıltıcı)
- SKAdNetwork kimlikleri yerinde mi

### Doğrulama

```
flutter build apk --debug
aapt2 dump permissions build/app/outputs/flutter-apk/app-debug.apk
```

1 Eylül 2026'da çalıştırıldı; birleşmiş manifestte beklenen izinler çıktı:
`AD_ID`, dört `ACCESS_ADSERVICES_*`, `INTERNET`, `ACCESS_NETWORK_STATE` ve
Meta'nın install referrer bağlaması
(`BIND_GET_INSTALL_REFERRER_SERVICE`).

iOS tarafında derleme `tool/flutter-ios` sarmalayıcısıyla yapılır (Flutter'ın
SPM sıralama hatası). Eklenti SPM'i destekliyor (`ios/facebook_app_events/
Package.swift`), CocoaPods'a dönmek gerekmiyor — projede Podfile yok ve
olmasına da gerek kalmadı.

iOS derlemesi de yapıldı: `FBSDKCoreKit`, `FBSDKCoreKit_Basics` ve `FBAEMKit`
`Runner.app/Frameworks` altında, plist anahtarları derlenmiş pakette yerinde.

**`NSPrivacyTrackingDomains`.** SDK kendi gizlilik bildirgesiyle
`ep1.facebook.com`'u izleme alan adı olarak ekliyor; derlenmiş plist'te
görünüyor. ATT izni verilmemişken Apple bu alan adına giden istekleri
engelliyor — bizde ATT istemi hiç yok. Beklenen davranış, SDK'nın reklam
kimliği kapalıyken olayları izleme uçu yerine normal uca göndermesi; yani
satın alma olayları yine ulaşıyor, kaybedilen kullanıcı kırılımı. **Yayından
sonra Events Manager'da olayların gerçekten düştüğü teyit edilmeli**
(§6) — bu, yer tutucular değişmeden sınanamayan tek şey.


## 4. Debug araçları

Debug derlemesinde SDK kendi loglarını basar, cihazın anonim kimliğini konsola
yazar ve her olayı **anında** gönderir — SDK normalde olayları biriktirip toplu
yolluyor, test ederken en çok vakit kaybettiren şey o. Release'de bu kodun
gövdesi tamamen elenir.

---

## 5. Tuzaklar

- **Client Token, App Secret değil.** SDK'nın istediği Client Token: Meta
  panelinde Ayarlar → Gelişmiş → İstemci Jetonu. App Secret sunucu tarafı kimlik
  bilgisidir, uygulama paketinden okunabilir, oraya asla girmemeli.
- **`flutter pub add`** lock dosyasını baştan yazıyor.
- **Bayraklar manifest ve plist'te, Dart'ta değil.**
- **Satın almada çift sayım.** Latermark'ta restore yüzünden gerçek risk
  (§0.3).
- **SPM bozulmuyor**, CocoaPods'a dönmek gerekmiyor.
- **Elle indirilmiş Facebook AAR paketleri** — gerekmiyor.

---

## 6. Kodun halledemediği kısım

Mağaza formları ve web sitesi. Kod karşılığı yok ama atlanırsa ret sebebi. Play
bu redleri koda değil, politika ile beyan arasındaki uyuşmazlığa bakarak veriyor.

- **Play Console → Veri güvenliği:** reklam kimliği **Evet**. Uygulama
  etkileşimleri ve satın alma geçmişi de "toplanıyor + Meta ile paylaşılıyor"
  işaretlenmeli.
- **App Store Connect → App Privacy:** IDFA toplanmıyor, Tracking **Hayır**.
  ATT isteminin olmamasının sebebi tam olarak bu. Purchase History ve Product
  Interaction ise toplanıyor.
- **Gizlilik politikası:** Meta alıcı olarak yazılmalı, reklam kimliği kullanımı
  geçmeli. Site metni mağaza formundan bağımsız kontrol ediliyor.
- **Uygulama içi "Your Data" metni:** §0.2 — 13 dilde.
- **Meta panelinden Client Token'ı al.** Test kırmızı kaldığı sürece bu adım
  eksik demektir.
- **Yayından sonra Events Manager'da doğrula.** Olayları Test Etme gerçek
  zamanlı; asıl panelde 30 dakikaya kadar gecikme normal.

---
