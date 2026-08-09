import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/aperture.dart';
import '../../../shared/widgets/icon_orb.dart';

/// Latermark'ın cihaz-içi veri yaklaşımını ürün diliyle anlatan kısa sayfa.
///
/// Yasal metnin özeti değildir. Kullanıcının gerçekten merak ettiği beş
/// noktayı, kart veya akordeon kalabalığı olmadan tek bir güven izi üzerinde
/// anlatır.
class YourDataPage extends StatelessWidget {
  const YourDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final horizontalInset = media.size.width <= 320 ? 16.0 : 22.0;
    final questions = <_PrivacyCopy>[
      _PrivacyCopy(
        icon: Icons.lock_outline_rounded,
        question: l10n.yourDataSafetyQuestion,
        answer: l10n.yourDataSafetyAnswer,
      ),
      _PrivacyCopy(
        icon: Icons.location_on_outlined,
        question: l10n.yourDataLocationQuestion,
        answer: l10n.yourDataLocationAnswer,
      ),
      _PrivacyCopy(
        icon: Icons.photo_library_outlined,
        question: l10n.yourDataPhotosQuestion,
        answer: l10n.yourDataPhotosAnswer,
      ),
      _PrivacyCopy(
        icon: Icons.notifications_none_rounded,
        question: l10n.yourDataRemindersQuestion,
        answer: l10n.yourDataRemindersAnswer,
      ),
      _PrivacyCopy(
        icon: Icons.delete_outline_rounded,
        question: l10n.yourDataDeletionQuestion,
        answer: l10n.yourDataDeletionAnswer,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(palette.brightness),
      child: Scaffold(
        backgroundColor: palette.canvas,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.72),
              radius: 1.08,
              colors: [
                Color.lerp(
                  palette.canvas,
                  palette.ember,
                  palette.isDark ? 0.045 : 0.028,
                )!,
                palette.canvas,
              ],
              stops: const [0, 0.78],
            ),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _YourDataHeader(
                  palette: palette,
                  topPadding: media.padding.top,
                  title: l10n.yourDataTitle,
                  backLabel: l10n.actionBack,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset + media.padding.left,
                  18,
                  horizontalInset + media.padding.right,
                  media.padding.bottom + 42,
                ),
                sliver: SliverList.list(
                  children: [
                    const Center(child: _OnDeviceSeal()),
                    const SizedBox(height: 30),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Semantics(
                          header: true,
                          namesRoute: true,
                          child: Text(
                            l10n.yourDataTitle,
                            textAlign: TextAlign.center,
                            style: palette.display.copyWith(
                              fontSize: 32,
                              height: 1.08,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Text(
                          l10n.yourDataSubtitle,
                          textAlign: TextAlign.center,
                          style: palette.bodyStrong.copyWith(
                            color: palette.inkSoft,
                            fontSize: 17,
                            height: 1.38,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 54),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          children: [
                            for (var i = 0; i < questions.length; i++)
                              _PrivacyEntry(
                                copy: questions[i],
                                isLast: i == questions.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyCopy {
  const _PrivacyCopy({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}

class _PrivacyEntry extends StatelessWidget {
  const _PrivacyEntry({required this.copy, required this.isLast});

  final _PrivacyCopy copy;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(copy.icon, size: 19, color: palette.ember),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    copy.question,
                    style: palette.title.copyWith(
                      fontSize: 19,
                      height: 1.2,
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 33),
            child: Text(
              copy.answer,
              style: palette.body.copyWith(
                color: palette.inkSoft,
                fontSize: 15.5,
                height: 1.5,
              ),
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 33, top: 30),
              child: SizedBox(
                width: 42,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.hairlineBright, palette.hairline],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Latermark diyaframını cihazın dışına taşmayan kapalı bir yörüngeye alır.
/// Dekoratif bir kalkan yerine ürünün kendi imzası güven fikrini anlatır.
class _OnDeviceSeal extends StatelessWidget {
  const _OnDeviceSeal();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: SizedBox(
        width: 122,
        height: 126,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DeviceOrbitPainter(
                  ink: palette.ink,
                  faint: palette.inkFaint,
                  accent: palette.ember,
                ),
              ),
            ),
            SizedBox.square(
              dimension: 42,
              child: Aperture(
                openness: 0.52,
                twist: 0.05,
                edgeTint: palette.ember,
                bladeBase: palette.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceOrbitPainter extends CustomPainter {
  const _DeviceOrbitPainter({
    required this.ink,
    required this.faint,
    required this.accent,
  });

  final Color ink;
  final Color faint;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final device = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 72, height: 112),
      const Radius.circular(21),
    );
    final devicePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = ink.withValues(alpha: 0.62);
    canvas.drawRRect(device, devicePaint);

    canvas.drawLine(
      Offset(center.dx - 8, device.bottom - 8),
      Offset(center.dx + 8, device.bottom - 8),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1
        ..color = faint,
    );

    final orbit = Rect.fromCenter(center: center, width: 116, height: 86);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.34);
    canvas.drawArc(orbit, math.pi * 0.18, math.pi * 0.72, false, orbitPaint);
    canvas.drawArc(orbit, math.pi * 1.18, math.pi * 0.72, false, orbitPaint);

    for (final angle in [math.pi * 0.18, math.pi * 1.18]) {
      final point = Offset(
        center.dx + orbit.width / 2 * math.cos(angle),
        center.dy + orbit.height / 2 * math.sin(angle),
      );
      canvas.drawCircle(point, 2.2, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_DeviceOrbitPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.faint != faint ||
      oldDelegate.accent != accent;
}

class _YourDataHeader extends SliverPersistentHeaderDelegate {
  const _YourDataHeader({
    required this.palette,
    required this.topPadding,
    required this.title,
    required this.backLabel,
  });

  final AppPalette palette;
  final double topPadding;
  final String title;
  final String backLabel;

  @override
  double get maxExtent => topPadding + 62;

  @override
  double get minExtent => topPadding + 58;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final t = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(palette.brightness),
      child: ColoredBox(
        // DEĞİŞİKLİK BURADA: Arka planı kaydırma oranına göre şeffaflaştırıyoruz
        color: palette.canvas.withValues(alpha: eased),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 22,
              top: topPadding + 7,
              child: IconOrb(
                icon: Icons.arrow_back_rounded,
                semanticLabel: backLabel,
                onPressed: () => Navigator.of(context).maybePop(),
                size: 44,
                iconSize: 18,
                tint: palette.ink,
                fill: palette.canvasLift,
              ),
            ),
            Positioned(
              left: 72,
              right: 72,
              top: topPadding,
              height: 58,
              child: Opacity(
                opacity: eased,
                child: ExcludeSemantics(
                  child: Center(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: palette.title.copyWith(
                          fontSize: 18,
                          letterSpacing: -0.28,
                        ),
                      ),
                    ),
                  ),
                ),
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
                  child: const SizedBox(height: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_YourDataHeader oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.topPadding != topPadding ||
      oldDelegate.title != title ||
      oldDelegate.backLabel != backLabel;
}
