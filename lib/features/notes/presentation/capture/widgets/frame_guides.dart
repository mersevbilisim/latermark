import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';

/// Önizlemenin dört köşesindeki ince ayraçlar.
///
/// Ekranın "bir vizör" olduğunu tek bir çizgiyle anlatır; ızgara veya
/// çerçeve gibi görüntüyü boğan öğelere gerek bırakmaz.
class FrameGuides extends StatelessWidget {
  const FrameGuides({super.key, this.inset = 22, this.arm = 26});

  final double inset;
  final double arm;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top + 56,
          bottom: padding.bottom + 148,
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: _GuidesPainter(inset: inset, arm: arm),
        ),
      ),
    );
  }
}

class _GuidesPainter extends CustomPainter {
  const _GuidesPainter({required this.inset, required this.arm});

  final double inset;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = OnPhoto.ink.withValues(alpha: 0.42);

    const radius = 6.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    final path = Path()
      // Sol üst
      ..moveTo(left, top + arm)
      ..lineTo(left, top + radius)
      ..quadraticBezierTo(left, top, left + radius, top)
      ..lineTo(left + arm, top)
      // Sağ üst
      ..moveTo(right - arm, top)
      ..lineTo(right - radius, top)
      ..quadraticBezierTo(right, top, right, top + radius)
      ..lineTo(right, top + arm)
      // Sağ alt
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom - radius)
      ..quadraticBezierTo(right, bottom, right - radius, bottom)
      ..lineTo(right - arm, bottom)
      // Sol alt
      ..moveTo(left + arm, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius)
      ..lineTo(left, bottom - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GuidesPainter old) =>
      old.inset != inset || old.arm != arm;
}
