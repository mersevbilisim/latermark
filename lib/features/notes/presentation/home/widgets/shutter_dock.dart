import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/aperture.dart';
import '../../../../../shared/widgets/icon_orb.dart';

/// Deklanşörün ana ekrandaki yeri.
///
/// Uygulama boşken diyafram ekranın ortasında, nefes alarak durur ve altında
/// ne yapılacağını söyleyen iki satır vardır. İlk not kaydedildiği anda
/// küçülüp aşağı, akışın üstündeki yerine kayar. Böylece uygulama kullanıcıyla
/// birlikte büyür — iki ayrı ekran yerine tek bir sürekli hareket.
class ShutterDock extends StatelessWidget {
  const ShutterDock({
    super.key,
    required this.docked,
    required this.onCapture,
    this.onOpenSettings,
  });

  /// `true` ise aşağıya yerleşmiş, `false` ise ortada davet ediyor.
  final bool docked;

  final VoidCallback onCapture;

  /// Boş ekranda başlık çubuğu olmadığı için ayarlara giriş buradan verilir.
  final VoidCallback? onOpenSettings;

  /// Akışın alt boşluğu bu değere göre ayarlanır.
  static const dockHeight = 148.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: docked ? 1 : 0),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeOutQuart,
      builder: (context, t, _) {
        return Stack(
          children: [
            // Kartlar düğmenin altından geçerken okunurluğu koruyan perde.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: dockHeight + safeBottom,
              child: IgnorePointer(
                child: Opacity(
                  opacity: t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // Düğmenin oturduğu yükseklikte perde tamamen kapalı
                        // olmalı; yarı saydam kalırsa altındaki kartın yazısı
                        // diyaframın içinden okunuyor.
                        colors: [
                          palette.canvas.withValues(alpha: 0),
                          palette.canvas.withValues(alpha: 0.85),
                          palette.canvas,
                        ],
                        stops: const [0.0, 0.34, 0.58],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Align(
              alignment: Alignment.lerp(
                const Alignment(0, -0.08),
                Alignment.bottomCenter,
                t,
              )!,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: lerpDouble(0, 20 + safeBottom, t)!,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ApertureButton(
                      size: lerpDouble(112, 68, t)!,
                      breathing: !docked,
                      bladeBase: palette.canvas,
                      edgeTint: palette.ink,
                      onPressed: onCapture,
                    ),
                    ClipRect(
                      child: Align(
                        heightFactor: (1 - t).clamp(0.0, 1.0),
                        child: Opacity(
                          opacity: (1 - t * 2).clamp(0.0, 1.0),
                          child: _Invitation(onOpenSettings: onOpenSettings),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dokun ve çek', style: palette.bodyStrong),
          const SizedBox(height: 8),
          SizedBox(
            width: 250,
            child: Text(
              'Fiş, park yeri, bir parça…\nFotoğrafla, iki kelime yaz, unut.',
              textAlign: TextAlign.center,
              style: palette.caption.copyWith(
                color: palette.inkSoft,
                height: 1.45,
              ),
            ),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 28),
            IconOrb(
              icon: Icons.tune_rounded,
              semanticLabel: 'Ayarlar',
              onPressed: onOpenSettings,
              size: 38,
              iconSize: 18,
              tint: palette.inkSoft,
              fill: palette.glass,
            ),
          ],
        ],
      ),
    );
  }
}
