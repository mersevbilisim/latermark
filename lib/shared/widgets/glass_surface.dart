import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Işığı taklit eden katmanlı yüzey.
///
/// Varsayılan yol arka planı yeniden örneklemez. Opak bir taban, üst kenarda
/// ince bir ışık ve altta hafif bir ton farkıyla derinlik kurar. Bu, canlı
/// kamera ve kayan listelerde `BackdropFilter` maliyeti olmadan aynı görsel
/// hiyerarşiyi verir.
///
/// [tint] ve [borderColor] verilmezse yürürlükteki paletten alınır. Fotoğrafın
/// üzerinde duran yüzeyler bunları [OnPhoto] değerleriyle açıkça geçmeli —
/// orada cam, temadan bağımsız olarak açık kalır.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.tint,
    this.borderColor,
    this.border = true,
    this.padding = EdgeInsets.zero,
    this.elevation = 0,
  });

  /// Tam daire yüzeyler (ikon düğmeleri) için kısayol.
  const GlassSurface.circle({
    super.key,
    required this.child,
    this.tint,
    this.borderColor,
    this.border = true,
    this.padding = EdgeInsets.zero,
    this.elevation = 0,
  }) : borderRadius = const BorderRadius.all(Radius.circular(999));

  final Widget child;
  final BorderRadius borderRadius;
  final Color? tint;
  final Color? borderColor;
  final bool border;
  final EdgeInsetsGeometry padding;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final base = tint ?? palette.canvasLift;
    final top = Color.lerp(base, Colors.white, palette.isDark ? 0.055 : 0.32)!;
    final bottom = Color.lerp(
      base,
      palette.isDark ? Colors.black : palette.canvasSunk,
      palette.isDark ? 0.08 : 0.12,
    )!;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base, bottom],
          stops: const [0, 0.42, 1],
        ),
        borderRadius: borderRadius,
        border: border
            ? Border.all(color: borderColor ?? palette.hairline, width: 0.5)
            : null,
        boxShadow: elevation <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.28 : 0.13,
                  ),
                  blurRadius: elevation,
                  offset: Offset(0, elevation * 0.34),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );

    return surface;
  }
}
