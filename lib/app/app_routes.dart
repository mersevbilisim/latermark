import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import 'back_swipe_route.dart';

/// Sayfa geçişleri.
///
/// Kamera, yığının üstüne "açılan bir örtücü" gibi gelir: karartma + ölçek.
/// Standart yatay kaydırma bu his için fazla sıradan kalıyor.
abstract final class AppRoutes {
  /// Ana ekrandan kameraya: sahne öne doğru büyüyerek gelir.
  static Route<T> shutter<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      opaque: true,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: AppMotion.ease,
          reverseCurve: AppMotion.exit,
        );
        final faded = FadeTransition(opacity: eased, child: child);
        if (MediaQuery.disableAnimationsOf(context)) return faded;
        return ScaleTransition(
          scale: Tween<double>(begin: 1.12, end: 1.0).animate(eased),
          child: faded,
        );
      },
    );
  }

  /// Kameradan yazma ekranına: fotoğraf yerinde kalır, panel alttan yükselir.
  ///
  /// Sayfa kenardan geri çekilebiliyor. Bu rotalar opak olduğu için hareket
  /// sayfanın gövdesine değil rotanın kendi denetleyicisine bağlı — detay
  /// sayfasındaki saydam çözümün neden burada işe yaramadığı
  /// [BackSwipeRoute]'un başında yazıyor.
  static Route<T> lift<T>(Widget page) =>
      BackSwipeRoute<T>(builder: (_) => page);

  /// Fotoğraf detayı: alttaki akışı canlı tutar; böylece fotoğraf aşağı
  /// çekildiğinde detay bir perde gibi kapanmak yerine ana ekranı açığa çıkarır.
  static Route<T> photoDetail<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppMotion.medium,
      reverseTransitionDuration: const Duration(milliseconds: 240),
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: AppMotion.exit,
        );
        final faded = FadeTransition(opacity: eased, child: child);
        if (MediaQuery.disableAnimationsOf(context)) return faded;
        return ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(eased),
          child: faded,
        );
      },
    );
  }
}
