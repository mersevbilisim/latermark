import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/retention.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../l10n/enum_labels.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../shared/widgets/pro_badge.dart';
import 'custom_retention_sheet.dart';

/// "Otomatik Sil" seçimi: cam bir ray üzerinde yay gibi kayan kemik beyazı pil.
class RetentionSelector extends StatelessWidget {
  const RetentionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.showTitle = true,
    this.isPro = true,
    this.onLockedTap,
  });

  final RetentionChoice value;
  final ValueChanged<RetentionChoice> onChanged;

  /// Ücretsiz katmanda "Özel" segmenti kilitli görünür.
  final bool isPro;

  /// Kilitli segmente dokunulduğunda çağrılır (paywall).
  final VoidCallback? onLockedTap;

  /// Boşsa yürürlükteki dildeki varsayılan başlık kullanılır.
  final String? title;

  /// Başlığı tamamen gizlemek için `false`.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    const options = Retention.values;
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.upper(
                    title ?? context.l10n.retentionSelectorTitle,
                  ),
                  style: palette.overline,
                ),
              ),
              const SizedBox(width: 8),
              // Süreli bir seçim yapıldığında kor rengi bir işaret belirir.
              AnimatedOpacity(
                opacity: value.isTimed ? 1 : 0,
                duration: AppMotion.medium,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.ember,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final labels = [
              for (final option in options) _labelFor(context, option),
            ];
            final labelStyle = palette.label.copyWith(
              fontWeight: FontWeight.w600,
            );
            final textScaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);
            final oneRowSegment = constraints.maxWidth / options.length;
            final oneRow = labels.every(
              (label) =>
                  _textWidth(label, labelStyle, textScaler, direction) <=
                  oneRowSegment - 8,
            );
            final columns = oneRow ? options.length : 2;
            final rows = (options.length / columns).ceil();
            final segmentWidth = constraints.maxWidth / columns;
            final labelWidth = math.max(1.0, segmentWidth - 12);
            final requiredCellHeight = [
              for (
                var optionIndex = 0;
                optionIndex < options.length;
                optionIndex++
              )
                _textHeight(
                      labels[optionIndex],
                      labelStyle,
                      textScaler,
                      direction,
                      labelWidth,
                    ) +
                    (options[optionIndex].isCustom && !isPro ? 18 : 0) +
                    16,
            ].reduce(math.max);
            final cellHeight = math.max(46.0, requiredCellHeight);
            final index = options.indexOf(value.retention);

            return SizedBox(
              height: cellHeight * rows,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.canvasSunk,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.hairlineBright, width: 0.5),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: AppMotion.travel(context, AppMotion.medium),
                      curve: Curves.easeOutQuart,
                      left: segmentWidth * (index % columns),
                      top: cellHeight * (index ~/ columns),
                      width: segmentWidth,
                      height: cellHeight,
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
                    Column(
                      children: [
                        for (var row = 0; row < rows; row++)
                          SizedBox(
                            height: cellHeight,
                            child: Row(
                              // Esneme olmadan hücreler yazının boyuna
                              // iniyordu: 46 pt'lik kutunun ortasında 13 pt'lik
                              // bir şerit dışında hiçbir yer dokunulabilir
                              // değildi. Ölçüldü.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var column = 0; column < columns; column++)
                                  Expanded(
                                    child: _Segment(
                                      label: labels[row * columns + column],
                                      selected:
                                          options[row * columns + column] ==
                                          value.retention,
                                      locked:
                                          options[row * columns + column]
                                              .isCustom &&
                                          !isPro,
                                      singleLine: oneRow,
                                      onTap: () => _select(
                                        context,
                                        options[row * columns + column],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Seçili özel sürede segment sayıyı gösterir: "Özel" yerine "6 saat".
  String _labelFor(BuildContext context, Retention option) =>
      option.isCustom && option == value.retention && value.customMinutes > 0
      ? value.label(context.l10n)
      : option.label(context.l10n);

  double _textWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _textHeight(
    String text,
    TextStyle style,
    TextScaler textScaler,
    TextDirection direction,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: direction,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Future<void> _select(BuildContext context, Retention option) async {
    if (option.isCustom && !isPro) {
      onLockedTap?.call();
      return;
    }

    HapticFeedback.selectionClick();

    // "Özel", seçilmekle bitmiyor: süreyi sormak gerekiyor. Zaten özeldeyken
    // tekrar dokunmak da süreyi *değiştirmek* demek — bu yüzden aynı segmente
    // dokunma burada yok sayılmıyor.
    if (option.isCustom) {
      final minutes = await showCustomRetentionSheet(
        context,
        initialMinutes: value.customMinutes,
      );
      if (minutes != null) onChanged(RetentionChoice.custom(minutes));
      return;
    }

    if (option == value.retention) return;
    onChanged(RetentionChoice(option));
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.locked,
    required this.singleLine,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final bool singleLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, ${context.l10n.proBadge}' : label,
      // Eylem düğümün **kendisinde** duruyor: `excludeSemantics` altındaki
      // GestureDetector'ın dokunma eylemini de siliyor ve geriye ekran
      // okuyucunun okuyabildiği ama çalıştıramadığı bir düğme kalıyor.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: singleLine ? 4 : 6),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.medium,
              curve: AppMotion.ease,
              style: context.palette.label.copyWith(
                color: locked
                    ? context.palette.inkSoft
                    : (selected
                          ? context.palette.ink
                          : context.palette.inkSoft),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: locked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: singleLine ? 1 : null,
                          softWrap: !singleLine,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        const ProGateMark(),
                      ],
                    )
                  : Text(
                      label,
                      maxLines: singleLine ? 1 : null,
                      softWrap: !singleLine,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
