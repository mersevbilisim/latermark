import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_motion.dart';
import '../../l10n/l10n_context.dart';

/// Uygulamanın imzası: gerçek bir objektif diyaframı gibi davranan, tamamen
/// el ile çizilmiş iris.
///
/// Geometri gerçeğe sadıktır — açıklık, [bladeCount] kenarlı düzgün bir çokgen
/// olarak açılır; bıçak kenarları bu çokgenin kenarlarının dış çembere kadar
/// uzatılmasıyla elde edilir. Bu yüzden kapanırken hafifçe burulur.
class Aperture extends StatelessWidget {
  const Aperture({
    super.key,
    required this.openness,
    this.twist = 0,
    this.bladeCount = 7,
    this.edgeTint,
    this.bladeBase,
    this.glow = 0,
    this.glowColor,
    this.barrel,
  });

  /// 0 = tamamen kapalı, 1 = tamamen açık.
  final double openness;

  /// Bıçakların dönme açısı (radyan). Kapanma hissini fiziksel kılar.
  final double twist;

  final int bladeCount;

  /// Bıçak kenarlarına verilecek renk. Boşsa nötr beyaz kullanılır.
  final Color? edgeTint;

  /// Bıçakların gövde rengi — arkadaki parıltıyı örter.
  ///
  /// Ana ekranda temanın zemini, fotoğraf üstünde ise koyu zemin verilir.
  final Color? bladeBase;

  /// Açıklıktan sızan ışığın gücü (0 = yok).
  ///
  /// Ayrı bir katman değil, çizimin parçası — çünkü ışık **deliğin şeklini
  /// alır**. Yuvarlak bir gradyan yedigen bir açıklığın içinde puslu bir leke
  /// gibi duruyordu; gerçek optikte bokeh'in yedi kenarlı olmasının sebebi de
  /// aynı: ışık geçtiği diyaframın kesitini taşır.
  final double glow;

  /// Işığın rengi. Boşsa kor çizilmez.
  final Color? glowColor;

  /// Bıçakların **arkasındaki** namlunun rengi. Boşsa açıklık saydam kalır.
  ///
  /// Deklanşör düğmesinde dolu: aydınlık temada delik, sayfanın zeminini
  /// gösterip gövdeye açılmış bir delik gibi duruyordu — oysa bir objektifin
  /// içine bakınca karanlık görürsün, gövdeyle aynı malzeme. Örtücü onayında
  /// ise iris **fotoğrafın üstüne** kapanıyor; orada namlu doldurulursa kare
  /// daha iris açıkken örtülürdü. Bu yüzden karar çağırana bırakılıyor.
  final Color? barrel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Çocuğu olmayan bir `CustomPaint` varsayılan olarak `Size.zero` alır ve
      // hiçbir şey çizmez. `Size.infinite` verilince gelen kısıtlara sıkışır,
      // yani ebeveyni ne kadar yer verirse onu kaplar.
      size: Size.infinite,
      painter: _AperturePainter(
        openness: openness.clamp(0.0, 1.0),
        twist: twist,
        bladeCount: bladeCount,
        edgeTint: edgeTint,
        bladeBase: bladeBase ?? OnPhoto.canvas,
        glow: glow.clamp(0.0, 1.0),
        glowColor: glowColor,
        barrel: barrel,
      ),
      isComplex: true,
    );
  }
}

class _AperturePainter extends CustomPainter {
  _AperturePainter({
    required this.openness,
    required this.twist,
    required this.bladeCount,
    required this.edgeTint,
    required this.bladeBase,
    required this.glow,
    required this.glowColor,
    required this.barrel,
  });

  final double openness;
  final double twist;
  final int bladeCount;
  final Color? edgeTint;
  final Color bladeBase;
  final double glow;
  final Color? glowColor;
  final Color? barrel;

  /// Açıklığın yarıçapı hiçbir zaman sıfıra inmez; sıfır çokgen bozuk yol üretir.
  static const _minInradius = 0.045;
  static const _maxInradius = 0.63;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    if (outer <= 0) return;

