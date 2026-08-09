import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/aperture.dart';

enum ComposeSavePhase { idle, saving, sealed }

/// Compose'a özgü kayıt eylemi (Apple Design Awards Standartlarında).
///
/// Havada süzülen, altındaki görüntüyü flulaştıran (glassmorphism) oval bir kapsül.
/// Dokunulduğunda tüm kapsül organik bir şekilde esnerken, sağ taraftaki deklanşör
/// haznesi fiziksel bir tekerlek gibi tepki verir. Kayıt sırasında kapsülün
/// altından süzülen bir LED ışığı ilerlemeyi gösterir.
class ComposeSaveAction extends StatefulWidget {
  const ComposeSaveAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.phase = ComposeSavePhase.idle,
  });

  final String label;
  final VoidCallback? onPressed;
  final ComposeSavePhase phase;

  @override
  State<ComposeSaveAction> createState() => _ComposeSaveActionState();
}

class _ComposeSaveActionState extends State<ComposeSaveAction>
    with TickerProviderStateMixin {
  static const _bladePitch = 2 * math.pi / 7;

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    reverseDuration: AppMotion.fast,
  );
  late final AnimationController _commit = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    reverseDuration: AppMotion.medium,
    value: widget.phase == ComposeSavePhase.idle ? 0 : 1,
  );
  late final AnimationController _ratchet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  );

  Timer? _ratchetDelay;
  bool _reduceMotion = false;

  bool get _enabled =>
      widget.onPressed != null && widget.phase == ComposeSavePhase.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) {
      if (widget.phase == ComposeSavePhase.saving && !_ratchet.isAnimating) {
        _scheduleRatchet();
      }
      return;
    }
    _reduceMotion = reduce;
    _syncPhase();
  }

  @override
  void didUpdateWidget(ComposeSaveAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncPhase();
  }

  void _syncPhase() {
    _ratchetDelay?.cancel();
    _ratchet.stop();
    _press.value = 0;

    if (_reduceMotion) {
      _commit.value = widget.phase == ComposeSavePhase.idle ? 0 : 1;
      _ratchet.value = widget.phase == ComposeSavePhase.idle ? 0 : 1;
      return;
    }

    switch (widget.phase) {
      case ComposeSavePhase.idle:
        _ratchet.value = 0;
        _commit.reverse();
        return;
      case ComposeSavePhase.saving:
        _commit.forward();
        _scheduleRatchet();
        return;
      case ComposeSavePhase.sealed:
        _ratchet.value = 1;
        _commit.forward();
        return;
    }
  }

  void _scheduleRatchet() {
    _ratchetDelay?.cancel();
    if (_reduceMotion || widget.phase != ComposeSavePhase.saving) return;
    _ratchetDelay = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || widget.phase != ComposeSavePhase.saving) return;
      _ratchet.repeat();
    });
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    if (_reduceMotion) {
      _press.value = 1;
    } else {
      _press.forward();
    }
  }

  void _release() {
    if (_reduceMotion) {
      _press.value = 0;
    } else {
      _press.reverse();
    }
  }

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.lightImpact(); // Daha premium, hassas bir dokunma hissi
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    _ratchetDelay?.cancel();
    _press.dispose();
    _commit.dispose();
    _ratchet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      onTap: _enabled ? _activate : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? _handleTapDown : null,
          onTapUp: _enabled ? (_) => _release() : null,
          onTapCancel: _enabled ? _release : null,
          onTap: _enabled ? _activate : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_press, _commit, _ratchet]),
            builder: (context, _) {
              final pressed = AppMotion.ease.transform(_press.value);
              final committed = AppMotion.ease.transform(_commit.value);
              final closure = math.max(committed, pressed * 0.78);
              final railProgress = math.max(committed, pressed * 0.14);

              // Butonu pasif bir etiket olmaktan çıkarıp, yüksek kontrastlı ana eylem
              // rengine (ink) boyuyoruz. Üstündeki yazılar ise arka plan rengini (canvas) alıyor.
              final buttonBg = palette.ink;
              final textColor = palette.canvas;
              // Deklanşör yuvası, ana buton renginin içinde çok hafif oyulmuş bir alan hissi verecek
              final chamberBg = palette.canvas.withValues(alpha: 0.12);

              final openness = 0.60 + (0.045 - 0.60) * closure;
              final twist =
                  -_bladePitch * 0.38 * closure + _bladePitch * _ratchet.value;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Transform.scale(
                  scale:
                      1.0 -
                      (pressed *
                          0.03), // Basıldığında buton tok bir şekilde aşağı çöker
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: buttonBg,
                      borderRadius: BorderRadius.circular(
                        25,
                      ), // Klasik ve net buton formu
                      // Gölge yok, sahte üst kenar ışığı da yok.
                      //
                      // Düğmenin kendi renginde bir parıltı (0.35 alfa, 16
                      // bulanıklık) ve 1 piksellik beyaz bir çerçeve, düğmeyi
                      // zeminden "koparmak" yerine ucuzlatıyordu: ikisi de
                      // ışığı taklit eden, kaynağı olmayan efektler. Uygulamanın
                      // geri kalanında hiçbir yüzey gölge taşımıyor — baskılar
                      // saç teli kenarla, paneller ton farkıyla ayrılıyor.
                      // Düğmenin dolgusu zaten zeminden yeterince ayrı.
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // İlerleme Çubuğu (Butonun alt sınırında dolan Ember rengi ince hat)
                        if (railProgress > 0)
                          Positioned(
                            left: 0,
                            bottom: 0,
                            width:
                                (MediaQuery.of(context).size.width - 44) *
                                railProgress,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.ember,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(32),
                                ),
                              ),
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Sol taraf: Net, okunaklı, kontrastlı eylem metni
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                widget.label,
                                style: palette.bodyStrong.copyWith(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),

                            // Sağ taraf: İçeri gömülü fiziksel deklanşör (Aperture) yuvası
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: chamberBg,
                                ),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: pressed * math.pi / 16,
                                    child: Transform.scale(
                                      scale: 1 - pressed * 0.05,
                                      child: SizedBox.square(
                                        dimension: 28,
                                        child: Aperture(
                                          openness: openness,
                                          twist: twist,
                                          edgeTint: palette.ember,
                                          bladeBase: buttonBg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
