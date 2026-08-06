import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'app_typography.dart';

/// Açık ve koyu tema aynı iskeletten, yalnızca palet değiştirilerek üretilir.
abstract final class AppTheme {
  static ThemeData dark() => _build(AppPalette.dark);
  static ThemeData light() => _build(AppPalette.light);

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
