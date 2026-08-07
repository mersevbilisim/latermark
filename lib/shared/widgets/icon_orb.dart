import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'glass_surface.dart';
import 'pressable.dart';

/// Yuvarlak cam ikon düğmesi.
///
/// Varsayılan renkleri fotoğraf üzerinde durmaya göredir ([OnPhoto]); temalı
/// zeminlerde kullanılırken [tint] ve [fill] açıkça verilir.
class IconOrb extends StatelessWidget {
  const IconOrb({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 40,
    this.iconSize = 19,
    this.tint = OnPhoto.ink,
    this.fill,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color tint;

  /// Cam dolgusu. Boşsa fotoğraf üstü değeri kullanılır.
  final Color? fill;

  /// Etkin durumda (ör. açık flaş) dolgu kor rengine döner.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final effectiveFill = active
        ? const Color(0xE62D1711)
        : fill ?? OnPhoto.canvasDeep.withValues(alpha: 0.78);

    return Pressable(
      onPressed: onPressed,
      scale: 0.9,
      semanticLabel: semanticLabel,
      child: GlassSurface.circle(
        tint: effectiveFill,
        borderColor: active
            ? OnPhoto.ember.withValues(alpha: 0.60)
            : (fill == null ? OnPhoto.hairlineBright : null),
        elevation: fill == null ? 10 : 0,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: iconSize,
            color: active ? OnPhoto.ember : tint,
          ),
        ),
      ),
    );
  }
}
