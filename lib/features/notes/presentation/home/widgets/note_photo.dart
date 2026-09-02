import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';

/// Diskteki kareyi çizen tek yer.
///
/// Çözünürlüğü ekrana göre düşürerek listede onlarca tam boy JPEG'in belleği
/// doldurmasını engeller ve dosya kaybolduğunda çökmek yerine sessiz bir
/// yer tutucu gösterir.
class NotePhoto extends StatelessWidget {
  const NotePhoto({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
    this.decodeWidth,
  });

  final File file;
  final BoxFit fit;

  /// Mantıksal piksel cinsinden hedef genişlik. Boşsa tam çözünürlük okunur
  /// (detay ekranında yakınlaştırma için gerekli).
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return Image.file(
      file,
      fit: fit,
      gaplessPlayback: true,
      // `medium` Impeller'da mipmap üretimini tetikler. Kare zaten hedef
      // boyutuna yakın çözüldüğü için bunun görsel karşılığı yok, bedeli var.
      filterQuality: FilterQuality.low,
      cacheWidth: decodeWidth == null ? null : (decodeWidth! * ratio).round(),
      errorBuilder: (context, _, _) => const _MissingPhoto(),
      // Kare diskten geldiğinde sert bir sıçrayışla değil, kısa bir açılışla
      // yerine oturur. Yalnızca ilk çözülmede çalışır; önbellekten gelen kare
      // anında ve bedelsiz çizilir.
      //
      // Altında **her zaman** bir yüzey duruyor. Eskiden kare çözülene kadar
      // burası saydamdı ve arkadaki tuval görünüyordu: açılışta bütün ızgara
      // bir an karanlık deliklerle doluyordu. Artık bekleyen şey bir boşluk
      // değil, üstüne baskı gelecek boş bir yüzey.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            const _PrintSurface(),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// Kare çözülene kadar duran boş yüzey.
///
/// Shimmer yok: soldan sağa süzülen bir parlaklık bu uygulamanın dili değil,
/// üstelik ızgarada aynı anda sekiz tanesi dönerdi. Yüzey **kıpırdamıyor** —
/// bekleyişi anlatan şey karenin üstüne açılması, altındaki zeminin dans
/// etmesi değil.
///
/// Tuvalin kendi fikri burada da geçerli: üstten aşağı çok hafif açılan bir
/// yüzey, düz bir doldurmadan daha çok "ışık alan bir şey" gibi duruyor.
class _PrintSurface extends StatelessWidget {
  const _PrintSurface();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = palette.canvasSunk;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              base,
              palette.isDark ? Colors.white : Colors.black,
              0.03,
            )!,
            base,
          ],
        ),
      ),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.canvasSunk,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 22,
          color: palette.inkGhost,
        ),
      ),
    );
  }
}
