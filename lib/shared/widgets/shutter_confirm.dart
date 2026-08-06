import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';
import 'aperture.dart';

/// Bir kaydı silmek için onay.
///
/// Burada "Sil / Vazgeç" düğmeleri yok. Silmek, kareyi çeken diyaframın
/// **basılı tutularak kapatılmasıyla** olur: parmağını bastıkça iris fotoğrafın
/// üzerine kapanır, kare kararır, kapandığı an kayıt gider. Erken bırakırsan
/// yayla geri açılır ve hiçbir şey olmaz.
///
/// Bunun iki faydası var. Birincisi, yıkıcı eylem yanlışlıkla yapılamayacak
/// kadar iradî hâle geliyor — bir dokunuş değil, bir buçuk saniyelik bir karar.
/// İkincisi, uygulamanın kendi diliyle konuşuyor: örtücü kapanır, kare biter.
///
/// Onaylanırsa `true`, aksi hâlde `null` döner.
Future<bool?> showShutterConfirm(
  BuildContext context, {
  required File photo,
  required String title,
  String? caption,
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: 'Kapat',
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) =>
          _ShutterConfirm(photo: photo, title: title, caption: caption),
      transitionsBuilder: (context, animation, _, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.08, end: 1).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
}

class _ShutterConfirm extends StatefulWidget {
  const _ShutterConfirm({
    required this.photo,
    required this.title,
    this.caption,
  });

  final File photo;
  final String title;
  final String? caption;

  @override
  State<_ShutterConfirm> createState() => _ShutterConfirmState();
}

class _ShutterConfirmState extends State<_ShutterConfirm>
    with SingleTickerProviderStateMixin {
  /// Kararın uzunluğu. Kazayla tetiklenemeyecek kadar uzun, sabır sınamayacak
  /// kadar kısa.
  static const _hold = Duration(milliseconds: 1150);

  late final AnimationController _close = AnimationController(
    vsync: this,
    duration: _hold,
    reverseDuration: const Duration(milliseconds: 420),
  )..addStatusListener(_onStatus);

  /// Kapanma ilerledikçe belirli eşiklerde tek tek tıklar; parmağın altında
  /// mekanik bir kadran dönüyormuş hissi verir.
  int _lastTick = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _close.addListener(_tick);
  }

  @override
  void dispose() {
    _close.dispose();
    super.dispose();
  }

  void _tick() {
    final step = (_close.value * 8).floor();
    if (step != _lastTick) {
      _lastTick = step;
      if (_close.status == AnimationStatus.forward) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _done) return;
    _done = true;
    HapticFeedback.heavyImpact();
    // Kapanışın son karesi görünsün diye kısa bir nefes.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan bulanıklaşır ama kaybolmaz: nereden geldiğini görürsün.
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: ColoredBox(
                color: OnPhoto.canvasDeep.withValues(alpha: 0.72),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: OnPhotoText.title,
                  ),
                  if (widget.caption != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.caption!,
                      textAlign: TextAlign.center,
                      style: OnPhotoText.label,
                    ),
                  ],
                  const SizedBox(height: 44),

                  _HoldTarget(
                    controller: _close,
                    photo: widget.photo,
                    enabled: !_done,
                  ),

                  const SizedBox(height: 34),
                  _HoldLabel(controller: _close),
                  const Spacer(),

                  // Vazgeçmek her zaman bir dokunuş; silmek bir karar.
                  _QuietAction(
                    label: 'Vazgeç',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(height: safe.bottom > 0 ? 8 : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Basılı tutulan daire: içinde kare, üstünde kapanan iris.
class _HoldTarget extends StatelessWidget {
  const _HoldTarget({
    required this.controller,
    required this.photo,
    required this.enabled,
  });

  final AnimationController controller;
  final File photo;
  final bool enabled;

  static const _size = 236.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!enabled) return;
        HapticFeedback.selectionClick();
        controller.forward();
      },
      onTapUp: (_) => controller.reverse(),
      onTapCancel: () => controller.reverse(),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final eased = Curves.easeInOutCubic.transform(t);

          return SizedBox.square(
            dimension: _size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // İlerlemeyi çevreleyen ince yay.
                CustomPaint(
                  size: const Size.square(_size),
                  painter: _ProgressRingPainter(t),
                ),

                ClipOval(
                  child: SizedBox.square(
                    dimension: _size - 26,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Kare kapandıkça hem kararır hem hafifçe büyür:
                        // içeri çekiliyormuş gibi.
                        Transform.scale(
                          scale: 1 + 0.06 * eased,
                          child: Image.file(
                            photo,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, _, _) =>
                                const ColoredBox(color: OnPhoto.canvasDeep),
                          ),
                        ),
                        ColoredBox(
                          color: OnPhoto.canvasDeep.withValues(
                            alpha: 0.62 * eased,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // İris tam kapanana kadar iner.
                SizedBox.square(
                  dimension: _size - 26,
                  child: Aperture(
                    openness: 1 - eased,
                    twist: -(2 * math.pi / 7) * 0.85 * eased,
                    edgeTint: Color.lerp(
                      OnPhoto.ink,
                      OnPhoto.danger,
                      eased,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
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
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(OnPhoto.ember, OnPhoto.danger, progress)!,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

/// Basma süresince değişen tek satırlık yönerge.
class _HoldLabel extends StatelessWidget {
  const _HoldLabel({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final text = switch (t) {
          0 => 'Silmek için basılı tut',
          < 0.55 => 'Bırakma…',
          < 0.99 => 'Neredeyse',
          _ => 'Gitti',
        };

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            text,
            key: ValueKey(text),
            style: AppType.label.copyWith(
              color: Color.lerp(OnPhoto.inkSoft, OnPhoto.danger, t),
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: OnPhoto.inkSoft,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
      child: Text(label, style: OnPhotoText.label),
    );
  }
}
