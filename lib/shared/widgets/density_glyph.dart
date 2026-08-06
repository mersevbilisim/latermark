import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import 'glass_surface.dart';

/// Görünüm yoğunluğunu değiştiren düğme.
///
/// İkon bir sembol değil, eylemin kendisi: tek büyük kutu ortadan ikiye
/// bölünüp dört küçük kutuya ayrılır. Bu yüzden hangi duruma geçeceğini
/// açıklamaya gerek kalmıyor — hareketin kendisi anlatıyor.
class DensityToggle extends StatelessWidget {
  const DensityToggle({
    super.key,
    required this.split,
    required this.onPressed,
    this.size = 40,
  });

  /// `true` ise ızgara (bölünmüş), `false` ise tek sütun (bütün).
  final bool split;

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: split ? 'Büyük görünüme geç' : 'Izgara görünüme geç',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: GlassSurface.circle(
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: split ? 1 : 0),
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
                builder: (context, t, _) => CustomPaint(
                  size: const Size.square(17),
                  painter: _DensityPainter(t.clamp(0, 1), palette.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DensityPainter extends CustomPainter {
  const _DensityPainter(this.split, this.color);

  final double split;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;

    // Aradaki boşluk açıldıkça tek kutu dörde ayrılır.
    final gap = lerpDouble(0, 4.2, split)!;
    final cell = (size.width - gap) / 2;
    // Dış köşeler hep yuvarlak; iç köşeler ancak kutular ayrıldıkça yuvarlanır.
    final outer = Radius.circular(lerpDouble(4.5, 2.4, split)!);
    final inner = Radius.circular(lerpDouble(0, 2.4, split)!);

    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final rect = Rect.fromLTWH(
          col * (cell + gap),
          row * (cell + gap),
          cell,
          cell,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: row == 0 && col == 0 ? outer : inner,
            topRight: row == 0 && col == 1 ? outer : inner,
            bottomLeft: row == 1 && col == 0 ? outer : inner,
            bottomRight: row == 1 && col == 1 ? outer : inner,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DensityPainter old) =>
      old.split != split || old.color != color;
}
