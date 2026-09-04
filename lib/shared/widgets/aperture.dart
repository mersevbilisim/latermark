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
/// Sahnenin varsayılan ışık yönü: sol üst.
///
/// Arayüzün geri kalanı da ışığı oradan alıyor; nesnenin kendi başına başka
/// bir yöne bakması onu sahneden koparırdı.
const double kApertureLightAngle = -math.pi * 0.75;

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
    this.accent,
    this.lightAngle = kApertureLightAngle,
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

  /// Gövdeye karışan ısı — eloksal kaplı bir objektif gibi.
  ///
  /// Pay bilinçli olarak küçük. Gövdeyi baskın biçimde boyamak denendi ve
  /// nesneyi **kil bir diske** çeviriyordu: bu çizimin bütün modellemesi
  /// koyu zemine düşen açık ışık üzerine kurulu, gövde açılınca bıçak
  /// kenarlarındaki çizgiler metal parlaması değil tebeşir hattı gibi
  /// okunuyor. Renk asıl gücünü [edgeTint] üzerinden, yani **ışığın kendisi**
  /// olarak taşıyor.
  ///
  /// Bu ton verildiğinde dış halkanın en parlak durağı da beyaza kaçar:
  /// eloksal bir yüzeyde de dar parlama, gövdenin renginden bağımsızdır.
  ///
  /// Boşsa nesne nötr grafit gövdesiyle çizilir.
  final Color? accent;

  /// Sahnedeki ışığın geldiği yön (radyan).
  ///
  /// Bu çizimdeki bütün modelleme tek bir ışığa dayanıyor: yaprak tonları,
  /// gövde halkasındaki parlama ve namlunun iç pahı. Eskiden açı **üç ayrı
  /// yerde** sabit yazılıydı; biri değiştirilse nesne kendi içinde çelişirdi.
  /// Tek sayıya indirilmesinin asıl kazancı da bu değil: ışık artık
  /// oynatılabilir bir şey. Nesne yerinde durur, ışık gezer — bir cismi
  /// gerçek yapan da budur.
  final double lightAngle;

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
        accent: accent,
        lightAngle: lightAngle,
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
    required this.accent,
    required this.lightAngle,
  });

  final double openness;
  final double twist;
  final int bladeCount;
  final Color? edgeTint;
  final Color bladeBase;
  final double glow;
  final Color? glowColor;
  final Color? barrel;
  final Color? accent;
  final double lightAngle;

  /// Gövdenin ısıya kaçan payı. Bkz. [Aperture.accent].
  static const _bodyTint = 0.19;

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
    //
    // Vurgu rengi buraya giriyor: metalin **kendi** rengi. Işığı taşıyan
    // katmanlar (yaprak tonu, kenarlar, ağız) nötr kalıyor.
    final metal = accent == null
        ? bladeBase
        : Color.lerp(bladeBase, accent, _bodyTint)!;
    canvas.drawPath(blades, Paint()..color = metal.withValues(alpha: 0.88));

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
    final lightDx = math.cos(lightAngle);
    final lightDy = math.sin(lightAngle);
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
      // Işık yalnızca **eklemiyor**: karşı yaprak gölgeye giriyor.
      //
      // Eskiden her yaprak yalnız beyaz alıyordu (0.025–0.10 alfa) ve hiçbiri
      // gölgede değildi. Metali metal yapan şey rengi değil **değer aralığı**;
      // o aralık bu kadar dar olunca nesne, ne kadar doğru çizilirse çizilsin
      // düz bir disk gibi okunuyordu.
      //
      // Üs, parlamayı dar tutuyor: geniş ve doğrusal bir rampa metalden çok
      // plastik gibi duruyor.
      final lit = (facing - 0.5) * 2;
      canvas.drawRect(
        bounds,
        lit >= 0
            ? (Paint()
                ..color = tint.withValues(
                  alpha: 0.02 + 0.19 * math.pow(lit, 1.6).toDouble(),
                ))
            : (Paint()
                ..color = const Color(
                  0xFF000000,
                ).withValues(alpha: 0.16 * math.pow(-lit, 1.35).toDouble())),
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

    // 5) Namlunun derinliği.
    //
    // Buraya kadarki her şey **tek bir düzlemde** duruyordu: halka, bıçaklar ve
    // delik aynı yüzeydeydi ve nesne kâğıda açılmış bir delik gibi okunuyordu.
    // Oysa gerçek bir diyaframda bıçaklar gövdenin *içinde* döner, delik de bir
    // tüpün ağzıdır.
    //
    // Derinliği kuran iki şey var ve ikisi de ışığa bağlı:
    //
    // **İç duvar gölgesi** — ön yüzün hemen altındaki halka karanlıkta kalır,
    // çünkü üstündeki gövde onu gölgeler. Bıçakların "aşağıda" olduğunu
    // söyleyen şey bu.
    //
    // **Karşı duvarın aydınlanması** — ışık üst soldan girerse tüpün *sağ alt*
    // iç duvarına çarpar. Bir deliği tüp yapan tek işaret budur; olmadığında
    // göz orayı düz siyah bir leke olarak okuyor.
    final wall = outer * 0.085;

    // Gölge **hilal**, halka değil. Işığı engelleyen şey gövdenin duvarı, o
    // yüzden karanlık ışığın geldiği tarafta en derin; karşı tarafta duvar
    // ışığa dönük olduğu için gölge yok denecek kadar az. Her yönde eşit bir
    // halka denendi: nesneyi "içeride" yapmıyor, yalnız bütün bıçakları
    // birden söndürüp az önce kazanılan yaprak ayrımını yiyordu.
    canvas.save();
    canvas.clipPath(blades);
    canvas.drawCircle(
      center,
      outer - wall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wall * 1.7
        ..shader = SweepGradient(
          transform: GradientRotation(lightAngle),
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.62),
            const Color(0xFF000000).withValues(alpha: 0.34),
            const Color(0xFF000000).withValues(alpha: 0.04),
            const Color(0xFF000000).withValues(alpha: 0.34),
            const Color(0xFF000000).withValues(alpha: 0.62),
          ],
          stops: const [0.0, 0.24, 0.5, 0.76, 1.0],
        ).createShader(bounds)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, wall * 0.7),
    );
    canvas.restore();

    // Deliğin içi: kenara doğru koyulaşıyor, karşı duvarda bir yay aydınlanıyor.
    canvas.save();
    canvas.clipPath(hole);
    final holeBounds = hole.getBounds();
    canvas.drawPath(
      hole,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x00000000),
            const Color(0xFF000000).withValues(alpha: 0.55),
          ],
          stops: const [0.35, 1.0],
        ).createShader(holeBounds),
    );
    canvas.drawCircle(
      center -
          Offset(math.cos(lightAngle), math.sin(lightAngle)) * (outer * 0.5),
      outer * 0.42,
      Paint()
        ..color = tint.withValues(alpha: 0.055)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outer * 0.22),
    );
    canvas.restore();

    // 6) Açıklığın keskin ağzı.
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.miter
        ..color = tint.withValues(alpha: 0.46),
    );

    // 7) Namlunun ön yüzü — bıçakların **üstünde** duran gerçek bir bant.
    //
    // Eskiden burada bir puanlık bir çizgi vardı ve gövde sacdan kesilmiş gibi
    // ince duruyordu. Bant, bıçak kenarlarının dış uçlarını da örtüyor: onlar
    // artık gövdenin altına giriyor, kenara kadar uzanıp bitmiyorlar.
    //
    // Halka gövdenin tonuna kısmen katılıyor: tamamen nötr bırakıldığında
    // renkli gövdenin etrafında ona ait olmayan gümüş bir çember duruyordu.
    final glint = accent == null
        ? tint
        : Color.lerp(tint, const Color(0xFFFFFFFF), 0.55)!;
    final rim = Rect.fromCircle(center: center, radius: outer - 0.6);
    // Önce malzeme: eloksal bir namlu bıçaklardan **koyudur**. Bu ayrım
    // olmadan bant, gövdenin üstünde duran bir parça değil yalnızca daha açık
    // bir halka gibi okunuyordu.
    canvas.drawCircle(
      center,
      outer - wall / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wall
        ..color = const Color(0xFF000000).withValues(alpha: 0.30),
    );
    // Sonra ışık: dar ve tek yönlü.
    canvas.drawCircle(
      center,
      outer - wall / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wall
        ..shader = SweepGradient(
          // 0. durak ışığın geldiği yöne düşsün.
          transform: GradientRotation(lightAngle),
          colors: [
            glint.withValues(alpha: 0.46),
            tint.withValues(alpha: 0.10),
            tint.withValues(alpha: 0.0),
            tint.withValues(alpha: 0.07),
            glint.withValues(alpha: 0.46),
          ],
          stops: const [0.0, 0.22, 0.5, 0.80, 1.0],
        ).createShader(bounds),
    );

    // 8) Namlunun tırtılı.
    //
    // Bir objektifin kavrama halkası tornada tırtıllanır; o dişler gövdeyi
    // "gradyanla boyanmış bir bant" olmaktan çıkarıp **işlenmiş bir parça**
    // yapan şey. Yüzeyin kendisi hakkında konuşan tek detay bu.
    //
    // Diş **sayısı** değil **aralığı** sabit: 6.5 puanda bir. Sayıyı sabitlemek
    // küçük çapta dişleri birbirine geçiriyor, büyük çapta seyreltiyordu;
    // aralığı sabitlemek dokunun her boyutta aynı sıklıkta okunmasını sağlıyor
    // ve örtüşmeyi (aliasing) baştan kesiyor.
    //
    // Küçük çapta tümden siliniyor. Başlıktaki 15 puanlık işarette yedi diş,
    // doku değil kirli bir kenar demek; orada dokunun taşıyacağı bilgi yok.
    final knurlFade = ((outer - 17) / 13).clamp(0.0, 1.0);
    if (knurlFade > 0) {
      final knurlRadius = outer - wall / 2;
      final teeth = (2 * math.pi * knurlRadius / 6.5).round();
      final inner = outer - wall * 0.86;
      final top = outer - wall * 0.14;
      final knurl = Paint()
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.butt;

      for (var k = 0; k < teeth; k++) {
        final angle = 2 * math.pi * k / teeth;
        // Diş de aynı ışığa bakıyor: aydınlık yanda parlıyor, karşı yanda
        // kendi gölgesine dönüşüyor. Ayrı bir "doku rengi" verilseydi nesnenin
        // üstüne yapıştırılmış bir desen gibi durur, yüzeyi anlatmazdı.
        final facing = 0.5 + 0.5 * math.cos(angle - lightAngle);
        final unit = Offset(math.cos(angle), math.sin(angle));
        knurl.color = facing >= 0.5
            ? glint.withValues(
                alpha:
                    knurlFade *
                    0.20 *
                    math.pow((facing - 0.5) * 2, 1.4).toDouble(),
              )
            : const Color(0xFF000000).withValues(
                alpha:
                    knurlFade *
                    0.22 *
                    math.pow((0.5 - facing) * 2, 1.2).toDouble(),
              );
        canvas.drawLine(center + unit * inner, center + unit * top, knurl);
      }
    }

    // 8) Ön yüzün iki pahı: dıştaki keskin parlama, içteki tornalanmış lip.
    canvas.drawCircle(
      center,
      outer - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = SweepGradient(
          transform: GradientRotation(lightAngle),
          colors: [
            glint.withValues(alpha: 0.72),
            tint.withValues(alpha: 0.30),
            tint.withValues(alpha: 0.14),
            tint.withValues(alpha: 0.44),
            glint.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.26, 0.52, 0.82, 1.0],
        ).createShader(rim),
    );
    canvas.drawCircle(
      center,
      outer - wall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = SweepGradient(
          // İç lip dışarıdakinin tersinden aydınlanır: ışık namlunun
          // içinde karşı duvara çarpıyor.
          //
          // Tepe **ortada**, dikişte değil. Uçları eşleşmeyen bir sweep, tam
          // döndüğü yerde bir basamak bırakıyor: parlak yay orada aniden
          // kesiliyor ve tornalanmış bir kenar değil, üstüne düşmüş bir çizik
          // gibi okunuyordu. İki uç da aynı sönük değerde olduğu için artık
          // dikiş yok.
          transform: GradientRotation(lightAngle),
          colors: [
            tint.withValues(alpha: 0.05),
            glint.withValues(alpha: 0.40),
            tint.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rim),
    );

    // 9) Ön elemanın camındaki parlama.
    //
    // Kaplamalı bir cam ışığı yumuşak bir leke olarak değil **dar ve keskin bir
    // şerit** olarak verir; bir objektif fotoğrafını objektif yapan işaret de
    // odur. Yumuşak bir hale denendi ve nesneyi yine düzleştiriyordu: hale her
    // yüzeyde aynı görünüyor, şerit yalnız camda.
    //
    // Şerit ışıkla birlikte dönüyor ve gövdenin dışına taşmıyor.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: center, radius: outer - wall * 0.4)),
    );
    canvas.translate(center.dx, center.dy);
    canvas.rotate(lightAngle + math.pi / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -outer * 0.55),
        width: outer * 1.02,
        height: outer * 0.13,
      ),
      Paint()
        ..color = glint.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outer * 0.035),
    );
    canvas.restore();
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
      old.barrel != barrel ||
      old.accent != accent ||
      old.lightAngle != lightAngle;
}

