# Not

Fotoğraf çek, iki kelime yaz, unut.

Bir market fişini, arabayı bıraktığın park yerini ya da araştıracağın bir
parçayı yakalamanın en kısa yolu: uygulama açılır, ortada bir diyafram durur,
dokunursun, kare çekilir, altında not alanı açılır. İstersen kayda bir ömür
biçersin — 3 gün ya da 1 hafta sonra kendiliğinden silinir.

## Yapı

Katmanlar özellik bazlı ayrılmıştır; hiçbir ekran mantığı `main.dart` içinde
durmaz.

```
lib/
  main.dart                    yalnızca açılış sırası
  app/                         MaterialApp, depo kapsamı, sayfa geçişleri
  core/theme/                  renk, tipografi, hareket, tema
  core/utils/                  Türkçe tarih/süre biçimlendirme
  shared/widgets/              diyafram, cam yüzey, parallax, düğmeler
  features/notes/
    domain/                    saklama süresi (Retention)
    data/                      Drift veritabanı, fotoğraf deposu, repository
    presentation/home/         akış + deklanşör
    presentation/capture/      vizör
    presentation/compose/      not yazma
    presentation/detail/       tek kayıt görünümü
  features/home_widget/        ana ekran widget'ını besleyen köprü
ios/NotWidget/                 WidgetKit eklentisi (SwiftUI)
android/.../NotWidgetProvider.kt  Android ana ekran widget'ı
```

Durum yönetimi için ek paket yok: Drift'in canlı sorguları doğrudan
`StreamBuilder` ile kullanılıyor.

## Ana ekran widget'ı

En son kaydı gösterir; hiç kayıt yoksa diyafram nişanı ve "Dokun ve çek".

Uygulama her veri değişikliğinde son notun özetini paylaşılan alana yazar
(`lib/features/home_widget/home_widget_bridge.dart`). Widget hiçbir hesap
yapmaz; Türkçe tarih metni ve küçültülmüş kare hazır gider. Yalnızca "kalan
süre" rozetini kendisi üretir, böylece saatler sonra tazelendiğinde bile doğru
kalır.

### iOS kurulumu

Eklenti hedefi projeye eklenmiş durumda. Sıfırdan bir kopyada yeniden
oluşturmak gerekirse:

```bash
ruby ios/add_widget_target.rb
```

Paket kimliğini değiştirirsen App Group kimliğini **dört yerde birden**
güncelle:

| Dosya | Alan |
| --- | --- |
| `lib/features/home_widget/widget_keys.dart` | `kAppGroupId` |
| `ios/Runner/Runner.entitlements` | `application-groups` |
| `ios/NotWidget/NotWidget.entitlements` | `application-groups` |
| `ios/NotWidget/NotWidgetEntry.swift` | `NotKeys.appGroup` |

Gerçek cihazda App Group yetkisinin Apple Developer hesabında da tanımlı olması
gerekir; Xcode otomatik imzalama bunu genelde kendiliğinden halleder.

### Android kurulumu

Ek adım yok — `AndroidManifest.xml` içindeki receiver ve
`res/xml/not_widget_info.xml` yeterli.

## Otomatik silme

Süre, notun **oluşturulma** anına göre hesaplanır; düzenlemek ömrü uzatmaz.
Temizlik üç yerde tetiklenir: açılışta, uygulama öne geldiğinde ve önplandayken
dakikada bir. Kayıt silinirken fotoğrafı da diskten kalkar.

## Geliştirme

```bash
flutter pub get
dart run build_runner build        # Drift kod üretimi
flutter test
flutter run
```

Kamera gerçek donanım ister; iOS simülatöründe vizör "Kamera bulunamadı" der.
Akış, yazma ve detay ekranları simülatörde sorunsuz çalışır.
