import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accent_tone.dart';
import 'app_accent.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Açık ve koyu tema aynı iskeletten, yalnızca palet değiştirilerek üretilir.
abstract final class AppTheme {
  static ThemeData dark([
    AppAccent accent = AppAccent.orange,
    int customHue = AccentTone.defaultHue,
  ]) => _build(AppPalette.forAccent(Brightness.dark, accent, customHue: customHue));

  static ThemeData light([
    AppAccent accent = AppAccent.orange,
    int customHue = AccentTone.defaultHue,
  ]) => _build(
    AppPalette.forAccent(Brightness.light, accent, customHue: customHue),
  );

  static ThemeData _build(AppPalette palette) {
    final base = ThemeData(
      brightness: palette.brightness,
      useMaterial3: true,
      fontFamily: AppType.fontFamily,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.ember,
        brightness: palette.brightness,
        surface: palette.canvas,
        primary: palette.ink,
        onPrimary: palette.canvas,
        secondary: palette.ember,
        error: palette.danger,
      ),
    );

    return base.copyWith(
      extensions: [palette],
      textTheme: base.textTheme.apply(
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.ember,
        selectionColor: palette.emberGlow,
        selectionHandleColor: palette.ember,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Durum çubuğu ikonlarının zemine göre okunması için.
  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final light = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: light
          ? Brightness.light
          : Brightness.dark,
    );
  }

  /// Fotoğrafın hâkim olduğu ekranlar (vizör, tam ekran kare) her zaman koyu.
  static const overlayOnPhoto = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
