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
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
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
