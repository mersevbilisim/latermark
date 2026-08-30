import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/aperture.dart';
import '../../../../../shared/widgets/colophon_bar.dart';
import '../../../../../shared/widgets/icon_orb.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../../paywall/domain/pro_limits.dart';

/// Deklanşörün ana ekrandaki yeri.
///
/// Uygulama boşken diyafram ekranın ortasında, nefes alarak durur ve altında
/// ne yapılacağını söyleyen iki satır vardır. İlk not kaydedildiği anda
/// küçülüp aşağı, akışın üstündeki yerine kayar. Böylece uygulama kullanıcıyla
/// birlikte büyür — iki ayrı ekran yerine tek bir sürekli hareket.
///
/// Yerleştiğinde şerit bir makine gövdesi gibi okunur: solda galeri, ortada
/// deklanşör, sağda seçim. Üç denetim de başparmağın vardığı yerde ve hiçbiri
/// diğerini bastırmıyor — ortadaki tek dolu kütle, yanlardakiler sessiz cam.
class ShutterDock extends StatelessWidget {
  const ShutterDock({
    super.key,
    required this.docked,
    required this.importing,
    required this.onCapture,
    required this.onImport,
    required this.noteCount,
    required this.isPro,
    this.onOpenSettings,
    this.selecting = false,
    this.selectedCount = 0,
    this.onToggleSelecting,
    this.onDeleteSelection,
  });

  /// `true` ise aşağıya yerleşmiş, `false` ise ortada davet ediyor.
  final bool docked;

  /// Sistem fotoğraf seçicisi açılırken galeri eylemlerinin etkinlik durumu.
  final bool importing;

  final VoidCallback onCapture;
  final VoidCallback onImport;

  /// Sınır sayacı için. Kullanıcı duvara habersiz toslamamalı: son birkaç
  /// karede deklanşörün altında kaç hakkı kaldığı görünür.
  final int noteCount;
  final bool isPro;

  /// Boş ekranda başlık çubuğu olmadığı için ayarlara giriş buradan verilir.
  final VoidCallback? onOpenSettings;

  /// Toplu silme kipi. Açıkken deklanşörün yeri künye diline bırakılır:
  /// seçim yaparken çekilecek bir kare yok.
  final bool selecting;
  final int selectedCount;

  /// Kipi açıp kapatan sağ denetim. `null` ise akış boştur ve silinecek bir
  /// şey yoktur; denetim hiç çizilmez.
  final VoidCallback? onToggleSelecting;

  /// Silme kelimesine dokunulduğunda çağrılır.
  final VoidCallback? onDeleteSelection;

