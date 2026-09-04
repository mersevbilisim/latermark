import 'dart:math' as math;
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
class ShutterDock extends StatefulWidget {
  const ShutterDock({
    super.key,
    required this.docked,
    required this.importing,
    required this.onCapture,
    required this.onImport,
    required this.onComposeText,
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

  /// Karesiz kayıt: composer kare olmadan açılır.
  final VoidCallback onComposeText;

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
  State<ShutterDock> createState() => _ShutterDockState();
}

class _ShutterDockState extends State<ShutterDock> {
  /// Sol yuvadaki giriş menüsü açık mı.
  ///
  /// Şerit üç yuvalık bir makine gövdesi: solda giriş, ortada deklanşör,
  /// sağda eleme. İki ayrı giriş denetimi dördüncü bir kütle olurdu ve küçük
  /// ekranda deklanşöre yapışırdı; bunun yerine sol yuva **açılıyor**.
  bool _addOpen = false;

  @override
  void didUpdateWidget(ShutterDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seçim kipine girildiğinde ya da akış boşaldığında yuvanın kendisi
    // kayboluyor; açık kalan menü ekranda asılı kalırdı.
    if (_addOpen && (widget.selecting || !widget.docked)) _addOpen = false;
  }

  void _toggleAdd() => setState(() => _addOpen = !_addOpen);

  void _closeAdd() {
    if (_addOpen) setState(() => _addOpen = false);
  }

  void _pick(VoidCallback action) {
    _closeAdd();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.docked ? 1 : 0),
      // Uygulamadaki en uzun yolculuk: diyafram ekranın ortasından şeride
      // iniyor. Hareket azaltıldığında yol yok, yalnız varış var.
      duration: AppMotion.travel(context, const Duration(milliseconds: 760)),
      curve: Curves.easeOutQuart,
      builder: (context, t, _) {
        return Stack(
          children: [
            // Kartlar düğmenin altından geçerken okunurluğu koruyan perde.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: ShutterDock.dockHeight + safeBottom,
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

            // Galerinin aynadaki eşi. Şerit böylece bir makine gövdesi gibi
            // okunuyor: solda geçmiş kareler, ortada çekim, sağda eleme.
            // Aynı denetim kipi hem açıyor hem kapatıyor — girdiğin kapıdan
            // çıkıyorsun, üstlükte ikinci bir çarpı aramıyorsun.
            if (widget.onToggleSelecting != null)
              Positioned(
                right: 24,
                bottom: safeBottom + 32,
                child: IgnorePointer(
                  ignoring: t < 0.5,
                  child: Opacity(
                    opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                    child: IconOrb(
                      icon: widget.selecting
                          ? Icons.close_rounded
                          : Icons.delete_outline_rounded,
                      semanticLabel: widget.selecting
                          ? context.l10n.selectionExit
                          : context.l10n.selectionStart,
                      onPressed: widget.onToggleSelecting,
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
                child: widget.selecting
                    ? _SelectionWord(
                        count: widget.selectedCount,
                        onDelete: widget.onDeleteSelection,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ProLimits.showsCounter(
                            widget.noteCount,
                            isPro: widget.isPro,
                          )) ...[
                            _LimitCounter(count: widget.noteCount),
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
                              breathing: !widget.docked,
                              bladeBase: palette.isDark
                                  ? palette.canvas
                                  : OnPhoto.canvasDeep,
                              // Vurgu artık ışığın kendisi: kenarlar, ağız ve
                              // halka bu tonu taşıyor.
                              edgeTint: palette.onPhotoAccent,
                              // Vurgu rengi artık delikten sızan ışıkta
                              // değil, gövdenin kendisinde. Deklanşör ekranın
                              // tek dolu kütlesi; rengi taşıyacak yüzey de o.
                              // Gövde her iki temada da grafit olduğu için
                              // fotoğraf üstü (parlak) ton kullanılıyor.
                              accent: palette.onPhotoAccent,
                              // Gövde rengi taşırken deliğin içindeki kor
                              // ikinci bir renk kaynağı oluyor ve bulanık bir
                              // gradyandan ibaret kalıyordu — düğmenin
                              // arkasındaki hale de bir zamanlar aynı sebeple
                              // kaldırılmıştı. Objektifin içi karanlıktır.
                              glow: false,
                              onPressed: widget.onCapture,
                            ),
                          ),
                          // Davet ekrana sığmadığında kaydırılabiliyor:
                          // en büyük yazı boyunda hiçbir şey kırpılmıyor,
                          // her eyleme parmak yetişiyor.
                          //
                          // Kaydırma yüzeyi **yalnız daveti** sarıyor,
                          // sütunun tamamını değil. Şerit yerleştiğinde
                          // davetin yüksekliği sıfıra iniyor ve yüzey onunla
                          // birlikte yok oluyor. Sütun sarılsaydı deklanşör
                          // hizasında ekran genişliğinde görünmez bir yüzey
                          // kalır, sağdaki eleme düğmesinin dokunuşunu
                          // yutardı.
                          //
                          // `Flexible` sayaç ve diyaframdan artan yeri
                          // veriyor; kaydırma da içeriğine göre büzüldüğü
                          // için davet sığdığı sürece düzen bugünkü hâliyle
                          // birebir aynı kalıyor.
                          Flexible(
                            child: ClipRect(
                              child: Align(
                                heightFactor: (1 - t).clamp(0.0, 1.0),
                                child: Opacity(
                                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                                  child: SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    child: _Invitation(
                                      importing: widget.importing,
                                      onImport: widget.onImport,
                                      onComposeText: widget.onComposeText,
                                      onOpenSettings: widget.onOpenSettings,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Menü açıkken ekranın geri kalanına yapılan ilk dokunuş menüyü
            // kapatır ve **altına geçmez**: açık bir menünün üstünden
            // deklanşöre basmak kimsenin niyeti değil.
            if (_addOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Ekran okuyucuda görünmüyor: adsız, ekran boyunda bir
                  // düğme olarak listeleniyordu. Menüyü kapatmanın adı olan
                  // yolu zaten var — artı, açıkken "Vazgeç"e dönüşüyor.
                  excludeFromSemantics: true,
                  onTap: _closeAdd,
                ),
              ),

            // Sol yuva: giriş ailesi.
            //
            // Kapalıyken tek bir artı. Dokununca galeri ve metin, başparmağın
            // vardığı yerde, artının üstünde açılır. Sık kullanılan galeri
            // alta — yani artıya en yakın yere — geliyor; yeni olan metin
            // onun üstünde duruyor.
            Positioned(
              left: 24,
              bottom: safeBottom + 32,
              child: IgnorePointer(
                ignoring: t < 0.5 || widget.selecting,
                child: AnimatedOpacity(
                  key: const ValueKey('dock-add-slot'),
                  duration: AppMotion.fast,
                  opacity: widget.selecting
                      ? 0
                      : ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                  child: _AddSlot(
                    open: _addOpen,
                    importing: widget.importing,
                    onToggle: _toggleAdd,
                    onImport: () => _pick(widget.onImport),
                    onComposeText: () => _pick(widget.onComposeText),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Artı ve üstünde açılan iki giriş.
///
/// Kendi kolonunda büyüyor: kapalıyken yalnız artının yüksekliği kadar yer
/// kaplıyor, açılınca haplar onun üstüne diziliyor. Böylece şeridin taban
/// çizgisi hiç kaymıyor — artı her iki hâlde de aynı noktada duruyor.
class _AddSlot extends StatelessWidget {
  const _AddSlot({
    required this.open,
    required this.importing,
    required this.onToggle,
    required this.onImport,
    required this.onComposeText,
  });

  final bool open;
  final bool importing;
  final VoidCallback onToggle;
  final VoidCallback onImport;
  final VoidCallback onComposeText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: open ? 1 : 0),
      duration: AppMotion.travel(context, const Duration(milliseconds: 260)),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kapalıyken haplar yer kaplamıyor: kolon artının boyuna iniyor.
            //
            // Kapalıyken **hiç kurulmuyorlar** da. Sadece kırpmak yetmiyordu:
            // görünmeyen haplar ağaçta durunca ekran okuyucu onları yine
            // buluyor ve boş ekrandaki davetle aynı eylem iki kez okunuyordu.
            if (t > 0)
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  heightFactor: t.clamp(0.0, 1.0),
                  child: ExcludeSemantics(
                    excluding: !open,
                    child: IgnorePointer(
                      ignoring: !open,
                      // İki hap aynı genişlikte: farklı uzunluktaki iki
                      // etiket sol kenara dayalı durunca sağ kenar tırtıklı
                      // kalıyor ve menü tek bir denetim gibi okunmuyordu.
                      // Genişliği uzun olan belirliyor.
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Üstteki hap biraz gecikmeli çıkıyor; ikisi birden
                            // belirdiğinde menü tek bir blok gibi zıplıyordu.
                            _MenuEntry(
                              progress: _stagger(t, from: 0.15),
                              child: _ActionPill(
                                icon: Icons.text_fields_rounded,
                                label: l10n.composeTextEntry,
                                semanticLabel: l10n.composeTextEntry,
                                onPressed: onComposeText,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _MenuEntry(
                              progress: _stagger(t, to: 0.85),
                              child: _ActionPill(
                                icon: Icons.photo_library_outlined,
                                label: l10n.pickFromGallery,
                                semanticLabel: l10n.pickFromGallery,
                                busyLabel: l10n.galleryPickerOpening,
                                busy: importing,
                                onPressed: onImport,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Stack(
              alignment: Alignment.center,
              children: [
                // Artı, kapanırken çarpıya dönüyor: aynı denetim hem açıyor
                // hem kapatıyor, ikinci bir çıkış aranmıyor.
                AnimatedRotation(
                  turns: open ? 0.125 : 0,
                  duration: AppMotion.travel(
                    context,
                    const Duration(milliseconds: 260),
                  ),
                  curve: Curves.easeOutCubic,
                  child: IconOrb(
                    icon: Icons.add_rounded,
                    semanticLabel: open ? l10n.actionCancel : l10n.addEntry,
                    onPressed: onToggle,
                    size: 44,
                    iconSize: 21,
                    tint: importing && !open ? Colors.transparent : palette.ink,
                    fill: palette.canvasLift,
                  ),
                ),
                if (importing && !open)
                  const IgnorePointer(child: _GalleryActivityGlyph(size: 19)),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Tek bir ilerlemeden kaydırılmış bir aralık çıkarır.
  static double _stagger(double t, {double from = 0, double to = 1}) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);
}

/// Menüdeki tek bir hap: aşağıdan, artının olduğu köşeden büyüyor.
class _MenuEntry extends StatelessWidget {
  const _MenuEntry({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * 10),
        child: Transform.scale(
          scale: 0.92 + 0.08 * progress,
          alignment: AlignmentDirectional.bottomStart,
          child: child,
        ),
      ),
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({
    required this.importing,
    required this.onImport,
    required this.onComposeText,
    this.onOpenSettings,
  });

  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onComposeText;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1);

    // Paragrafın ölçüsü sabit 250 pt değil: yazı büyüdükçe satır da genişler,
    // yoksa aynı cümle altı satıra bölünüp ekranı tek başına yiyor. Tavan
    // ekranın kendisi; okuma genişliği hiçbir zaman kenarlara dayanmıyor.
    final bodyWidth = math.min(media.size.width - 48, 250 * scale);

    // Künye üç kelime: ürünün imzası, işin kendisi değil. Erişilebilirlik
    // boylarında ekranda kalan yer eylemlere gidiyor.
    final showsSignature = scale < 1.5;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.inviteTitle,
            style: palette.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: bodyWidth,
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
          // Boş ekranda iki giriş de **adıyla** duruyor: burada yer var ve
          // yeni gelen kullanıcının ikisini de görmesi gerekiyor. Şerit
          // yerleştiğinde aynı iki eylem sol yuvadaki artının altına
          // toplanıyor. Uzun çevirilerde satır kendiliğinden kırılır.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionPill(
                icon: Icons.photo_library_outlined,
                label: context.l10n.pickFromGallery,
                semanticLabel: context.l10n.pickFromGallery,
                busyLabel: context.l10n.galleryPickerOpening,
                busy: importing,
                onPressed: onImport,
              ),
              _ActionPill(
                key: const ValueKey('invite-action-text'),
                icon: Icons.text_fields_rounded,
                label: context.l10n.composeTextEntry,
                semanticLabel: context.l10n.composeTextEntry,
                onPressed: onComposeText,
              ),
              if (onOpenSettings != null)
                IconOrb(
                  key: const ValueKey('invite-action-settings'),
                  icon: Icons.tune_rounded,
                  semanticLabel: context.l10n.settingsAction,
                  onPressed: onOpenSettings,
                  size: 38,
                  iconSize: 18,
                  tint: palette.inkSoft,
                  fill: palette.canvasLift,
                ),
            ],
          ),
          if (showsSignature) ...[
            const SizedBox(height: 32),
            const _ManifestoSignature(),
          ],
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
                    // Şeridin **tek** eylemi ve mürekkep tonunda yazılınca
                    // fark edilmiyordu: ekranın en görünür noktasında,
                    // deklanşörün yerinde duruyor ama sıradan bir yazı gibi
                    // okunuyordu. Kor rengi, kutu çizmeden "asıl olan bu"
                    // demenin bu uygulamadaki karşılığı.
                    //
                    // Basılıyken kırmızıya geçiyor: renk önce önemi, sonra
                    // yıkıcılığı söylüyor.
                    accent: true,
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

/// Adıyla duran ikincil eylem.
///
/// Boş ekrandaki davet ile şeritteki giriş menüsü aynı hapı kullanıyor: iki
/// yerde iki ayrı görünüm olsaydı aynı eylem iki farklı şey gibi okunurdu.
/// Yüzey tonu ve yarım piksellik süperelips kenar dışında hiçbir ayrım yok —
/// gölge yok, çünkü davet kapanırken `ClipRect` içinde kalıyor ve dış gölge
/// orada keskin bir alt çizgiye dönüşüyor.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Eylem sürüyor: simge yerine çalışma imi döner.
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Pressable(
      onPressed: busy ? null : onPressed,
      semanticLabel: semanticLabel,
      semanticValue: busy ? busyLabel : null,
      scale: 0.985,
      // Hap 37 pt yüksekliğinde çiziliyor; dokunma alanı 44'e tamamlanıyor.
      minimumTarget: const Size.fromHeight(44),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.canvasLift,
          shape: AppShape.border(
            AppShape.control,
            side: BorderSide(color: palette.hairlineBright, width: 0.5),
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
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.78,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: busy
                      ? const _GalleryActivityGlyph(
                          key: ValueKey('pill-busy'),
                          size: 17,
                        )
                      : Icon(
                          icon,
                          key: const ValueKey('pill-idle'),
                          size: 17,
                          color: palette.ember,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Erişilebilirlik boylarında ad hapı taşırıyordu. Esneme payı
              // hapın kendisinde: kelime kırılır, satır büyür, kap uyar.
              Flexible(
                child: Text(
                  label,
                  style: palette.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
