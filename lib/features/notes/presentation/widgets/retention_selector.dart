import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/tr_format.dart';
import '../../domain/retention.dart';

/// "Otomatik Sil" seçimi: cam bir ray üzerinde yay gibi kayan kemik beyazı pil.
class RetentionSelector extends StatelessWidget {
  const RetentionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Otomatik Sil',
  });

  final Retention value;
  final ValueChanged<Retention> onChanged;
  final String? title;

  @override
  Widget build(BuildContext context) {
    const options = Retention.values;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Text(TrFormat.upper(title!), style: palette.overline),
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
            final index = options.indexOf(value);

            return Container(
              height: 46,
              decoration: BoxDecoration(
                color: palette.glass,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: palette.hairline, width: 0.5),
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
                          color: palette.ink,
                          borderRadius: BorderRadius.circular(11),
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
                            selected: option == value,
                            onTap: () {
                              if (option == value) return;
                              HapticFeedback.selectionClick();
                              onChanged(option);
                            },
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
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final Retention option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.medium,
            curve: AppMotion.ease,
            style: context.palette.label.copyWith(
              color: selected
                  ? context.palette.canvas
                  : context.palette.inkSoft,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(option.label),
          ),
        ),
      ),
    );
  }
}
