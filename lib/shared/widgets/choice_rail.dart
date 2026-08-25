import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_palette.dart';

/// Uygulamanın genel amaçlı seçim rayı.
///
/// "Otomatik Sil" kontrolüyle aynı fizik: cam bir ray, üzerinde yay gibi kayan
/// dolu bir pil. Uygulamada iki farklı segment kontrolü olmasın diye biçim
/// birebir aynı tutuldu; ayarlar da hatırlatma planı da bu tek raydan sorar.
class ChoiceRail<T> extends StatelessWidget {
  const ChoiceRail({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.enabled = true,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final index = options.indexOf(value);

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: AppMotion.medium,
      child: IgnorePointer(
        ignoring: !enabled,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segment = constraints.maxWidth / options.length;
            final baseStyle = palette.label.copyWith(
              fontWeight: FontWeight.w600,
            );
            final textScaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);
            var tallestLabel = 0.0;
            for (final option in options) {
              final painter = TextPainter(
                text: TextSpan(text: labelOf(option), style: baseStyle),
                textScaler: textScaler,
                textDirection: direction,
                textAlign: TextAlign.center,
                maxLines: 3,
                ellipsis: '…',
              )..layout(maxWidth: math.max(1.0, segment - 12));
              tallestLabel = math.max(tallestLabel, painter.height);
            }
            final railHeight = math.max(46.0, tallestLabel + 16);

            return Container(
              height: railHeight,
              decoration: BoxDecoration(
                color: palette.canvasSunk,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.hairlineBright, width: 0.5),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: AppMotion.medium,
                    curve: Curves.easeOutQuart,
                    left: segment * (index < 0 ? 0 : index),
                    top: 0,
                    bottom: 0,
                    width: segment,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(
                                palette.canvasLift,
                                Colors.white,
                                palette.isDark ? 0.08 : 0.35,
                              )!,
                              palette.canvasLift,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: palette.ember.withValues(alpha: 0.28),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: palette.isDark ? 0.24 : 0.08,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final option in options)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (option == value) return;
                              HapticFeedback.selectionClick();
                              onChanged(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: AppMotion.medium,
                                  curve: AppMotion.ease,
                                  style: palette.label.copyWith(
                                    color: option == value
                                        ? palette.ink
                                        : palette.inkSoft,
                                    fontWeight: option == value
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  child: Text(
                                    labelOf(option),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
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
            );
          },
        ),
      ),
    );
  }
}
