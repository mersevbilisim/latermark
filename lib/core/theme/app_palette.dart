import 'package:flutter/material.dart';

import 'app_accent.dart';
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
    required this.accent,
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
    required this.onPhotoAccent,
    required this.onPhotoAccentGlow,
    required this.danger,
  });

  /// Bu paleti üreten kullanıcı tercihi. Parlaklık kopyalanırken vurgu
  /// seçiminin varsayılan turuncuya dönmesini önler.
  final AppAccent accent;

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

  /// Kullanıcının seçtiği tek vurgu rengi.
  ///
  /// `ember` adı widget API'sinde geriye dönük olarak korunuyor; değer artık
  /// turuncuya sabit değil, [AppAccent] seçiminden üretiliyor.
  final Color ember;
  final Color emberGlow;

  /// Vizör ve fotoğraf üzerindeki öğeler için aynı seçimin canlı koyu-zemin
  /// tonu. Bunlar açık tema seçiliyken de fotoğraf üzerinde okunur kalır.
  final Color onPhotoAccent;
  final Color onPhotoAccentGlow;

  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  /// Karanlık: fotoğrafın önde, arayüzün geride durduğu asıl hâl.
  static const dark = AppPalette(
    accent: AppAccent.orange,
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
    ember: AppAccent.defaultDark,
    emberGlow: AppAccent.defaultDarkGlow,
    onPhotoAccent: AppAccent.defaultDark,
    onPhotoAccentGlow: AppAccent.defaultDarkGlow,
    danger: Color(0xFFFF5A5A),
  );

  /// Aydınlık: soğuk beyaz değil, hafif sıcak bir kâğıt.
  ///
  /// Kor rengi burada koyulaşır — açık zeminde aynı turuncu okunmuyor.
  static const light = AppPalette(
    accent: AppAccent.orange,
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
    ember: AppAccent.defaultLight,
    emberGlow: AppAccent.defaultLightGlow,
    onPhotoAccent: AppAccent.defaultDark,
    onPhotoAccentGlow: AppAccent.defaultDarkGlow,
    danger: Color(0xFFC62B2B),
  );

  /// Nötr paleti bozmadan yalnızca gerçek vurgu kanallarını değiştirir.
  static AppPalette forAccent(Brightness brightness, AppAccent accent) {
    final base = brightness == Brightness.dark ? dark : light;
    if (accent == AppAccent.orange) return base;
    final color = accent.colorFor(brightness);
    final photo = accent.onPhoto;
    return base._withAccent(
      accent,
      color,
      color.withValues(alpha: brightness == Brightness.dark ? 0.17 : 0.15),
      photo,
      photo.withValues(alpha: 0.17),
    );
  }

  AppPalette _withAccent(
    AppAccent accent,
    Color color,
    Color glow,
    Color photo,
    Color photoGlow,
  ) => AppPalette(
    accent: accent,
    brightness: brightness,
    canvas: canvas,
    canvasLift: canvasLift,
    canvasSunk: canvasSunk,
    ink: ink,
    inkSoft: inkSoft,
    inkFaint: inkFaint,
    inkGhost: inkGhost,
    glass: glass,
    glassStrong: glassStrong,
    hairline: hairline,
    hairlineBright: hairlineBright,
    ember: color,
    emberGlow: glow,
    onPhotoAccent: photo,
    onPhotoAccentGlow: photoGlow,
    danger: danger,
  );

  @override
  AppPalette copyWith({Brightness? brightness}) =>
      brightness == null || brightness == this.brightness
      ? this
      : AppPalette.forAccent(brightness, accent);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      accent: t < 0.5 ? accent : other.accent,
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
      onPhotoAccent: Color.lerp(onPhotoAccent, other.onPhotoAccent, t)!,
      onPhotoAccentGlow: Color.lerp(
        onPhotoAccentGlow,
        other.onPhotoAccentGlow,
        t,
      )!,
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
