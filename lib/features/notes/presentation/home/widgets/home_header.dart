import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/aperture.dart';
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
    this.selecting = false,
    this.selectedCount = 0,
  });

  final AppPalette palette;
  final double topPadding;
  final int noteCount;
  final VoidCallback onOpenSettings;

  /// Seçim kipi. Arama gibi bu da ayrı bir ekran değil, başlığın bir hâli:
  /// "Notlar" yerine ne yapıldığı yazar, sayaç satırı da kaç karenin
  /// işaretlendiğini söyler.
  ///
  /// Üstlük kip boyunca yalnız *anlatır*: kipi açan da kapatan da alt şeritteki
  /// denetim. Silme kipindeyken arama ve ayarlar da çekiliyor — o an yapılacak
  /// tek iş kare işaretlemek.
  final bool selecting;
  final int selectedCount;

  /// Arama kipi. Denetimin durumu (metin, odak) üstlükte tutulamaz: bu bir
  /// [SliverPersistentHeaderDelegate] ve kaydırmanın her karesinde yeniden
  /// kuruluyor. Bu yüzden ana ekranda yaşıyor, buraya veriliyor.
  final bool searching;
  final int resultCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;

  /// Sayaç satırının o anki hâli: seçim > arama > toplam.
  String _tally(BuildContext context) {
    final l10n = context.l10n;
    if (selecting) return l10n.selectionCount(selectedCount);
    if (searching) return l10n.searchResults(resultCount);
    return l10n.noteCount(noteCount);
  }

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
                                context.l10n.upper(_tally(context)),
                                // Arama ve seçimde sayaç kor rengine döner:
                                // kullanıcı bir alt kümeye baktığını, sayının
                                // toplam kayıt olmadığını görmeli.
                                style: palette.overline.copyWith(
                                  color: searching || selecting
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
                        selecting: selecting,
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
                else if (!selecting) ...[
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
      old.resultCount != resultCount ||
      old.selecting != selecting ||
      old.selectedCount != selectedCount;
}

/// Başlık ile arama girdisi arasındaki geçiş.
class _TitleOrField extends StatelessWidget {
  const _TitleOrField({
    required this.searching,
    required this.selecting,
    required this.palette,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.fontSize,
    required this.letterSpacing,
  });

  final bool searching;
  final bool selecting;
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
      return Text(
        selecting ? context.l10n.selectionTitle : context.l10n.notesTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
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
  const AgeSeparator({
    super.key,
    required this.label,
    this.collapsed = false,
    this.count,
    this.onToggle,
  });

  final String label;

  /// Bölüm kapalı mı. [onToggle] verilmediyse anlamsız.
  final bool collapsed;

  /// Kapalıyken saklanan kayıt sayısı.
  ///
  /// Yalnız kapalıyken okunuyor: açıkken kayıtlar zaten ekranda ve sayıyı
  /// ayrıca yazmak aynı şeyi iki kez söylemek olurdu. Kapalıyken ise bölüm
  /// bir kutu; içinde ne olduğunu söylemeyen bir kapak kapatılmaya değmez.
  final int? count;

  /// Bölümü açıp kapatır. `null` ise ayraç eskisi gibi hareketsiz.
  ///
  /// Seçim kipinde bilinçli olarak `null` geliyor: görünmeyen kayıtları
  /// silinecekler arasında tutmak, kullanıcının göremediği bir şeyi silmesi
  /// demek olurdu.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final interactive = onToggle != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final showRule = constraints.maxWidth >= 330 && textScale <= 1.3;

        // Etiket esnek bir çocuk olursa çizgiyle **boş alanı paylaşıyor** ve
        // çizgi sağa kadar uzanmıyor: iris ortaya doğru kayıyor. Bu yüzden
        // esneyen tek çocuk çizgi; etiketin taşmaması da genişliğini burada
        // sınırlayarak sağlanıyor.
        final labelWidth = (constraints.maxWidth - 44) * 0.42;

        final row = Padding(
          padding: const EdgeInsets.fromLTRB(22, 32, 22, 14),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelWidth),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: palette.overline.copyWith(
                    // Kapalı bölüm sönmüyor, tersine: saklanan şeyin izi
                    // kalmalı, yoksa arşivin bir parçası yok olmuş gibi durur.
                    color: collapsed ? palette.ink : palette.inkSoft,
                  ),
                ),
              ),
              if (showRule) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ColoredBox(
                    color: palette.hairline,
                    child: const SizedBox(height: 0.5),
                  ),
                ),
              ] else
                const Spacer(),
              if (interactive) ...[
                const SizedBox(width: 12),
                // Sayı çizginin ucunda, irisin hemen solunda: göz çizgiyi
                // takip edip kapağın üstünde duruyor.
                AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: collapsed ? 1 : 0,
                  child: Text(
                    count == null ? '' : '$count',
                    style: palette.overline.copyWith(
                      color: palette.inkFaint,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // İşaret artı değil, uygulamanın kendi irisi: bölüm
                // kapandığında o da kapanıyor. Aynı iris kalan ömrü, silme
                // onayını ve hatırlatma sözünü de anlatıyor.
                //
                // Bıçaklar tek bir `t` ile sürülüyor; açıklık, burulma ve
                // kenar rengi birlikte hareket ediyor, yani kapanma bir durum
                // değişimi değil bir **hareket** olarak okunuyor.
                SizedBox.square(
                  dimension: 15,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: collapsed ? 1 : 0),
                    duration: AppMotion.medium,
                    curve: AppMotion.ease,
                    builder: (context, t, _) => Aperture(
                      openness: lerpDouble(0.78, 0.16, t)!,
                      twist: lerpDouble(0, -0.38, t)!,
                      bladeCount: 7,
                      edgeTint: Color.lerp(palette.inkFaint, palette.ember, t),
                      bladeBase: palette.canvas,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

        return Semantics(
          container: true,
          header: true,
          label: label,
          button: interactive,
          expanded: interactive ? !collapsed : null,
          onTap: onToggle,
          child: ExcludeSemantics(
            child: interactive
                // Hedef bütün satır: 15 puanlık irise nişan almak, telefonu
                // tek elle tutan birinden gereksiz bir hassasiyet ister.
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: row,
                  )
                : row,
          ),
        );
      },
    );
  }
}
