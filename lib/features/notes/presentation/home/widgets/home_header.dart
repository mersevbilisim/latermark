import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/icon_orb.dart';

/// Kaydırıldıkça büyük başlıktan ince bir çubuğa dönüşen üstlük.
///
/// Yükseklik, yazı boyutu, sayaç ve arka bulanıklık aynı `t` değeriyle
/// sürülür; böylece hepsi tek bir jestle birlikte hareket eder.
///
/// **Arama ayrı bir kutu değil, başlığın kendisi.** Büyütece dokununca
/// "Notlar" yazısı aynı yerde, aynı puntoda bir girdiye dönüşüyor; sayaç
/// satırı da sonuç sayısına. Ekrana kalıcı bir arama çubuğu çakmak, hem
/// uygulamanın sade düzenini bozardı hem de nadiren kullanılan bir denetime
/// sürekli yer ayırmak olurdu.
class HomeHeader extends SliverPersistentHeaderDelegate {
  const HomeHeader({
    required this.palette,
    required this.topPadding,
    required this.noteCount,
    required this.onOpenSettings,
    required this.searching,
    required this.resultCount,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onToggleSearch,
  });

  final AppPalette palette;
  final double topPadding;
  final int noteCount;
  final VoidCallback onOpenSettings;

  /// Arama kipi. Denetimin durumu (metin, odak) üstlükte tutulamaz: bu bir
  /// [SliverPersistentHeaderDelegate] ve kaydırmanın her karesinde yeniden
  /// kuruluyor. Bu yüzden ana ekranda yaşıyor, buraya veriliyor.
  final bool searching;
  final int resultCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;

  static const _expandedHeight = 116.0;
  static const _collapsedHeight = 56.0;

  @override
  double get maxExtent => topPadding + _expandedHeight;

  @override
  double get minExtent => topPadding + _collapsedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);

    final header = Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Stack(
        children: [
          Positioned(
            left: 22,
            right: 22,
            bottom: lerpDouble(20, 15, eased)!,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sayaç, başlık küçüldükçe onun altından kayıp gider.
                      ClipRect(
                        child: Align(
                          heightFactor: (1 - eased * 1.4).clamp(0.0, 1.0),
                          alignment: Alignment.bottomLeft,
                          child: Opacity(
                            opacity: (1 - eased * 2).clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                context.l10n.upper(
                                  searching
                                      ? context.l10n.searchResults(resultCount)
                                      : context.l10n.noteCount(noteCount),
                                ),
                                // Aramada sayaç kor rengine döner: kullanıcı
                                // filtrelenmiş bir listeye baktığını, sayının
                                // toplam kayıt olmadığını görmeli.
                                style: palette.overline.copyWith(
                                  color: searching
                                      ? palette.ember
                                      : palette.inkFaint,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Başlık ve arama girdisi aynı tipografiyi paylaşıyor:
                      // geçiş bir ekran değişimi değil, bir hâl değişimi gibi
                      // okunuyor.
                      _TitleOrField(
                        searching: searching,
                        palette: palette,
                        controller: searchController,
                        focus: searchFocus,
                        onChanged: onSearchChanged,
                        fontSize: lerpDouble(34, 19, eased)!,
                        letterSpacing: lerpDouble(-0.9, -0.3, eased)!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (searching)
                  IconOrb(
                    icon: Icons.close_rounded,
                    semanticLabel: context.l10n.searchCancel,
                    onPressed: onToggleSearch,
                    size: 38,
                    iconSize: 18,
                    tint: palette.ink,
                    fill: palette.glass,
                  )
                else ...[
                  IconOrb(
                    icon: Icons.search_rounded,
                    semanticLabel: context.l10n.searchHint,
                    onPressed: onToggleSearch,
                    size: 38,
                    iconSize: 18,
                    tint: palette.ink,
                    fill: palette.glass,
                  ),
                  const SizedBox(width: 8),
                  IconOrb(
                    icon: Icons.tune_rounded,
                    semanticLabel: context.l10n.settingsAction,
                    onPressed: onOpenSettings,
                    size: 38,
                    iconSize: 18,
                    tint: palette.ink,
                    fill: palette.glass,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: eased,
              child: ColoredBox(
                color: palette.hairline,
                child: const SizedBox(height: 0.5, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );

    // Kaydırma sırasında sigma değiştiren BackdropFilter her karede yeni
    // bir ara katman oluşturuyordu. Tuvalin hafif saydamlaşması aynı ayrımı
    // GPU blur geçişi olmadan verir.
    return ColoredBox(
      color: palette.canvas.withValues(alpha: lerpDouble(1, 0.94, eased)!),
      child: header,
    );
  }

  @override
  bool shouldRebuild(HomeHeader old) =>
      old.topPadding != topPadding ||
      old.noteCount != noteCount ||
      old.palette != palette ||
      old.searching != searching ||
      old.resultCount != resultCount;
}

/// Başlık ile arama girdisi arasındaki geçiş.
class _TitleOrField extends StatelessWidget {
  const _TitleOrField({
    required this.searching,
    required this.palette,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.fontSize,
    required this.letterSpacing,
  });

  final bool searching;
  final AppPalette palette;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final style = palette.display.copyWith(
      fontSize: fontSize,
      letterSpacing: letterSpacing,
    );

    if (!searching) {
      return Text(context.l10n.notesTitle, style: style);
    }

    return TextField(
      controller: controller,
      focusNode: focus,
      onChanged: onChanged,
      autofocus: true,
      style: style,
      cursorColor: palette.ember,
      cursorWidth: 2,
      textInputAction: TextInputAction.search,
      keyboardAppearance: palette.isDark ? Brightness.dark : Brightness.light,
      decoration: InputDecoration.collapsed(
        hintText: context.l10n.searchHint,
        hintStyle: style.copyWith(color: palette.inkGhost),
      ),
    );
  }
}

/// Akışın editoryal zaman ayıracı.
///
/// Bir kart ya da kapsül çizmez. Bölüm adı ile ince kılavuz çizgisi aynı yatay
/// omurga üzerinde çalışır; böylece uzun bir arşiv rahatça taranabilir ve
/// fotoğraflarla yarışmaz.
class AgeSeparator extends StatelessWidget {
  const AgeSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final showRule = constraints.maxWidth >= 330 && textScale <= 1.3;

        return Semantics(
          container: true,
          header: true,
          label: label,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 32, 22, 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: palette.overline.copyWith(color: palette.inkSoft),
                    ),
                  ),
                  if (showRule) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ColoredBox(
                        color: palette.hairline,
                        child: const SizedBox(height: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
