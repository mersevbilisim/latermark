import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/icon_orb.dart';
import 'widgets/settings_pieces.dart';

/// Latermark'a özel, cihaz ayarlarını yalnızca güçlendirebilen erişilebilirlik
/// tercihleri.
///
/// Bu sayfa not, satın alma veya hak verisine dokunmaz. Cihazın erişilebilirlik
/// sinyalleri uygulama kökünde bu iki tercihle OR'lanır; dolayısıyla kullanıcı
/// buradaki anahtarı kapatarak sistemde açık bir özelliği geri kapatamaz.
class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final settings = AppScope.preferences(context);
    final repository = AppScope.settingsOf(context);
    final horizontalInset = media.size.width <= 320 ? 16.0 : 22.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(palette.brightness),
      child: Scaffold(
        key: const Key('accessibility-page'),
        backgroundColor: palette.canvas,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: palette.canvas,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14),
            child: Center(
              child: IconOrb(
                icon: Icons.arrow_back_rounded,
                semanticLabel: l10n.actionBack,
                onPressed: () => Navigator.of(context).maybePop(),
                size: 38,
                iconSize: 18,
                tint: palette.ink,
                fill: palette.canvasLift,
              ),
            ),
          ),
          titleSpacing: 6,
          title: Semantics(
            header: true,
            namesRoute: true,
            child: Text(
              l10n.accessibilityTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: palette.title.copyWith(fontSize: 20),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: ColoredBox(
              color: palette.hairline,
              child: const SizedBox(height: 0.5, width: double.infinity),
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.92),
              radius: 1.1,
              colors: [
                Color.lerp(
                  palette.canvas,
                  palette.ember,
                  palette.isDark ? 0.04 : 0.025,
                )!,
                palette.canvas,
              ],
              stops: const [0, 0.82],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalInset + media.padding.left,
              30,
              horizontalInset + media.padding.right,
              media.padding.bottom + 38,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.accessibilityIntro,
                      style: palette.bodyStrong.copyWith(
                        color: palette.inkSoft,
                        height: 1.45,
                      ),
                    ),
                    SettingsSection(
                      title: l10n.appTitle,
                      children: [
                        SettingsRow(
                          title: l10n.accessibilityContrastTitle,
                          description: l10n.accessibilityContrastDescription,
                          trailing: InkSwitch(
                            key: const Key('accessibility-high-contrast'),
                            value: settings.alwaysHighContrast,
                            semanticLabel: l10n.accessibilityContrastTitle,
                            onChanged: repository.setAlwaysHighContrast,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SettingsRow(
                          title: l10n.accessibilityMotionTitle,
                          description: l10n.accessibilityMotionDescription,
                          trailing: InkSwitch(
                            key: const Key('accessibility-reduce-motion'),
                            value: settings.alwaysReduceMotion,
                            semanticLabel: l10n.accessibilityMotionTitle,
                            onChanged: repository.setAlwaysReduceMotion,
                          ),
                        ),
                      ],
                    ),
                    // Yazı boyunun kendi anahtarı **yok** ve olmamalı: ölçü
                    // kişinin gözüne ait, uygulamaya değil. iOS'ta bir kez
                    // ayarlanıyor, bütün uygulamalar uyuyor; buraya ikinci bir
                    // kaydırıcı koymak aynı kararı iki yerde verdirir ve ikisi
                    // çeliştiğinde hangisinin kazandığını kimse bilemez.
                    //
                    // Ama "yazı boyu nerede?" diye bakan biri bu sayfaya
                    // geliyor. Bölüm başlığı onu karşılıyor ve yolu söylüyor —
                    // yalnız Latermark'ta büyütmenin yolu dahil.
                    SettingsSection(
                      title: l10n.accessibilityTextSizeTitle,
                      children: [
                        Text(
                          l10n.accessibilityTextSizeBody,
                          style: palette.caption.copyWith(
                            color: palette.inkSoft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Semantics(
                      readOnly: true,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.canvasLift,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.hairlineBright,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.phone_iphone_rounded,
                              color: palette.ember,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.accessibilitySystemNote,
                                style: palette.caption.copyWith(
                                  color: palette.inkSoft,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
