import '../data/notes_database.dart';

/// Bir kaydın karesi var mı.
///
/// Latermark'ın aslı bir kare ve altına düşülmüş nottur. Karesiz kayıt — bir
/// hatırlatma, bir cümle — sonradan eklendi ve **ayrı bir tür değil**: aynı
/// tablo, aynı saklama süresi, aynı hatırlatma, aynı Pro sınırı. Tek fark
/// dosyası olmaması.
///
/// Bu yüzden şemaya yeni bir sütun eklenmedi. `imageName` boş string ise kayıt
/// karesizdir; başka hiçbir yerde işaret aranmaz. Boş adın seçilmesinin sebebi
/// göç değil **uyum**: sütun `NOT NULL` kalıyor, tablo yeniden kurulmuyor,
/// kimsenin arşivi taşınmıyor ve yedek dosyası eski sürümlerde de açılmaya
/// devam ediyor (orada kayıt "karesi kaybolmuş not" olarak çiziliyor).
///
/// Tek kapı burasıdır. Fotoğraf okuyan her yer önce buna sormalı; `imageName`
/// alanına doğrudan bakan yeni kod yazma.
extension NoteKind on Note {
  /// Kaydın diskte bir karesi var mı.
  bool get hasPhoto => imageName.isNotEmpty;

  /// Kayıt yalnızca yazıdan ibaret mi.
  bool get isTextOnly => imageName.isEmpty;

  /// [body] ile kaydedilirse geriye hiçbir şey kalmıyor mu.
  ///
  /// Karesiz bir kaydın yazısı silinirse ortada ne kare ne yazı kalıyor:
  /// akışta boş bir kart, aramada hiç bulunmayan bir satır. Yeni kayıt ekranı
  /// bunu baştan beri engelliyordu; aynı kaydın **düzenlenmesi**
  /// engellenmiyordu.
  ///
  /// Kare varsa gövdenin boşalması serbest — kayıt hâlâ bir şey. Aksi hâlde
  /// kullanıcı fotoğrafına yazdığı notu bir daha hiç silemezdi.
  bool wouldBeEmpty(String body) => isTextOnly && body.trim().isEmpty;
}
