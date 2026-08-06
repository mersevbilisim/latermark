import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';

/// Dokunulan noktada bir an belirip sönen odak halkası.
///
/// Her yeni dokunuşta yeniden başlaması için çağıran taraf benzersiz bir
/// [Key] verir; widget yeniden kurulur ve animasyon baştan çalışır.
class FocusReticle extends StatefulWidget {
  const FocusReticle({super.key});

  static const size = 74.0;

  @override
  State<FocusReticle> createState() => _FocusReticleState();
}

class _FocusReticleState extends State<FocusReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final Animation<double> _scale = Tween<double>(begin: 1.35, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.22, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: FocusReticle.size,
            height: FocusReticle.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: OnPhoto.ember, width: 1.2),
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: OnPhoto.ember,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
