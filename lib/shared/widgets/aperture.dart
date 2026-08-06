import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_motion.dart';

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
  });

  final double openness;
  final double twist;
  final int bladeCount;
  final Color? edgeTint;
  final Color bladeBase;

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
      if (reach > halfSide) {
        final rim = touch + tangent * reach;
        edges
          ..moveTo(vertex.dx, vertex.dy)
          ..lineTo(rim.dx, rim.dy);
      }
    }
    hole.close();
    // Çokgeni köşeden başlattığımız için ilk köşeyi sona kapatmak yeterli.

    final bounds = Rect.fromCircle(center: center, radius: outer);
    final blades = Path.combine(
      PathOperation.difference,
      Path()..addOval(bounds),
      hole,
    );

    // 1) Bıçakların gövdesi. Arkadaki kor parıltısını büyük ölçüde kapatır;
    // aksi halde metal yerine sisli bir bulut gibi görünür.
    canvas.drawPath(
      blades,
      Paint()..color = bladeBase.withValues(alpha: 0.88),
    );

    final tint = edgeTint ?? OnPhoto.flash;

    // 2) Metalik yanılsama: köşeden köşeye ışık düşüşü.
    //
    // Gölge rengi de kenar rengiyle aynı kaynaktan gelir. Aydınlık temada bu
    // koyu bir mürekkeptir; sabit beyaz kullanılsaydı diyafram açık zeminde
    // tamamen kaybolurdu.
    canvas.drawPath(
      blades,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.24),
            tint.withValues(alpha: 0.06),
            tint.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );

    // 3) Bıçakları birbirinden ayıran ince kenarlar.
    canvas.drawPath(
      edges,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: 0.22),
    );

    // 4) Açıklığın keskin ağzı.
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.miter
        ..color = tint.withValues(alpha: 0.46),
    );

    // 5) Dış gövde halkası.
    canvas.drawCircle(
      center,
      outer - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tint.withValues(alpha: 0.38),
    );
  }

  @override
  bool shouldRepaint(_AperturePainter old) =>
      old.openness != openness ||
      old.twist != twist ||
      old.bladeCount != bladeCount ||
      old.edgeTint != edgeTint ||
      old.bladeBase != bladeBase;
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
    this.semanticLabel = 'Fotoğraf çek',
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

  final String semanticLabel;

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
      label: widget.semanticLabel,
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
            final resting = lerpDouble(1.0, 0.92, widget.breathing ? breath : 0)!;
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
                    if (widget.glow) ...[
                      OverflowBox(
                        maxWidth: widget.size * 1.9,
                        maxHeight: widget.size * 1.9,
                        child: _Bloom(
                          size: widget.size * 1.9,
                          opacity:
                              lerpDouble(0.9, 0.35, pressed)! *
                              lerpDouble(1.0, 0.7, breath)!,
                        ),
                      ),
                      _Core(size: widget.size * openness * 1.35),
                    ],
                    Aperture(
                      openness: openness,
                      twist: twist,
                      bladeBase: widget.bladeBase,
                      edgeTint: widget.edgeTint,
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

/// Diyaframın dışına taşan geniş, yumuşak hale.
class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [OnPhoto.emberGlow, Color(0x00FF7A55)],
              stops: [0.25, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Açıklıktan sızan sıcak çekirdek.
class _Core extends StatelessWidget {
  const _Core({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x59FF7A55), Color(0x00FF7A55)],
            stops: [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
