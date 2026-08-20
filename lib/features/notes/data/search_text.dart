/// Aranabilir metnin tek kuralı burada.
///
/// Hem yazma (indeksi kurarken) hem okuma (sorguyu hazırlarken) aynı
/// fonksiyondan geçer. İkisi ayrışırsa arama sessizce bozulur — kullanıcı
/// bunu "bazen buluyor bazen bulmuyor" diye yaşar ve sebebini asla anlamaz.
abstract final class SearchText {
  /// Bir karenin indekse giren metni için üst sınır.
  ///
  /// Bu bir tasarruf ayarı değil, **patolojik girdiye karşı bant**. Yoğun bir
  /// A4 sayfası ~3.000, çift sütun bir sözleşme ~7.000 karakter üretir; 8.000
  /// gerçek bir belgeyi pratikte hiç kesmez. Asıl kesilmesi gereken şey bir
  /// gazete sayfası ya da ekran fotoğrafı gibi uç durumlar.
  ///
  /// Sınırı düşürmek cazip görünür ama özelliği öldürür: fişte aranan şey
  /// (tutar, fiş no, vergi no) sayfanın ortasındadır, başında değil.
  static const int maxIndexedChars = 8000;

  /// Süreçler ve sürümler arasında kararlı, küçük içerik imzası (FNV-1a).
  /// `String.hashCode` bu sözleşmeyi vermez; Spotlight state'i ise diskte bir
  /// sonraki sürüm tarafından da okunur.
  static String fingerprint(String value) {
    var hash = 0x811C9DC5;
    for (var i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Aramada büyük/küçük ve diakritik farklarını yok sayar.
  ///
  /// OCR `ı` ile `i`yi sık karıştırıyor; kullanıcının yazdığı da her zaman
  /// diakritikli olmuyor. İkisini de sadeleştirmek eşleşme şansını artırıyor.
  ///
  /// Kod birimleri üzerinden dönülüyor, `split('')` ile değil: eski hâl
  /// karakter başına bir `String` nesnesi ayırıyordu ve bu, her tuş vuruşunda
  /// tüm kayıtlar için tekrarlandığında tek başına takılmaya yetiyordu.
  /// Artık katlama yalnızca **yazarken** bir kez yapılıyor, ama ucuz olması
  /// yine de önemli: sorgu her tuşta katlanıyor.
  static String fold(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      final folded = switch (unit) {
        0x131 || 0x130 || 0x49 || 0x69 => 0x69, // ı İ I i → i
        0x11F || 0x11E => 0x67, // ğ Ğ → g
        0xFC || 0xDC => 0x75, // ü Ü → u
        0x15F || 0x15E => 0x73, // ş Ş → s
        0xF6 || 0xD6 => 0x6F, // ö Ö → o
        0xE7 || 0xC7 => 0x63, // ç Ç → c
        >= 0x41 && <= 0x5A => unit + 0x20, // ASCII büyük harf
        < 0x80 => unit, // geri kalan ASCII olduğu gibi
        _ => null, // ASCII dışı: genel küçültmeye düşülür
      };

      if (folded != null) {
        buffer.writeCharCode(folded);
        continue;
      }

      // Uygulama sekiz dilde yayınlanıyor; `É`, `Ä`, `Ç` dışındaki aksanlı
      // büyük harfler de küçültülmeli. Bu dal yalnızca ASCII dışı karakterlere
      // giriyor, yani Latin metinde nadiren çalışıyor. Tek kod birimi yerine
      // tüm sonucu yazıyoruz: bazı harflerin küçüğü birden fazla birim.
      buffer.write(String.fromCharCode(unit).toLowerCase());
    }
    return buffer.toString();
  }

  /// Yazının anlamını bozmayan ama boşluk yapısı taşıyan kısımlarını
  /// tek boşluğa indirir ve [maxIndexedChars] ile sınırlar.
  ///
  /// Boşluk daraltması iki platformu da hizalıyor: Android tarafı bunu zaten
  /// yapıyordu, iOS ise Vision'ın satır satır sonuçlarını ham hâlde
  /// birleştiriyordu. Aynı fotoğrafın iki telefonda farklı indekslenmesi,
  /// çok kelimeli aramalarda platformdan platforma değişen sonuç demekti.
  ///
  /// Kesme noktası kelime sınırına çekilir: sınırın tam ortasına denk gelen
  /// yarım kelime hiçbir aramada eşleşmez, indekste yer kaplamasının anlamı
  /// yok.
  static String normalize(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxIndexedChars) return collapsed;

    final cut = collapsed.substring(0, maxIndexedChars);
    final lastSpace = cut.lastIndexOf(' ');
    // Boşluksuz 8.000 karakter gerçek bir belge değil (barkod, base64, gürültü);
    // öyleyse olduğu yerden kes.
    return lastSpace > maxIndexedChars - 64 ? cut.substring(0, lastSpace) : cut;
  }

  /// Katlanmış metni SQL `LIKE` deseni hâline getirir.
  ///
  /// `%` ve `_` kullanıcının yazdığı sıradan karakterler; desen operatörü
  /// olarak geçerlerse "%" araması her kaydı döndürür. Kaçış karakteri
  /// sorguda `ESCAPE '\'` ile bildiriliyor.
  static String likePattern(String foldedQuery) {
    final escaped = foldedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }
}
