import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Arkasını bulanıklaştıran buzlu cam yüzey.
///
/// Uygulamadaki tüm panel, çubuk ve rozetler bunun üzerine kurulur; böylece
/// derinlik hissi tek yerden ayarlanır.
///
/// [tint] ve [borderColor] verilmezse yürürlükteki paletten alınır. Fotoğrafın
/// üzerinde duran yüzeyler bunları [OnPhoto] değerleriyle açıkça geçmeli —
/// orada cam, temadan bağımsız olarak açık kalır.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 24,
    this.tint,
    this.borderColor,
    this.border = true,
    this.padding = EdgeInsets.zero,
  });

  /// Tam daire yüzeyler (ikon düğmeleri) için kısayol.
  const GlassSurface.circle({
    super.key,
    required this.child,
    this.blur = 20,
    this.tint,
    this.borderColor,
    this.border = true,
    this.padding = EdgeInsets.zero,
  }) : borderRadius = const BorderRadius.all(Radius.circular(999));

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final bool border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? palette.glass,
            borderRadius: borderRadius,
            border: border
                ? Border.all(
                    color: borderColor ?? palette.hairline,
                    width: 0.5,
                  )
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
