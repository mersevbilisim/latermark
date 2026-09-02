# Metin notu — veri sözleşmesi ve Siri devir teslimi

Bu belge iki iş arasındaki sınırı çiziyor:

- **Latermark tarafı (bende):** karesiz notun veritabanı temsili, oluşturma
  yolu, arayüz, ızgara, yedekleme, bildirim.
- **Siri tarafı (Codex'te):** iOS App Intents hedefi ve Swift devir teslimi.

Sınır tek bir şey: **App Group gelen kutusundaki JSON.** Codex Dart'a hiç
dokunmuyor, ben Swift App Intent'ine hiç dokunmuyorum.

---

## 1. Karesiz not veritabanında ne

**Şema değişmiyor.** Yeni sütun yok, yeni tablo yok, `schemaVersion` 10'da
kalıyor, hiçbir göç çalışmıyor.

| Alan | Karesi olan kayıt | Karesiz kayıt |
| --- | --- | --- |
| `notes.image_name` | dosya adı (`1754…-4821.jpg`) | **`''`** (boş string) |
| `notes.original_name` | isteğe bağlı | her zaman `NULL` |
| `note_search.body_folded` | gövdeden katlanmış | aynı |
| `note_search.photo_folded` | `NULL` → OCR kuyruğuna girer | **`''`** → hiç girmez |

Neden boş string, neden `NULL` değil:

- `image_name` `NOT NULL`. Nullable yapmak SQLite'ta tabloyu yeniden kurmayı
  gerektiriyor — kullanıcının bütün arşivini taşıyan tek tehlikeli adım, ve
  gereksiz.
- `schemaVersion` artmadığı için **yeni yedek dosyası eski sürümlerde de
  açılıyor**. Orada kayıt "karesi kaybolmuş not" olarak çiziliyor; metni ve
  hatırlatması duruyor.
- `photo_folded = ''`, `unscanned()` kuyruğunun `photo_folded IS NULL`
  koşuluyla beslenmesinden dolayı zorunlu. `NULL` bırakılırsa okunacak karesi
  olmayan her kayıt, deneme hakkı bitene kadar OCR sırasında döner.

Tek kapı: `NoteKind` uzantısı (`lib/features/notes/domain/note_kind.dart`).

```dart
note.hasPhoto     // imageName.isNotEmpty
note.isTextOnly   // imageName.isEmpty
```

`imageName` alanına doğrudan bakan yeni kod yazılmıyor.

---

## 2. Oluşturma yolu

`NotesRepository.createText` — `create` ile **aynı** kapıdan geçiyor: aynı Pro
kapısı, aynı saklama süresi, aynı hatırlatma kuralı, aynı teslim tekilliği.

```dart
Future<int> createText({
  required String body,
  required RetentionChoice retention,
  ReminderChoice reminder = const ReminderChoice.off(),
  DateTime? createdAt,
  NoteLocation? location,
  String? importId,
});
```

### Uyulması zorunlu üç kural

1. **Hatırlatma Pro'ya bağlı.** `_insertNote` içinde:
   `effectiveReminder = isPro ? reminder : ReminderChoice.off()`. Pro değilse
   hatırlatma **sessizce düşer**. Siri tarafı bunu kullanıcıya söylemeli,
   yoksa "hatırlat" dedi, not oluştu, hatırlatma hiç kurulmadı.
2. **Hatırlatma, kaydın silinme anından önce olmalı.** Aksi hâlde
   `ReminderAfterExpiryException` fırlıyor ve kayıt hiç oluşmuyor. Saklama
   süresi kullanıcının varsayılanından geliyor; "3 ay sonra hatırlat" diyen
   biri, varsayılanı 30 gün ise hata alır.
3. **`importId` tekilliği.** Aynı kimlik iki kez düşerse ikinci kayıt
   açılmıyor, ilkinin kimliği dönüyor (`processed_imports` tablosu). Dışarıdan
   gelen her teslim bir `importId` taşımak zorunda.

---

## 3. Siri devir teslimi — sözleşme

### Neden App Intent notu kendisi oluşturmuyor

App Intent ayrı bir süreçte çalışıyor. Oradan veritabanına yazmak üç şeyi
kırar: sqlite kilidi, Pro durumu (ayarlar tablosunda) ve saklama süresi
hesabı. Zaten Share Extension'da da bu yüzden yazılmıyor.

Kurulu desen aynen kullanılacak: **uzantı gelen kutusuna bırakır, Runner
alır, Dart yazar.** `AppLink` hiyerarşisinin yorumu bunu zaten öngörüyor —
"yarın bir App Intent ya da kısayol aynı kapıdan girsin diye".

### Gelen kutusu

`ios/Shared/SharedImportStore.swift`, App Group `group.com.mersev.latermark`,
klasör `shared_imports`. Kural değişmiyor: **JSON en son yazılır**, böylece
yarım kalan bir öğe Flutter'a tamamlanmış görünmez.

Bugünkü `Metadata` görsel varsayıyor. Metin öğesi için genişletilecek:

```json
{
  "id": "9f2c…",              // UUID, aynı zamanda importId
  "kind": "text",             // yeni alan; yoksa "photo" varsayılır
  "imageName": "",            // metin öğesinde boş
  "initialText": "Akşam Claude ile olan işi hatırlat",
  "createdAtMilliseconds": 1756704000000,
  "saveImmediately": true,
  "remindAtMilliseconds": 1756742400000   // yoksa hatırlatma yok
}
```

- `kind` **geriye uyumlu**: alanı olmayan eski öğeler `"photo"` sayılır.
- `remindAfterDays` (mevcut alan) metin öğesinde kullanılmıyor; Siri mutlak
  bir an biliyor, gün sayısına çevirmek o anı kaybettirir.
- `saveImmediately: false` gelirse uygulama composer'ı metinle açar,
  kaydetmez.

### Uzantının bilebileceği durum

App Group `UserDefaults` üzerinden aynadan okunuyor. Üçü tek turda
yazılıyor (`SharedImportBridge.setShareMirror` → `setShareMirror` kanalı):

| Anahtar | Ne için |
| --- | --- |
| `share.pro_unlocked` | hatırlatma kurulabilir mi (kural 1) |
| `share.default_retention_minutes` | hatırlatma silinme anından önce mi (kural 2). **Sıfır süresiz saklamadır**; anahtarın hiç olmaması "bilmiyorum" demektir ve uzantı o zaman hatırlatma teklif etmez |
| `share.reminder_enabled` | kullanıcı hatırlatmaları tümden kapattıysa uygulama ilk açılışta bekleyen bütün bildirimleri siliyor; uzantı bunu bilmeden kurduğu alarm sessizce kaybolurdu |

---

## 3.1 Alarm bekleyemez

Kaydın veritabanı satırı Runner açılana kadar gelen kutusunda bekliyor ve bu
teknik bir zorunluluk. **Bildirim beklemiyor.**

"Akşam 6'da hatırlat" diyen biri uygulamayı bir daha hiç açmayabilir. Alarm da
kayıtla birlikte beklerse Siri yolu tümden işe yaramaz: kullanıcı söyledi,
Siri "tamam" dedi, hiçbir şey çalmadı.

Bu yüzden bildirimi **uzantı kendisi planlıyor** (`QueuedReminder`,
`ios/Shared/SharedImportStore.swift`). `UNUserNotificationCenter` uzantıda da
ana uygulamanın merkezini döndürüyor; teslim ana uygulama adına yapılıyor.

| | Ne zaman | Kim |
| --- | --- | --- |
| Gelen kutusuna JSON | Siri konuşurken | uzantı |
| Geçici alarm (`latermark.queued.<importId>`) | Siri konuşurken | uzantı |
| Veritabanı satırı | Runner'ın ilk açılışı | Dart |
| Gerçek alarm (`noteId * 64 + oluşum`) | Runner'ın ilk açılışı | `ReminderService` |
| Geçici alarmın iptali | kayıt oluştuktan **sonra** | `cancelQueuedReminder` kanalı |

İkisi bir arada asla çalmaz: geçici istek kayıt gerçekten oluştuktan sonra
kaldırılıyor. Sıra bilinçli — arada bir hata olsaydı kullanıcı hem kaydı hem
alarmı kaybederdi.

Geçici istek `ReminderService.sync` döngüsünü de rahatsız etmiyor: kimliği
harfle başlıyor (eklentinin tamsayı şemasıyla çakışmaz) ve payload'ı
`note/<id>` kalıbına uymuyor, o yüzden senkron onu atlıyor.

Uzantı eylem düğmesi (`latermark.reminder.once`) takmıyor: o düğmeler
payload'daki not kimliğiyle çalışıyor ve kayıt henüz yok. Dokunma uygulamayı
açar, açılış zaten kaydı üretir.

### Uzantının söylemediği şeyler

Konuşma başlamadan reddedilen durumlar — kullanıcıdan önce metin ve zaman
isteyip sonra "olmadı" dememek için:

- Pro değil
- hatırlatmalar uygulamada kapalı
- saklama aynası hiç yazılmamış
- bildirim izni yok (izin uzantıdan **istenemez**, yalnız okunur)

## 4. İş bölümü

| | Durum |
| --- | --- |
| `createText`, `NoteKind`, arayüz, ızgara, yedekleme, bildirim | bitti |
| `SharedImportStore.swift` içinde metin öğesi | bitti |
| App Intents hedefi, intent tanımları, Siri ifadeleri | bitti |
| Uzantı yerelleştirmesi (10 dil) | bitti |
| `QueuedReminder` — uzantının kurduğu alarm | bitti |
| Dart: gelen kutusundan metin öğesini alıp `createText` çağırma | bitti |
| Dart: ayna (`pro`, `reminder_enabled`, `retention_minutes`) | bitti |

## 5. Sınırlar

- Uzantı veritabanına dokunmuyor — okumak da dahil
- Şema değişmiyor, `schemaVersion` artmıyor
- Ağa çıkan hiçbir şey yok
- `importId` taşımayan teslim yok
- Kullanıcı Pro değilken hatırlatma sözü verilmiyor

## 6. Kabul ölçütü

1. Siri ile metin + hatırlatma söylenince kayıt tek kere oluşuyor
2. Aynı intent iki kez tetiklenince ikinci kayıt oluşmuyor
3. Uygulama kapalıyken tetiklenen intent, açılışta kaydı üretiyor
4. **Uygulama hiç açılmasa bile hatırlatma zamanında çalıyor**
5. Kayıt oluştuktan sonra aynı hatırlatma iki kez çalmıyor
6. Pro olmayan kullanıcıda hatırlatma isteği açıkça reddediliyor
7. Silinme anından sonraya hatırlatma istenirse kullanıcı uyarılıyor
8. Bildirim izni yokken alarm sözü verilmiyor
9. Görsel paylaşımı (mevcut Share Extension) hiç etkilenmiyor

### Elle sınanacaklar

Simülatörde Kestirmeler uygulamasından, cihazda Siri ile:

- Uygulamayı **hiç açmadan** yakın bir zamana hatırlatma kur, bekle — çalmalı
- Aynı hatırlatmayı kurduktan sonra uygulamayı aç, zamanı bekle — bir kez çalmalı
- Bildirimleri kapat, sonra Siri'den hatırlatma iste — reddedilmeli
- Saklama süresini 1 saate düşür, Siri'den yarına hatırlatma iste — reddedilmeli
