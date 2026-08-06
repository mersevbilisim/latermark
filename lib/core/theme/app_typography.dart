import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Tipografi ölçeği — yalnızca boyut, ağırlık ve aralık.
///
/// Renk buraya girmez; o paletin işidir. Hazır renkli stiller için
/// `context.palette.caption` gibi uzantılara bakın.
abstract final class AppType {
  /// Apple platformlarında sistem yazı tipi (SF Pro), diğerlerinde varsayılan.
  static String? get fontFamily => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => '.SF Pro Text',
    _ => null,
  };

  static const display = TextStyle(
    fontSize: 34,
    height: 1.06,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
  );

  static const title = TextStyle(
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.42,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
  );

  static const bodyStrong = TextStyle(
    fontSize: 16,
    height: 1.32,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static const label = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  /// Bölüm başlıkları ve rozetler için harfleri açılmış küçük kapiteller.
  static const overline = TextStyle(
    fontSize: 10.5,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.7,
  );
}