    final n = bladeCount;
    final inradius = lerpDouble(_minInradius, _maxInradius, openness)! * outer;
    final halfSide = inradius * math.tan(math.pi / n);
    // Kenarın dış çembere ulaşana kadar uzatılacağı mesafe.
    final reach = math.sqrt(math.max(0, outer * outer - inradius * inradius));

    final hole = Path();
    final edges = Path();
    final rimAngles = <double>[];

    for (var k = 0; k < n; k++) {
      final angle = twist + 2 * math.pi * k / n;
      final normal = Offset(math.cos(angle), math.sin(angle));
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final touch = center + normal * inradius;

      final vertex = touch + tangent * halfSide;
      if (k == 0) {
        hole.moveTo(vertex.dx, vertex.dy);
      } else {
        hole.lineTo(vertex.dx, vertex.dy);
      }

      // Bıçağın arka kenarı: aynı doğru üzerinde, köşeden dış çembere.
      final rim = touch + tangent * reach;
      // Yaprak tonlaması bu kenarların arasına düşüyor; açıyı burada bir kez
      // hesaplayıp saklamak, ton döngüsünde aynı geometriyi tekrar kurmaktan
      // ucuz ve ikisinin ayrışmasını imkânsız kılıyor.
      rimAngles.add(math.atan2(rim.dy - center.dy, rim.dx - center.dx));
      if (reach > halfSide) {
        edges
          ..moveTo(vertex.dx, vertex.dy)
          ..lineTo(rim.dx, rim.dy);
      }
    }
    rimAngles.sort();
    hole.close();
    // Çokgeni köşeden başlattığımız için ilk köşeyi sona kapatmak yeterli.

    final bounds = Rect.fromCircle(center: center, radius: outer);
    final blades = Path.combine(
      PathOperation.difference,
      Path()..addOval(bounds),
      hole,
    );

    // 0) Açıklıktan sızan ışık — **deliğin kendi şeklinde**.
    //
    // Bıçaklar deliği zaten dışarıda bırakıyor, bu yüzden kor doğrudan `hole`
    // yoluna dökülüyor: yedigen, iris kapandıkça onunla birlikte küçülüyor ve
    // burulurken onunla dönüyor. Ayrı bir daire katmanı olsaydı hiçbiri
    // olmazdı.
    final inside = barrel;
    if (inside != null) {
      canvas.drawPath(hole, Paint()..color = inside.withValues(alpha: 0.94));
    }

    final light = glowColor;
    if (light != null && glow > 0) {
      canvas.drawPath(
        hole,
        Paint()
          ..shader = RadialGradient(
            colors: [
              light.withValues(alpha: 0.17 * glow),
              light.withValues(alpha: 0.04 * glow),
              light.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.42, 0.95],
          ).createShader(hole.getBounds()),
      );
    }

    // 1) Bıçakların gövdesi. Arkadaki kor parıltısını büyük ölçüde kapatır;
    // aksi halde metal yerine sisli bir bulut gibi görünür.
    canvas.drawPath(blades, Paint()..color = bladeBase.withValues(alpha: 0.88));

    final tint = edgeTint ?? OnPhoto.flash;

    // 2) Yapraklar **tek tek** tonlanıyor.
    //
    // Bütün halkayı tek bir gradyanla boyamak, nesneyi mekanizma değil
    // *mekanizma resmi* yapıyordu: yedi bıçak da aynı tondaydı ve göz onları
    // ayıramıyordu. Gerçek bir iriste her yaprak düz bir metal parçası ve
    // ışığı kendi açısıyla alıyor — ışığa dönük yaprak parlak, karşısındaki
    // sönük.
    //
    // Her yaprak kendi dilimine kırpılıyor. Yarım düzlemle çizmeyi denedim;
    // dilimler devasa daire parçaları oluyor, üst üste binen yerlerde ton
    // birikiyor ve nesne metal yerine kâğıt yelpazeye dönüyordu. Dilim sınırı
    // zaten çizilen bıçak kenarının ta kendisi, yani ton ile çizgi birebir
    // hizada.
    //
    // Yol birleştirme yerine kırpma kullanılıyor: bu çizim boştaki nefes
    // döngüsünde her kare yeniden koşuyor ve yedi boole işlemi o döngüde
    // gereksiz pahalı.
    const lightDx = -0.7071;
    const lightDy = -0.7071;
    final sweep = 2 * math.pi / n;
    final wedgeBounds = Rect.fromCircle(center: center, radius: outer * 1.2);

