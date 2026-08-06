import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/tr_format.dart';
import '../../../../shared/widgets/glass_surface.dart';

/// Süreli notların üzerinde duran küçük kum saati: kalan ömrü hem bir yay hem
/// de kısa bir metinle gösterir.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({
    super.key,
    required this.createdAt,
    required this.expiresAt,
    this.now,
  });

  final DateTime createdAt;
  final DateTime expiresAt;

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now();
    final total = expiresAt.difference(createdAt).inSeconds;
    final left = expiresAt.difference(reference).inSeconds;
    final progress = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);

    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      blur: 16,
      padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 13,
            child: CustomPaint(painter: _LifeRingPainter(progress)),
          ),
          const SizedBox(width: 6),
          Text(
            TrFormat.remainingShort(expiresAt, now: reference),
            style: OnPhotoText.caption.copyWith(
              color: OnPhoto.ink,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeRingPainter extends CustomPainter {
  const _LifeRingPainter(this.progress);

  /// 1 = yeni, 0 = süresi dolmak üzere.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = OnPhoto.inkGhost,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = OnPhoto.ember,
    );
  }

  @override
  bool shouldRepaint(_LifeRingPainter old) => old.progress != progress;
}
