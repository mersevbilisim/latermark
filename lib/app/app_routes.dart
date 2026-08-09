import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

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
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.12, end: 1.0).animate(eased),
            child: child,
          ),
        );
      },
    );
  }

  /// Kameradan yazma ekranına: fotoğraf yerinde kalır, panel alttan yükselir.
  static Route<T> lift<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: AppMotion.medium,
      reverseTransitionDuration: AppMotion.medium,
      opaque: true,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: eased,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(eased),
            child: child,
          ),
        );
      },
    );
  }

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
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: .985, end: 1).animate(eased),
            child: child,
          ),
        );
      },
    );
  }
}
