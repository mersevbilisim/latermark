import 'package:flutter/material.dart';

/// Latermark'ın kullanıcı tarafından seçilebilen vurgu renkleri.
///
/// Sıra veritabanında saklanır; mevcut değerleri yeniden sıralamayın. Keyfî
/// bir renk seçici yerine her iki temada da okunurluğu ayrı ayrı ayarlanmış,
/// fotoğraf üstünde de canlı kalan küçük bir kürasyon sunulur.
enum AppAccent {
  orange,
  blue,
  violet,
  pink,
  green,
  gold;

  static const defaultDark = Color(0xFFFF7A55);
  static const defaultLight = Color(0xFFD9532B);
  static const defaultDarkGlow = Color(0x2BFF7A55);
  static const defaultLightGlow = Color(0x26D9532B);

  Color colorFor(Brightness brightness) => switch ((this, brightness)) {
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
  };

  /// Fotoğraf/vizör zemini temadan bağımsız olarak karanlıktır; burada her
  /// zaman koyu tema için seçilmiş daha parlak ton kullanılır.
  Color get onPhoto => colorFor(Brightness.dark);
}
