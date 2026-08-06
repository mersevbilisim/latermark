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

  /// `14:32`
  static const time = 'not_time';

  /// `6 AĞUSTOS` — küçük kapitel olarak hazır gelir.
  static const date = 'not_date';

  /// Silinme anının epoch saniyesi; süresiz notlarda 0.
  ///
  /// Rozetin metnini widget kendisi üretir. Hazır metin göndermek, widget
  /// birkaç saat tazelenmediğinde "3g" yazısının donup kalmasına yol açardı.
  static const expiresAt = 'not_expires_at';

  /// Toplam kayıt sayısı.
  static const count = 'not_count';

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
const String kAndroidWidgetProvider = 'NotWidgetProvider';

/// Widget'a dokunulduğunda açılan şema: `notapp://note/12`.
const String kWidgetUrlScheme = 'latermark';
