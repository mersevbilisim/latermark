import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/retention.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../l10n/enum_labels.dart';
import '../../../../core/utils/app_format.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              Text(
                context.l10n.upper(
                  title ?? context.l10n.retentionSelectorTitle,
                ),
                style: palette.overline,
              ),
              const Spacer(),
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
            final segmentWidth = constraints.maxWidth / options.length;
            final index = options.indexOf(value.retention);

            return Container(
              height: 46,
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
                    left: segmentWidth * index,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
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
                          child: _Segment(
                            option: option,
                            choice: value,
                            selected: option == value.retention,
                            locked: option.isCustom && !isPro,
                            onTap: () => _select(context, option),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
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
    required this.option,
    required this.choice,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final Retention option;
  final RetentionChoice choice;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  /// Seçili özel sürede segment sayıyı gösterir: "Özel" yerine "6 saat".
  /// Kullanıcı ne seçtiğini kontrole bakarak görmeli.
  String _label(BuildContext context) =>
      option.isCustom && selected && choice.customMinutes > 0
      ? choice.label(context.l10n)
      : option.label(context.l10n);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: _label(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            curve: AppMotion.ease,
            style: context.palette.label.copyWith(
              color: locked
                  ? context.palette.inkFaint
                  : (selected ? context.palette.ink : context.palette.inkSoft),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(
              _label(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
