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
      filterQuality: FilterQuality.medium,
      cacheWidth: decodeWidth == null ? null : (decodeWidth! * ratio).round(),
      errorBuilder: (context, _, _) => const _MissingPhoto(),
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
