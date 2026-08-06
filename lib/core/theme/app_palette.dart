import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Uygulamanın renk paleti.
///
/// Açık ve koyu iki örneği vardır ve tema uzantısı olarak taşınır; hiçbir
/// widget içinde ham `Color(0x...)` yazılmaz.
///
/// Fotoğrafın *üzerinde* duran öğeler bu paletin dışındadır — bkz. [OnPhoto].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.canvasLift,
    required this.canvasSunk,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.inkGhost,
    required this.glass,
    required this.glassStrong,
    required this.hairline,
    required this.hairlineBright,
    required this.ember,
    required this.emberGlow,
    required this.danger,
  });

  final Brightness brightness;

  /// Ana zemin.
  final Color canvas;

  /// Zeminin bir tık üstü: paneller, ayar satırları.
  final Color canvasLift;

  /// Zeminin altı: gradyan uçları, boş fotoğraf yeri.
  final Color canvasSunk;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color inkGhost;

  /// Buzlu cam yüzeyler.
  final Color glass;
  final Color glassStrong;

  final Color hairline;
  final Color hairlineBright;

  /// Tek vurgu rengi: sıcak kor.
  final Color ember;
  final Color emberGlow;

  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  /// Karanlık: fotoğrafın önde, arayüzün geride durduğu asıl hâl.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0A0C),
    canvasLift: Color(0xFF141418),
    canvasSunk: Color(0xFF050506),
    ink: Color(0xFFF3F1ED),
    inkSoft: Color(0x8CF3F1ED),
    inkFaint: Color(0x52F3F1ED),
    inkGhost: Color(0x24F3F1ED),
    glass: Color(0x14FFFFFF),
    glassStrong: Color(0x1FFFFFFF),
    hairline: Color(0x1AFFFFFF),
    hairlineBright: Color(0x33FFFFFF),
    ember: Color(0xFFFF7A55),
    emberGlow: Color(0x2BFF7A55),
    danger: Color(0xFFFF5A5A),
  );

  /// Aydınlık: soğuk beyaz değil, hafif sıcak bir kâğıt.
  ///
  /// Kor rengi burada koyulaşır — açık zeminde aynı turuncu okunmuyor.
  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF7F5F1),
    canvasLift: Color(0xFFFFFFFF),
    canvasSunk: Color(0xFFE9E6E0),
    ink: Color(0xFF131316),
    inkSoft: Color(0x8C131316),
    inkFaint: Color(0x59131316),
    inkGhost: Color(0x24131316),
    glass: Color(0x0A000000),
    glassStrong: Color(0x14000000),
    hairline: Color(0x14000000),
    hairlineBright: Color(0x26000000),
    ember: Color(0xFFD9532B),
    emberGlow: Color(0x26D9532B),
    danger: Color(0xFFC62B2B),
  );

  @override
  AppPalette copyWith({Brightness? brightness}) =>
      brightness == null || brightness == this.brightness
      ? this
      : (brightness == Brightness.dark ? dark : light);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasLift: Color.lerp(canvasLift, other.canvasLift, t)!,
      canvasSunk: Color.lerp(canvasSunk, other.canvasSunk, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      inkGhost: Color.lerp(inkGhost, other.inkGhost, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineBright: Color.lerp(hairlineBright, other.hairlineBright, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      emberGlow: Color.lerp(emberGlow, other.emberGlow, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Fotoğrafın üzerinde duran öğelerin renkleri.
///
/// Bunlar temayla dönmez. Bir kareyi hangi temada açarsan aç, üstündeki yazı
/// açık, perdesi koyu olmalı — fotoğrafın kendi parlaklığı temadan bağımsızdır.
/// Kamera vizörü ve tam ekran fotoğraf görünümü de her zaman koyudur.
abstract final class OnPhoto {
  static const ink = Color(0xFFF3F1ED);
  static const inkSoft = Color(0x8CF3F1ED);
  static const inkFaint = Color(0x52F3F1ED);
  static const inkGhost = Color(0x24F3F1ED);
  static const glass = Color(0x14FFFFFF);
  static const glassStrong = Color(0x1FFFFFFF);
  static const hairline = Color(0x1AFFFFFF);
  static const hairlineBright = Color(0x33FFFFFF);
  static const ember = Color(0xFFFF7A55);
  static const emberGlow = Color(0x2BFF7A55);
  static const danger = Color(0xFFFF5A5A);

  /// Vizör ve tam ekran fotoğraf zemini.
  static const canvas = Color(0xFF0A0A0C);
  static const canvasDeep = Color(0xFF050506);

  /// Deklanşör patlaması.
  static const flash = Color(0xFFFFFFFF);
}

/// Palete bağlı hazır metin stilleri.
///
/// `context.palette.caption` yazmak, her çağrı yerinde `copyWith(color: ...)`
/// tekrarlamaktan hem kısa hem de tutarlı.
extension PaletteText on AppPalette {
  TextStyle get display => AppType.display.copyWith(color: ink);
  TextStyle get title => AppType.title.copyWith(color: ink);
  TextStyle get body => AppType.body.copyWith(color: ink);
  TextStyle get bodyStrong => AppType.bodyStrong.copyWith(color: ink);
  TextStyle get label => AppType.label.copyWith(color: inkSoft);
  TextStyle get caption => AppType.caption.copyWith(color: inkFaint);
  TextStyle get overline => AppType.overline.copyWith(color: inkFaint);
}

/// Fotoğraf üstündeki metinler için aynı ölçek.
abstract final class OnPhotoText {
  static final display = AppType.display.copyWith(color: OnPhoto.ink);
  static final title = AppType.title.copyWith(color: OnPhoto.ink);
  static final body = AppType.body.copyWith(color: OnPhoto.ink);
  static final bodyStrong = AppType.bodyStrong.copyWith(color: OnPhoto.ink);
  static final label = AppType.label.copyWith(color: OnPhoto.inkSoft);
  static final caption = AppType.caption.copyWith(color: OnPhoto.inkFaint);
  static final overline = AppType.overline.copyWith(color: OnPhoto.inkFaint);
}

extension PaletteContext on BuildContext {
  /// Yürürlükteki palet. Tema uzantısı her zaman tanımlı olduğu için güvenli.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