/// Nesnenin zemine düşürdüğü temas gölgesi.
///
/// [Aperture]'ın değil [ApertureButton]'ın parçası: gölgesi olan şey **cisim**.
/// Diyafram başlıktaki 15 puanlık işaret olarak da kullanılıyor ve orada bir
/// işaretin gölgesi olmaz.
///
/// Koyu temada kazanç sınırlı ve bu bilinçli kabul ediliyor: zemin zaten
/// neredeyse siyah, gölgenin gidecek yeri az. Orada nesneyi zeminden ayıran
/// asıl şey gövde halkasının alt yayındaki dönen ışık. Aydınlık temada ise
/// tersi — cismi tuvale oturtan şey bu leke.
///
/// Leke ışığın **tersine** düşüyor. Gezen ışıkla birlikte gölgenin de yer
/// değiştirmesi, ikisini tek bir sahnenin parçası yapan şey; sabit bir gölge
/// hareket eden bir ışığın altında yalan söylerdi.
class _ContactShadow extends CustomPainter {
  const _ContactShadow({
    required this.lightAngle,
    required this.strength,
    required this.pressed,
  });

  final double lightAngle;

  /// Zeminin gölgeyi taşıma kapasitesi; koyu temada düşük.
  final double strength;

  final double pressed;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;

