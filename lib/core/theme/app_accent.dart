import 'package:flutter/material.dart';

import 'accent_tone.dart';

/// Latermark'ın kullanıcı tarafından seçilebilen vurgu renkleri.
///
/// Sıra veritabanında saklanır; mevcut değerleri yeniden sıralamayın. Altı
/// küratörlü ton her iki temada ve fotoğraf üstünde ayrı ayrı elle ayarlandı.
///
/// [custom] bu kürasyonu terk etmiyor, **sürdürüyor**: kullanıcı yalnızca tonu
/// seçiyor, parlaklık ve renklilik yine uygulamaya ait (bkz. [AccentTone]).
/// Ham bir RGB seçici üç zeminden (koyu, aydınlık, fotoğraf) en az birinde
/// okunmayan bir vurgu üretebilirdi.
enum AppAccent {
  orange,
  blue,
  violet,
  pink,
  green,
  gold,
  custom,

  /// Gümüş: tonu olmayan ton.
  ///
  /// Çemberde yeri yok — orada 360 derecenin tamamı renk. Gümüş bir "özel ton"
  /// değil, tonun **yokluğu**; o yüzden seçicide değil küratörlü şeritte
  /// duruyor.
  ///
  /// Bir fotoğraf makinesi uygulamasında en doğal vurgu da bu: nesnenin kendi
  /// rengi. Değerler [AccentTone]'un parlaklık hedeflerinden (koyu 0.760,
  /// aydınlık 0.520) kroma sıfırlanarak türetildi, yani diğer tonlarla aynı
  /// disiplinde. Ölçüldü: nötr, renkli tonların **hepsinden** okunaklı —
  /// koyuda 9.22 (renklinin en kötüsü 8.56), aydınlıkta 5.04 (4.71).
  ///
  /// Enum sırasının sonunda: mevcut indeksler veritabanında saklı ve
  /// kaydırılamaz. Şeritteki yeri [strip] ile ayrı veriliyor.
  silver;

  /// Ayarlardaki şeridin sırası.
  ///
  /// Enum sırası depolamaya ait; bu liste göze ait. Gümüş küratörlülerin
  /// yanında, özel yuva ise her zaman sonda duruyor.
  static const strip = [
    orange,
    blue,
    violet,
    pink,
    green,
    gold,
    silver,
    custom,
  ];

  static const defaultDark = Color(0xFFFF7A55);

  /// Aydınlık temanın turuncusu.
  ///
  /// Bir zamanlar `0xFFD9532B` idi: kendi sisteminin dışında kalan tek renk.
  /// Küratörlü aydınlık tonlar OKLCH'de L≈0.52–0.56 bandında duruyor, bu ise
  /// L≈0.61'deydi — kâğıt zemine karşı 3.69 ölçüyordu ve şeritteki sekiz
  /// rengin **tek** AA'yı tutamayanıydı. Üstelik varsayılan olduğu için de
  /// çoğu kullanıcının gördüğü renk oydu.
  ///
  /// Yeni değer aynı tondan (hue 36), yalnızca kendi ailesinin parlaklığına
  /// çekilmiş hâli: L=0.54, sayfa zemininde 4.98. Ton değişmiyor; turuncu
  /// hâlâ turuncu, yalnızca kâğıdın üstünde okunuyor.
  static const defaultLight = Color(0xFFB54628);
  static const defaultDarkGlow = Color(0x2BFF7A55);
  static const defaultLightGlow = Color(0x26B54628);

  /// Küratörlü tonun kendi çemberdeki yeri.
  ///
  /// Özel renge geçen kullanıcı sıfırdan başlamıyor: seçici, o an yürürlükte
  /// olan rengin tonundan açılıyor.
  int get hue => switch (this) {
    AppAccent.orange => 36,
    AppAccent.blue => 260,
    AppAccent.violet => 295,
    AppAccent.pink => 2,
    AppAccent.green => 164,
    AppAccent.gold => 85,
    // Gümüşten özel renge geçen kullanıcı bir tonla başlamalı; renksizlik
    // çemberde temsil edilemiyor.
    AppAccent.silver => AccentTone.defaultHue,
    AppAccent.custom => AccentTone.defaultHue,
  };

  /// [customHue] yalnızca [AppAccent.custom] için okunur.
  Color colorFor(
    Brightness brightness, {
    int customHue = AccentTone.defaultHue,
  }) {
    if (this == AppAccent.custom) {
      return AccentTone.colorFor(customHue, brightness);
    }
    return _curated(brightness);
  }

  /// Fotoğraf/vizör zemini temadan bağımsız olarak karanlıktır; burada her
  /// zaman koyu tema için seçilmiş daha parlak ton kullanılır.
  Color onPhotoFor({int customHue = AccentTone.defaultHue}) =>
      colorFor(Brightness.dark, customHue: customHue);

  Color _curated(Brightness brightness) => switch ((this, brightness)) {
    (AppAccent.orange, Brightness.dark) => defaultDark,
    (AppAccent.orange, Brightness.light) => defaultLight,
    (AppAccent.blue, Brightness.dark) => const Color(0xFF74A9FF),
    (AppAccent.blue, Brightness.light) => const Color(0xFF2867B9),
    (AppAccent.violet, Brightness.dark) => const Color(0xFFB69BFF),
    (AppAccent.violet, Brightness.light) => const Color(0xFF7352BD),
    (AppAccent.pink, Brightness.dark) => const Color(0xFFFF8AAD),
    (AppAccent.pink, Brightness.light) => const Color(0xFFBC456A),
    (AppAccent.green, Brightness.dark) => const Color(0xFF63CBA0),
    (AppAccent.green, Brightness.light) => const Color(0xFF247A5E),
    (AppAccent.gold, Brightness.dark) => const Color(0xFFE8BA55),
    (AppAccent.gold, Brightness.light) => const Color(0xFF8A680D),
    (AppAccent.silver, Brightness.dark) => const Color(0xFFB1B1B1),
    (AppAccent.silver, Brightness.light) => const Color(0xFF696969),
    // Özel renk buraya hiç düşmüyor; `colorFor` onu önce ayırıyor.
    (AppAccent.custom, _) => AccentTone.colorFor(
      AccentTone.defaultHue,
      brightness,
    ),
  };
}
