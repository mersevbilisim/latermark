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
  custom;

  static const defaultDark = Color(0xFFFF7A55);
  static const defaultLight = Color(0xFFD9532B);
  static const defaultDarkGlow = Color(0x2BFF7A55);
  static const defaultLightGlow = Color(0x26D9532B);

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
    AppAccent.custom => AccentTone.defaultHue,
  };

  /// [customHue] yalnızca [AppAccent.custom] için okunur.
  Color colorFor(Brightness brightness, {int customHue = AccentTone.defaultHue}) {
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
    // Özel renk buraya hiç düşmüyor; `colorFor` onu önce ayırıyor.
    (AppAccent.custom, _) => AccentTone.colorFor(AccentTone.defaultHue, brightness),
  };
}
