import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../core/utils/app_format.dart';

/// Ayarların bölüm başlığı: küçük kapiteller ve peşinden giden ince çizgi.
///
/// Kutulanmış kartlar yerine yazı tipiyle ayrılan bölümler, ekranı bir
/// arayüzden çok basılı bir sayfaya benzetiyor.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 34, 4, 16),
          child: Row(
            children: [
              Text(context.l10n.upper(title), style: palette.overline),
              const SizedBox(width: 12),
              Expanded(
                child: ColoredBox(
                  color: palette.hairline,
                  child: const SizedBox(height: 0.5, width: double.infinity),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  palette.canvasLift,
                  Colors.white,
                  palette.isDark ? 0.045 : 0.28,
                )!,
                palette.canvasLift,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.hairlineBright, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isDark ? 0.16 : 0.06,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Bir ayarın adı, açıklaması ve sağdaki denetimi.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.below,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  /// Satırın altına açılan denetim (ör. süre seçici).
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: palette.bodyStrong),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      // Açıklamalar okunacak kadar belirgin olmalı; en soluk
                      // ton yalnızca imza ve yer tutucular için.
                      Text(
                        description!,
                        style: palette.caption.copyWith(
                          color: palette.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ],
          ),
          ?below,
        ],
      ),
    );
  }
}

/// Kaydırmalı anahtar.
///
/// Material'ın anahtarı bu dile fazla yuvarlak ve renkli geliyor; burada raya
/// oturan sade bir kapsül var ve açıkken kor rengine dönüyor.
class InkSwitch extends StatelessWidget {
  const InkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  static const _width = 50.0;
  static const _height = 30.0;
  static const _knob = 24.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: Curves.easeOutQuart,
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: value ? palette.ember : palette.canvasSunk,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? Colors.transparent : palette.hairlineBright,
              width: 0.5,
            ),
          ),
          child: AnimatedAlign(
            duration: AppMotion.medium,
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  color: value ? Colors.white : palette.canvasLift,
                  shape: BoxShape.circle,
                  border: value
                      ? null
                      : Border.all(color: palette.hairlineBright, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: palette.isDark ? 0.22 : 0.10,
                      ),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayarlar içindeki genel amaçlı seçim rayı.
///
/// "Otomatik Sil" kontrolüyle aynı fizik: cam bir ray, üzerinde yay gibi kayan
/// dolu bir pil. Uygulamada iki farklı segment kontrolü olmasın diye biçim
/// birebir aynı tutuldu.
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
                                child: Text(labelOf(option)),
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
