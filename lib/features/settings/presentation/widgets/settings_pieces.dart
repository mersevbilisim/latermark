import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/accent_tone.dart';
import '../../../../core/theme/app_accent.dart';
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
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    // Çizgi çok dar ekranda da görünür kalsın; başlık kalan
                    // alanda gerektiği kadar satıra açılır.
                    maxWidth: math.max(0.0, constraints.maxWidth - 36),
                  ),
                  child: Text(
                    context.l10n.upper(title),
                    style: palette.overline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: ColoredBox(
                      color: palette.hairline,
                      child: const SizedBox(height: 0.5),
                    ),
                  ),
                ),
              ],
            ),
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
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: palette.bodyStrong),
        if (description != null) ...[
          const SizedBox(height: 4),
          // Açıklamalar okunacak kadar belirgin olmalı; en soluk ton yalnızca
          // imza ve yer tutucular için.
          Text(
            description!,
            style: palette.caption.copyWith(
              color: palette.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final control = trailing;
              if (control == null) return copy;

              // Dar kartlarda metni ezmek yerine denetim ikinci satıra iner.
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: control,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      // Uzun bir dil adı açıklamayı görünmez hâle getirmesin.
                      maxWidth: constraints.maxWidth * 0.48,
                    ),
                    child: control,
                  ),
                ],
              );
            },
          ),
          ?below,
        ],
      ),
    );
  }
}

/// Küratörlü renklerin küçük bir prova şeridi.
///
/// Renk adlarını altı dar segmente sıkıştırmak yerine yalnız seçili ad üst
/// satırda okunur; burada her seçenek 44pt dokunma ve erişilebilirlik alanı
/// taşır. İnce çizgi, swatch'ları ayrı kartlara dönüştürmeden tek bir kontrol
/// gibi bağlar.
class AccentRail extends StatelessWidget {
  const AccentRail({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    required this.customHue,
    required this.onCustom,
  });

  final AppAccent value;
  final ValueChanged<AppAccent> onChanged;
  final String Function(AppAccent) labelOf;

  /// Kullanıcının özel tonu; yuvanın örneği bunu gösteriyor.
  final int customHue;

  /// Özel yuvaya dokunulduğunda. Seçim burada değil panelde tamamlanıyor:
  /// tonu görmeden "özel"e geçmek anlamsız bir ara durum olurdu.
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            start: 22,
            end: 22,
            child: ColoredBox(
              color: palette.hairlineBright,
              child: const SizedBox(height: 0.5),
            ),
          ),
          Row(
            children: [
              for (final accent in AppAccent.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: accent == value,
                    label: labelOf(accent),
                    child: GestureDetector(
                      key: ValueKey('app-accent-${accent.name}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // Özel yuva seçiliyken de dokunulabilir: kullanıcı
                        // tonunu değiştirmek için paneli yeniden açabilmeli.
                        if (accent == AppAccent.custom) {
                          onCustom();
                          return;
                        }
                        if (accent == value) return;
                        onChanged(accent);
                      },
                      child: Center(
                        child: accent == AppAccent.custom
                            ? _AccentSwatch(
                                color: accent.colorFor(
                                  palette.brightness,
                                  customHue: customHue,
                                ),
                                selected: accent == value,
                                canvas: palette.canvasLift,
                                ink: palette.ink,
                                // Henüz seçilmemişken yuva tek bir renk
                                // göstermiyor: seçilecek olan **ton
                                // çemberinin kendisi**. Şeritteki diğer
                                // altısıyla aynı dilde, ama ne yaptığı
                                // etiketsiz anlaşılıyor.
                                wheel: accent != value,
                              )
                            : _AccentSwatch(
                                color: accent.colorFor(palette.brightness),
                                selected: accent == value,
                                canvas: palette.canvasLift,
                                ink: palette.ink,
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
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.canvas,
    required this.ink,
    this.wheel = false,
  });

  final Color color;
  final bool selected;
  final Color canvas;
  final Color ink;

  /// Tek renk yerine ton çemberi çiz. Yalnızca henüz seçilmemiş özel yuva.
  final bool wheel;

  @override
  Widget build(BuildContext context) {
    final check = color.computeLuminance() > 0.47
        ? const Color(0xD9000000)
        : const Color(0xF2FFFFFF);

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: Curves.easeOutQuart,
      width: selected ? 34 : 28,
      height: selected ? 34 : 28,
      padding: EdgeInsets.all(selected ? 4 : 3),
      decoration: BoxDecoration(
        color: canvas,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ink.withValues(alpha: 0.42) : canvas,
          width: selected ? 1 : 0.5,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: wheel ? null : color,
          gradient: wheel
              ? SweepGradient(
                  colors: [
                    for (var h = 0; h <= 12; h++)
                      AccentTone.colorFor(
                        (h * 30) % AccentTone.hueCount,
                        Brightness.dark,
                      ),
                  ],
                )
              : null,
        ),
        child: selected
            ? Icon(Icons.check_rounded, color: check, size: 15)
            : null,
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
