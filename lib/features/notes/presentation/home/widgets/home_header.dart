import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/tr_format.dart';
import '../../../../../shared/widgets/density_glyph.dart';
import '../../../../../shared/widgets/icon_orb.dart';

/// Kaydırıldıkça büyük başlıktan ince bir çubuğa dönüşen üstlük.
///
/// Yükseklik, yazı boyutu, sayaç ve arka bulanıklık aynı `t` değeriyle
/// sürülür; böylece hepsi tek bir jestle birlikte hareket eder.
class HomeHeader extends SliverPersistentHeaderDelegate {
  const HomeHeader({
    required this.palette,
    required this.topPadding,
    required this.noteCount,
    required this.gridded,
    required this.onToggleDensity,
    required this.onOpenSettings,
  });

  final AppPalette palette;
  final double topPadding;
  final int noteCount;
  final bool gridded;
  final VoidCallback onToggleDensity;
  final VoidCallback onOpenSettings;

  static const _expandedHeight = 116.0;
  static const _collapsedHeight = 56.0;

  @override
  double get maxExtent => topPadding + _expandedHeight;

  @override
  double get minExtent => topPadding + _collapsedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);

    final header = Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Stack(
        children: [
          Positioned(
            left: 22,
            right: 22,
            bottom: lerpDouble(20, 15, eased)!,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sayaç, başlık küçüldükçe onun altından kayıp gider.
                      ClipRect(
                        child: Align(
                          heightFactor: (1 - eased * 1.4).clamp(0.0, 1.0),
                          alignment: Alignment.bottomLeft,
                          child: Opacity(
                            opacity: (1 - eased * 2).clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                TrFormat.upper(TrFormat.noteCount(noteCount)),
                                style: palette.overline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Notlar',
                        style: palette.display.copyWith(
                          fontSize: lerpDouble(34, 19, eased),
                          letterSpacing: lerpDouble(-0.9, -0.3, eased),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DensityToggle(
                  split: gridded,
                  onPressed: onToggleDensity,
                  size: 38,
                ),
                const SizedBox(width: 8),
                IconOrb(
                  icon: Icons.tune_rounded,
                  semanticLabel: 'Ayarlar',
                  onPressed: onOpenSettings,
                  size: 38,
                  iconSize: 18,
                  tint: palette.ink,
                  fill: palette.glass,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: eased,
              child: ColoredBox(
                color: palette.hairline,
                child: const SizedBox(height: 0.5, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );

    // Bulanıklık yalnızca gerçekten kaydırıldığında devreye girer; boştayken
    // her karede pahalı bir katman oluşturmanın anlamı yok.
    if (t < 0.01) {
      return ColoredBox(color: palette.canvas, child: header);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20 * eased, sigmaY: 20 * eased),
        child: ColoredBox(
          color: palette.canvas.withValues(alpha: lerpDouble(1, 0.72, eased)!),
          child: header,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(HomeHeader old) =>
      old.topPadding != topPadding ||
      old.noteCount != noteCount ||
      old.gridded != gridded ||
      old.palette != palette;
}

/// Akıştaki gün ayıracı: küçük kapiteller ve peşinden giden ince bir çizgi.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
      child: Row(
        children: [
          Text(TrFormat.dayHeader(day), style: palette.overline),
          const SizedBox(width: 12),
          Expanded(
            child: ColoredBox(
              color: palette.hairline,
              child: const SizedBox(height: 0.5, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}