    // Basılıyken cisim zemine yaklaşıyor: leke daralıyor, koyulaşıyor ve
    // kenarı sertleşiyor. Gerçek bir düğmenin altında olan da bu.
    final tighten = lerpDouble(1.0, 0.86, pressed)!;
    final rect = Rect.fromCenter(
      center: Offset(
        size.width / 2 - math.cos(lightAngle) * size.width * 0.055,
        size.height * 0.46 - math.sin(lightAngle) * size.height * 0.05,
      ),
      width: size.width * 0.80 * tighten,
      height: size.height * 0.52 * tighten,
    );

    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(
          0xFF000000,
        ).withValues(alpha: strength * lerpDouble(1.0, 1.3, pressed)!)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.width * 0.085 * lerpDouble(1.0, 0.82, pressed)!,
        ),
    );
  }

  @override
  bool shouldRepaint(_ContactShadow old) =>
      old.lightAngle != lightAngle ||
      old.strength != strength ||
      old.pressed != pressed;
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
    this.accent,
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

  /// Gövdeye karışan ısı. Bkz. [Aperture.accent].
  final Color? accent;

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

  /// Sahnedeki ışığın çok yavaş gidip gelmesi.
  ///
  /// Boştaki deklanşörün "canlı" durması için nesnenin kendisini büyütüp
  /// küçültmek en kolay yol — ve tam olarak her arayüzde görülen o yol.
  /// Nabız atan bir daire bir **arayüz öğesi** gibi okunuyor. Duran bir cismin
  /// üzerinden ışığın geçmesi ise cismi gerçek yapıyor: değişen şey nesne
  /// değil sahne.
  ///
  /// Süre bilerek nefesin üç katından uzun. Fark edilecek kadar hızlı olan her
  /// değer, dikkatini boş ekranda tutacak bir şeye dönüşüyordu; buradaki ışık
  /// ancak bakarken yakalanmalı.
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 13000),
  );

  /// Işığın varsayılan yönden sapabileceği en büyük açı.
  ///
  /// Tam tur döndürmek denendi: nesne dönen bir yükleme göstergesine
  /// benziyordu. Dar bir yay, ışığın kaynağını sabit tutuyor — gezinen şey
  /// sahnedeki nesnenin duruşu, ışığın kendisi değil.
  static const _lightSwing = 0.55;

  bool _lightMoves = false;

  @override
  void initState() {
    super.initState();
    if (widget.breathing) _breath.repeat(reverse: true);
    if (widget.locked) _press.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hareketi azalt açıkken ışık da durur: bu döngünün işi bilgi taşımak
    // değil, nesneye ağırlık vermek.
    final moves = widget.breathing && !MediaQuery.disableAnimationsOf(context);
    if (moves == _lightMoves) return;
    _lightMoves = moves;
    if (moves) {
      _light.repeat(reverse: true);
    } else {
      _light
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void didUpdateWidget(ApertureButton old) {
    super.didUpdateWidget(old);
    if (widget.breathing != old.breathing) {
      widget.breathing ? _breath.repeat(reverse: true) : _breath.stop();
      // Kapanışta ışık ortada bırakılıyor; nesne sahnenin varsayılan
      // aydınlığında donuyor.
      if (!widget.breathing) {
        _light
          ..stop()
          ..value = 0.5;
        _lightMoves = false;
      } else {
        didChangeDependencies();
      }
    }
    if (widget.locked != old.locked) {
      widget.locked ? _press.forward() : _press.reverse();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _breath.dispose();
    _light.dispose();
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
          animation: Listenable.merge([_press, _breath, _light]),
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
            // Basılıyken ışık sahnenin varsayılanına toplanıyor: parmağın
            // altında olan şey mekanizma, ışık değil.
            final drift = Curves.easeInOut.transform(_light.value) * 2 - 1;
            final lightAngle =
                kApertureLightAngle + _lightSwing * drift * (1 - pressed);
            // Zeminin gölgeyi taşıma kapasitesi. Koyu temada tuval zaten
            // neredeyse siyah; oraya koyu bir leke koymanın gidecek çok yeri
            // yok ve zorlanırsa nesnenin altında kirli bir halka duruyor.
            // Aydınlık temada leke asıl işini yapıyor.
            final shadowStrength = context.palette.isDark ? 0.30 : 0.16;

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
                    // Zemine değme. Kutunun **dışına** taşıyor: gölge nesnenin
                    // altında, dokunma alanının içinde değil.
                    Positioned(
                      left: -widget.size * 0.10,
                      right: -widget.size * 0.10,
                      bottom: -widget.size * 0.14,
                      height: widget.size * 0.40,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ContactShadow(
                            lightAngle: lightAngle,
                            strength: shadowStrength,
                            pressed: pressed,
                          ),
                        ),
                      ),
                    ),
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
                      // Namlu vurgudan **etkilenmiyor**: objektifin içine
                      // bakınca karanlık görürsün. Burayı da boyamak, gövde
                      // ile delik arasındaki derinliği siliyordu.
                      barrel: widget.bladeBase ?? OnPhoto.canvas,
                      accent: widget.accent,
                      lightAngle: lightAngle,
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