  /// Akışın alt boşluğu bu değere göre ayarlanır.
  static const dockHeight = 148.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: docked ? 1 : 0),
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeOutQuart,
      builder: (context, t, _) {
        return Stack(
          children: [
            // Kartlar düğmenin altından geçerken okunurluğu koruyan perde.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: dockHeight + safeBottom,
              child: IgnorePointer(
                child: Opacity(
                  opacity: t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // Düğmenin oturduğu yükseklikte perde tamamen kapalı
                        // olmalı; yarı saydam kalırsa altındaki kartın yazısı
                        // diyaframın içinden okunuyor.
                        colors: [
                          palette.canvas.withValues(alpha: 0),
                          palette.canvas.withValues(alpha: 0.85),
                          palette.canvas,
                        ],
                        stops: const [0.0, 0.34, 0.58],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Akış varken galeri eylemi deklanşörün solunda sessizce
            // belirir. Deklanşör merkezde kalır; iki eylem birbirine rakip
            // olmaz. Seçim kipinde bu yuva boşalır: silinecek kareler
            // seçilirken yeni kare almanın anlamı yok.
            Positioned(
              left: 24,
              bottom: safeBottom + 32,
              child: IgnorePointer(
                ignoring: t < 0.5 || selecting,
                child: AnimatedOpacity(
                  key: const ValueKey('dock-gallery-slot'),
                  duration: AppMotion.fast,
                  opacity: selecting ? 0 : ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconOrb(
                        icon: Icons.photo_library_outlined,
                        semanticLabel: importing
                            ? context.l10n.galleryPickerOpening
                            : context.l10n.pickFromGallerySemantic,
                        onPressed: onImport,
                        size: 44,
                        iconSize: 19,
                        tint: importing ? Colors.transparent : palette.ink,
                        fill: palette.canvasLift,
                      ),
                      if (importing)
                        const IgnorePointer(
                          child: _GalleryActivityGlyph(size: 19),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Galerinin aynadaki eşi. Şerit böylece bir makine gövdesi gibi
            // okunuyor: solda geçmiş kareler, ortada çekim, sağda eleme.
            // Aynı denetim kipi hem açıyor hem kapatıyor — girdiğin kapıdan
            // çıkıyorsun, üstlükte ikinci bir çarpı aramıyorsun.
            if (onToggleSelecting != null)
              Positioned(
                right: 24,
                bottom: safeBottom + 32,
                child: IgnorePointer(
                  ignoring: t < 0.5,
                  child: Opacity(
                    opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                    child: IconOrb(
                      icon: selecting
                          ? Icons.close_rounded
                          : Icons.delete_outline_rounded,
                      semanticLabel: selecting
                          ? context.l10n.selectionExit
                          : context.l10n.selectionStart,
                      onPressed: onToggleSelecting,
                      size: 44,
                      iconSize: 19,
                      tint: palette.ink,
                      fill: palette.canvasLift,
                    ),
                  ),
                ),
              ),

            Align(
              alignment: Alignment.lerp(
                const Alignment(0, -0.08),
                Alignment.bottomCenter,
                t,
              )!,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: lerpDouble(0, 20 + safeBottom, t)!,
                ),
                child: selecting
                    ? _SelectionWord(
                        count: selectedCount,
                        onDelete: onDeleteSelection,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ProLimits.showsCounter(
                            noteCount,
                            isPro: isPro,
                          )) ...[
                            _LimitCounter(count: noteCount),
                            const SizedBox(height: 10),
                          ],
                          DecoratedBox(
                            // Gerçek bir objektif diyaframı temayla beyaza dönmez.
                            // Aydınlık zeminde sabit grafit gövde, kontrollü temas
                            // gölgesiyle yüzeyden ayrılır; bulanıklık katmanı yoktur.
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: palette.isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: palette.ink.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 26,
                                        offset: const Offset(0, 11),
                                      ),
                                      BoxShadow(
                                        color: palette.ink.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: ApertureButton(
                              size: lerpDouble(112, 68, t)!,
                              breathing: !docked,
                              bladeBase: palette.isDark
                                  ? palette.canvas
                                  : OnPhoto.canvasDeep,
                              edgeTint: palette.isDark
                                  ? palette.ink
                                  : OnPhoto.ink,
                              onPressed: onCapture,
                            ),
                          ),
                          ClipRect(
                            child: Align(
                              heightFactor: (1 - t).clamp(0.0, 1.0),
                              child: Opacity(
                                opacity: (1 - t * 2).clamp(0.0, 1.0),
                                child: _Invitation(
                                  importing: importing,
                                  onImport: onImport,
                                  onOpenSettings: onOpenSettings,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({
    required this.importing,
    required this.onImport,
    this.onOpenSettings,
  });

  final bool importing;
  final VoidCallback onImport;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.inviteTitle, style: palette.bodyStrong),
          const SizedBox(height: 8),
          SizedBox(
            width: 250,
            child: Text(
              context.l10n.inviteBody,
              textAlign: TextAlign.center,
              style: palette.caption.copyWith(
                color: palette.inkSoft,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                onPressed: onImport,
                semanticLabel: importing
                    ? context.l10n.galleryPickerOpening
                    : context.l10n.pickFromGallerySemantic,
                scale: 0.985,
                child: DecoratedBox(
                  // Bu alan kapanırken ClipRect içinde kalıyor. Dış gölge
                  // keskin bir alt çizgiye dönüşeceği için ayrımı yalnızca
                  // yüzey tonu ve yarım piksellik süperelips kenar kurar.
                  decoration: ShapeDecoration(
                    color: palette.canvasLift,
                    shape: AppShape.border(
                      AppShape.control,
                      side: BorderSide(
                        color: palette.hairlineBright,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 17, 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 17,
                          child: AnimatedSwitcher(
                            duration: AppMotion.fast,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.78,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: importing
                                ? const _GalleryActivityGlyph(
                                    key: ValueKey('gallery-loading'),
                                    size: 17,
                                  )
                                : Icon(
                                    Icons.photo_library_outlined,
                                    key: const ValueKey('gallery-idle'),
                                    size: 17,
                                    color: palette.ember,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.pickFromGallery,
                          style: palette.label,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onOpenSettings != null) ...[
                const SizedBox(width: 12),
                IconOrb(
                  icon: Icons.tune_rounded,
                  semanticLabel: context.l10n.settingsAction,
                  onPressed: onOpenSettings,
                  size: 38,
                  iconSize: 18,
                  tint: palette.inkSoft,
                  fill: palette.canvasLift,
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          const _ManifestoSignature(),
        ],
      ),
    );
  }
}

/// Seçim kipinde deklanşörün yerini alan tek kelime.
///
/// Buraya bir düğme konmuyor. Uygulamanın eylem dili tipografik: not
/// detayının dibindeki şeritte de kutu, ikon ya da dolgu yok — kelimenin
/// kendisi duruyor ve karar verildiği an parmağın altında tehlike rengine
/// dönüyor. Toplu silme için ayrı bir hap düğme çizmek, ekranın en görünür
/// noktasına uygulamaya ait olmayan ikinci bir dil koymak olurdu.
///
/// Kelime deklanşörün tam yerine, aynı eksene oturuyor; yanlardaki iki
/// denetime değmesin diye orta koridorla sınırlanıyor.
class _SelectionWord extends StatelessWidget {
  const _SelectionWord({required this.count, required this.onDelete});

  final int count;
  final VoidCallback? onDelete;

  /// Sağdaki ve soldaki yuvarlak denetimlere değmeyen orta koridor.
  static const _corridor = 176.0;

  /// Deklanşörle aynı yükseklik: kip değişirken eksen kaymıyor.
  static const _height = 68.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: _corridor,
      height: _height,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.ease,
        switchOutCurve: AppMotion.exit,
        // Hiçbir şey seçilmemişken sönük bir düğme değil, ne yapılacağını
        // söyleyen tek satır durur.
        child: count == 0
            ? Center(
                key: const ValueKey('selection-idle'),
                child: Text(
                  context.l10n.selectionHint,
                  textAlign: TextAlign.center,
                  style: palette.caption.copyWith(
                    color: palette.inkFaint,
                    height: 1.35,
                  ),
                ),
              )
            : ColophonBar(
                key: const ValueKey('selection-delete'),
                height: _height,
                // Şeridi zaten perde sınırlıyor; ikinci bir güverte çizgisi
                // akışın orada bittiğini söylerdi, oysa kartlar altından
                // geçmeye devam ediyor.
                rule: false,
                actions: [
                  ColophonAction(
                    key: const ValueKey('selection-delete-action'),
                    label: context.l10n.actionDelete,
                    semanticLabel: context.l10n.actionDelete,
                    pressColor: palette.danger,
                    onPressed: onDelete,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Galeri seçicisi hazırlanırken fotoğraf ikonunun yerini alan mikro iris.
///
/// Standart platform spinner'ı yerine uygulamanın ana ambleminin küçük bir
/// sürümü döner. Yalnızca bu 17–19 px alan yeniden boyandığı için sürekli bir
/// blur ya da geniş animasyon katmanı oluşturmaz.
class _GalleryActivityGlyph extends StatefulWidget {
  const _GalleryActivityGlyph({super.key, required this.size});

  final double size;

  @override
  State<_GalleryActivityGlyph> createState() => _GalleryActivityGlyphState();
}

class _GalleryActivityGlyphState extends State<_GalleryActivityGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin
        ..stop()
        ..value = 0.28;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: RotationTransition(
            // Kor nokta irisin simetrisini bilinçli olarak bozuyor. Bu yüzden
            // bir bıçak aralığı değil tam tur döner; 0° ile 360° aynı kare
            // olduğundan döngü geri sarmadan kesintisiz birleşir.
            turns: _spin,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Aperture(
                  openness: 0.42,
                  twist: -0.08,
                  bladeCount: 7,
                  bladeBase: palette.canvasLift,
                  edgeTint: palette.ember,
                ),
                Positioned(
                  top: -0.25,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.ember,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: widget.size * 0.17),
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

/// Boş sahnenin marka imzası.
///
/// Diyafram zaten amblem gibi davrandığı için burada yeni bir logo ya da
/// dekorasyon üretilmez. Geniş harf aralığı, üç kısa vaat ve kor noktaları
/// ekranın en alçak sesli ama en kalıcı satırını kurar.
class _ManifestoSignature extends StatelessWidget {
  const _ManifestoSignature();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final words = [
      context.l10n.manifestoFirst,
      context.l10n.manifestoSecond,
      context.l10n.manifestoThird,
    ];
    final style = palette.overline.copyWith(
      color: palette.ink.withValues(alpha: palette.isDark ? 0.52 : 0.48),
      fontSize: 9.5,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.15,
    );

    return Semantics(
      label: words.join(', '),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.upper(words[0]), style: style),
                const _ManifestoDot(),
                Text(context.l10n.upper(words[1]), style: style),
                const _ManifestoDot(),
                Text(context.l10n.upper(words[2]), style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManifestoDot extends StatelessWidget {
  const _ManifestoDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.ember,
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: 4.5),
      ),
    );
  }
}

/// Ücretsiz katmanda kalan hakkı gösteren sessiz sayaç.
///
/// Yalnızca sınıra yaklaşınca beliriyor. Sürekli görünen bir sayaç, ödeme
/// yapmamış kullanıcıyı her açılışta rahatsız eder ve uygulamanın sakin
/// kişiliğini bozardı.
class _LimitCounter extends StatelessWidget {
  const _LimitCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final full = count >= ProLimits.freeNotes;

    return Text(
      context.l10n.paywallCounter(count, ProLimits.freeNotes),
      style: palette.caption.copyWith(
        color: full ? palette.ember : palette.inkFaint,
        fontWeight: full ? FontWeight.w600 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
