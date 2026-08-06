import 'package:flutter/animation.dart';

/// Hareket dili. Tüm animasyonlar bu üç süre ve iki eğriden türer; böylece
/// uygulama tek bir ritimde nefes alır.
abstract final class AppMotion {
  /// Dokunma geri bildirimi — göz kırpma hızında.
  static const fast = Duration(milliseconds: 180);

  /// Standart geçiş — panel açılması, seçim kayması.
  static const medium = Duration(milliseconds: 340);

  /// Sahne değişimi — sayfa geçişleri, düzen morflaması.
  static const slow = Duration(milliseconds: 620);

  /// Diyaframın boşta nefes alma döngüsü.
  static const breath = Duration(milliseconds: 4200);

  /// Yavaşlayarak yerine oturan hareketler (varsayılan).
  static const ease = Curves.easeOutCubic;

  /// Fiziksel his gereken yerlerde (kayan seçim pili, deklanşör).
  static const spring = Curves.easeOutBack;

  /// Kaybolan öğeler.
  static const exit = Curves.easeInCubic;
}