    for (var k = 0; k < n; k++) {
      final start = rimAngles[k];
      final mid = start + sweep / 2;
      final facing =
          0.5 + 0.5 * (math.cos(mid) * lightDx + math.sin(mid) * lightDy);

      final wedge = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(wedgeBounds, start, sweep, false)
        ..close();

      canvas.save();
      canvas.clipPath(blades);
      canvas.clipPath(wedge);
      canvas.drawRect(
        bounds,
        Paint()..color = tint.withValues(alpha: 0.025 + 0.075 * facing),
      );
      canvas.restore();
    }

    // 3) Bütün takımın üzerinden geçen tek parlaklık.
    //
    // Yaprak tonları ayrımı kuruyor, bu da onları **aynı** parçanın parçaları
    // yapıyor: tek bir yüzeyden yansıyan ortak ışık.
    canvas.drawPath(
      blades,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.10),
            tint.withValues(alpha: 0.02),
            tint.withValues(alpha: 0.07),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );

    // 4) Üstteki yaprağın alttakine düşürdüğü gölge, sonra kenarın kendisi.
    //
    // Tek bir açık çizgi, iki yaprağı yan yana duran iki alan gibi
    // gösteriyordu. Gölge onları üst üste bindiriyor: biri diğerinin altında.
    // Gölge `bladeBase` değil **siyah**: gövde rengiyle çizilen bir gölge, koyu
    // temada yaprakların üstünde kayboluyordu. Siyah yerel kontrast üretiyor ve
    // zeminin parlaklığından bağımsız çalışıyor.
    canvas.drawPath(
      edges,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF000000).withValues(alpha: 0.22),
    );
    canvas.drawPath(
      edges,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: 0.30),
    );

    // 5) Açıklığın keskin ağzı.
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.miter
        ..color = tint.withValues(alpha: 0.46),
    );

    // 6) Gövde halkası — düz bir çember değil, **ışığı tek yönden alan** kenar.
    //
    // Eşit parlaklıkta bir çember, gövdeyi çizilmiş bir daireye çeviriyordu.
    // Gerçek bir objektif halkası ışığı bir yandan alır: sol üstte keskin bir
    // parlama, sağ altta sönük bir dönüş. Karanlık temada zeminden ayıran şey
    // de artık bu kenar; etrafa yayılan bir renk bulutuna gerek kalmıyor —
    // koyu bir nesneyi koyu bir yüzeyde ayıran şey gerçek hayatta da halesi
    // değil, kenarındaki ışıktır.
    final rim = Rect.fromCircle(center: center, radius: outer - 0.6);
    canvas.drawCircle(
      center,
      outer - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = SweepGradient(
          // 0. durak sol üste düşsün: sahnenin ışığı oradan geliyor.
          transform: const GradientRotation(-math.pi * 0.75),
          colors: [
            tint.withValues(alpha: 0.66),
            tint.withValues(alpha: 0.20),
            tint.withValues(alpha: 0.09),
            tint.withValues(alpha: 0.34),
            tint.withValues(alpha: 0.66),
          ],
          stops: const [0.0, 0.26, 0.52, 0.82, 1.0],
        ).createShader(rim),
    );

    // 7) Namlunun iç pahı. Bir puanlık ikinci hat gövdeye kalınlık veriyor;
    // tek çizgi hâlinde halka sac gibi ince duruyordu.
    canvas.drawCircle(
      center,
      outer - 2.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = SweepGradient(
          // İç pah dışarıdakinin tersinden aydınlanır: ışık namlunun
          // içinde karşı duvara çarpıyor.
          transform: const GradientRotation(math.pi * 0.25),
          colors: [
            tint.withValues(alpha: 0.26),
            tint.withValues(alpha: 0.05),
            tint.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rim),
    );
  }

  @override
  bool shouldRepaint(_AperturePainter old) =>
      old.openness != openness ||
      old.twist != twist ||
      old.bladeCount != bladeCount ||
      old.edgeTint != edgeTint ||
      old.bladeBase != bladeBase ||
      old.glow != glow ||
      old.glowColor != glowColor ||
      old.barrel != barrel;
}

