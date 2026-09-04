/// Dart, Swift ve Kotlin tarafının ortak sözlüğü.
///
/// Bu anahtarlar üç dilde de birebir aynı yazılmalı. Değiştirirken
/// `ios/NotWidget/NotWidgetEntry.swift` ve
/// `android/app/src/main/kotlin/.../NotWidgetProvider.kt` dosyalarını da
/// güncelleyin.
abstract final class WidgetKeys {
  /// Ekran görünümünde bir kayıt var mı?
  static const hasNote = 'not_has_note';

  /// Kayıtlı kimlik — widget'a dokununca doğrudan o notu açmak için.
  static const noteId = 'not_note_id';

  /// Not metni. Boş olabilir (kullanıcı yazmadan kaydettiyse).
  static const body = 'not_body';

  /// Silinme anının epoch saniyesi; süresiz notlarda 0.
  ///
  /// Rozetin metnini widget kendisi üretir. Hazır metin göndermek, widget
  /// birkaç saat tazelenmediğinde "3g" yazısının donup kalmasına yol açardı.
  static const expiresAt = 'not_expires_at';

  /// Oluşturma anının epoch saniyesi.
  ///
  /// Ömür göstergesi için gerekli: yalnızca [expiresAt] gönderildiğinde widget
  /// notun *toplam* süresini bilemiyor ve kalanı sabit bir haftaya oranlamak
  /// zorunda kalıyordu — 3 günlük bir not doğduğu anda yarı tükenmiş
  /// görünüyordu.
  ///
  /// Künyedeki gün ve saat de bundan üretiliyor. Bir zamanlar buradan hazır
  /// `"BUGÜN"` ve `"14:32"` metinleri gidiyordu; ikisi de paylaşılan alanda
  /// donuyordu. Widget saatte bir tazelense de aynı donmuş metni yeniden
  /// okuduğu için, kullanıcı uygulamayı açmadığı sürece dün kaydedilmiş bir
  /// not ertesi gün hâlâ "BUGÜN" diyordu. Rozette çözülen sorunun aynısı:
  /// zamana bağlı her metni widget kendisi üretmeli.
  static const createdAt = 'not_created_at';

  /// Toplam kayıt sayısı.
  static const count = 'not_count';

  /// Pro hakkı açık mı. Köprü hakkı kapatmayı veri sınırı sayıp not alanlarını
  /// ve fotoğrafı temizler; native widget da ayrıca kendi kilit durumunu çizer.
  static const pro = 'not_pro';

  /// Widget metinlerinin dili: `tr`, `en`, `pt-BR` gibi bir BCP-47 etiketi.
  ///
  /// Zamana bağlı metinleri native taraf üretiyor (bkz. [createdAt]) ve bir
  /// uzantı kendi başına yalnızca **sistem** dilini bilir. Uygulama içinden
  /// başka bir dil seçen kullanıcının widget'ı bu anahtar olmadan telefonun
  /// dilinde kalıyordu: arayüz Türkçe, ana ekrandaki kart "TODAY · 2d".
  ///
  /// "Sistem" seçiliyken de boş geçilmez; çözülmüş dil yazılır. Native tarafın
  /// kendi yedeklemesi Flutter'ınkiyle aynı sonucu vermeyebilir — `pt_PT`
  /// konuşan bir telefonda uygulama `pt_BR` çevirisine düşerken Android
  /// `values-pt/` klasörünü seçerdi.
  static const locale = 'not_locale';

  /// Kullanıcının seçtiği fotoğraf-üstü vurgu renginin sekiz haneli ARGB
  /// karşılığı. Swift/Kotlin, widget'ı Flutter paletiyle aynı tonda çizer.
  static const accent = 'not_accent';

  /// Paylaşılan kapsayıcıya yazılan küçültülmüş fotoğrafın yolu.
  ///
  /// `HomeWidget.saveFile` bu anahtarı hem dosya adı hem de tercih anahtarı
  /// olarak kullandığı için ayrıca yol yazmaya gerek yok.
  static const photo = 'not_photo';
}

/// iOS'ta uygulama ile eklenti arasındaki ortak kapsayıcı.
///
/// Paket kimliğini değiştirirseniz burayı, `ios/Runner/Runner.entitlements` ve
/// `ios/NotWidget/NotWidget.entitlements` dosyalarını birlikte güncelleyin.
const String kAppGroupId = 'group.com.mersev.latermark';

/// WidgetKit eklentisinin ve Android sağlayıcısının adları.
const String kIosWidgetName = 'NotWidget';
const String kIosCaptureWidgetName = 'LatermarkCaptureWidget';
const String kAndroidWidgetProvider = 'NotWidgetProvider';

/// Widget'a dokunulduğunda açılan şema: `latermark://note/12`.
const String kWidgetUrlScheme = 'latermark';
