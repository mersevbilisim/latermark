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
}
