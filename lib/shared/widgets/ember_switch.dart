import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_shape.dart';

/// Latermark'ın kendi anahtarı.
///
/// Sistem anahtarı bu ekrana iki yabancı şey getiriyordu: kendi vurgu rengi ve
/// tam daire bir kapsül. Uygulamanın yüzeyleri süperelips, vurgusu tek bir kor
/// rengi; anahtarın da aynı malzemeden olması gerekiyor.
///
/// Durum değişimi yalnız renk değil, **fizik**: kapalıyken düğme oyuğun içinde
/// duran kabarık bir blok, açıkken kor dolu rayda açılmış bir delik ve
/// ortasında kaydın canlı olduğunu söyleyen nokta — künyedeki, kartın
/// üzerindeki aynı kor nokta. Boşalan yerde kalan kısa çizgi de künyenin
/// noktalama işareti.
class EmberSwitch extends StatelessWidget {
  const EmberSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const _width = 52.0;
  static const _height = 30.0;
  static const _knob = 24.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: Curves.easeOutQuart,
            width: _width,
            height: _height,
            decoration: ShapeDecoration(
              color: value ? palette.ember : palette.canvasSunk,
              shape: RoundedSuperellipseBorder(
                borderRadius: AppShape.all(9),
                side: BorderSide(
                  color: value ? Colors.transparent : palette.hairlineBright,
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              children: [
                // Boşalan yandaki künye çizgisi. Yalnız açıkken var: kapalı
                // rayda ikinci bir işaret, anahtarı okunur kılmak yerine
                // kalabalık yapardı.
                Positioned.fill(
                  child: Align(
                    alignment: value
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: value ? 1 : 0,
                        child: SizedBox(
                          width: 10,
                          height: 1,
                          child: ColoredBox(
                            color: palette.canvas.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: AppMotion.medium,
                  curve: Curves.easeOutQuart,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: AppMotion.medium,
                      curve: Curves.easeOutQuart,
                      width: _knob,
                      height: _knob,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: value ? palette.canvas : palette.canvasLift,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: AppShape.all(7),
                          side: BorderSide(
                            color: value
                                ? Colors.transparent
                                : palette.hairlineBright,
                            width: 0.5,
                          ),
                        ),
                        shadows: value
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: palette.isDark ? 0.24 : 0.10,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: value ? 1 : 0,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.ember,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