/// Diyaframı dokunulabilir bir deklanşöre çevirir.
///
/// Basıldığında iris kapanır ve burulur, bırakıldığında geri açılır. [locked]
/// verildiğinde kapalı kalır — çekim sürerken kullanılır.
class ApertureButton extends StatefulWidget {
  const ApertureButton({
    super.key,
    required this.onPressed,
    this.size = 92,
    this.breathing = false,
    this.glow = true,
    this.locked = false,
    this.bladeBase,
    this.edgeTint,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final double size;

  /// Boştayken çok yavaş bir açılıp kapanma döngüsü.
  final bool breathing;

  /// Arkadaki sıcak parıltı. Kamera önizlemesi üzerinde kapatılır.
  final bool glow;

  final bool locked;

  /// Bıçakların gövde rengi; boşsa koyu zemin varsayılır.
  final Color? bladeBase;

  /// Kenar ve gölge rengi; boşsa beyaz. Aydınlık temada mürekkep verilir.
  final Color? edgeTint;

  final String? semanticLabel;

  @override
  State<ApertureButton> createState() => _ApertureButtonState();
}

class _ApertureButtonState extends State<ApertureButton>
    with TickerProviderStateMixin {
  static const _bladeCount = 7;

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    reverseDuration: const Duration(milliseconds: 280),
  );

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  );

  @override
  void initState() {
    super.initState();
    if (widget.breathing) _breath.repeat(reverse: true);
    if (widget.locked) _press.value = 1;
  }

  @override
  void didUpdateWidget(ApertureButton old) {
    super.didUpdateWidget(old);
    if (widget.breathing != old.breathing) {
      widget.breathing ? _breath.repeat(reverse: true) : _breath.stop();
    }
    if (widget.locked != old.locked) {
      widget.locked ? _press.forward() : _press.reverse();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.locked) return;
    _press.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.locked) return;
    HapticFeedback.mediumImpact();
    _press.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    if (widget.locked) return;
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? context.l10n.shutterSemantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _breath]),
          builder: (context, _) {
            final pressed = AppMotion.ease.transform(_press.value);
            final breath = Curves.easeInOut.transform(_breath.value);
            final resting = lerpDouble(
              1.0,
              0.92,
              widget.breathing ? breath : 0,
            )!;
            final openness = lerpDouble(resting, 0.14, pressed)!;
            final twist = -(2 * math.pi / _bladeCount) * 0.5 * pressed;

            return Transform.scale(
              scale: lerpDouble(1.0, 0.93, pressed)!,
              // Düzen boyutu tam olarak `size`; hale bunun dışına taşar ama
              // dokunma alanını büyütmez.
              child: SizedBox.square(
                dimension: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Işık gövdenin **etrafında** değil, açıklığın **içinde**.
                    //
                    // Eskiden düğmenin arkasında, çapının iki katına yakın bir
                    // renk bulutu duruyordu. Gerçek bir objektifte ışık halede
                    // değil deliktedir; hale yalnız bir efektti ve düğmeyi
                    // uygulamanın en amatör parçası yapıyordu.
                    Aperture(
                      openness: openness,
                      twist: twist,
                      bladeBase: widget.bladeBase,
                      edgeTint: widget.edgeTint,
                      glow: widget.glow
                          ? lerpDouble(1.0, 0.35, pressed)! *
                                lerpDouble(1.0, 0.78, breath)!
                          : 0,
                      glowColor: context.palette.onPhotoAccent,
                      barrel: widget.bladeBase ?? OnPhoto.canvas,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
