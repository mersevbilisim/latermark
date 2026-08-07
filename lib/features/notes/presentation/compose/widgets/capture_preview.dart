import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/glass_surface.dart';
import '../../../../../shared/widgets/icon_orb.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../../../l10n/l10n_context.dart';

/// Yeni çekilen karenin yazma ekranındaki başlığı.
///
/// Klavye açıldıkça [height] küçülür ve fotoğraf ince bir şeride dönüşür —
/// düzen değişmez, yalnızca nefes alır. Böylece kullanıcı yazarken neyi
/// yazdığını görmeye devam eder.
class CapturePreview extends StatelessWidget {
  const CapturePreview({
    super.key,
    required this.file,
    required this.height,
    required this.onDiscard,
    required this.onRetake,
    this.replacementIcon = Icons.refresh_rounded,
    this.replacementLabel,
  });

  final File file;
  final double height;
  final VoidCallback onDiscard;
  final VoidCallback onRetake;
  final IconData replacementIcon;
  final String? replacementLabel;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final decodeWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              // Kamera dosyası 24/48 MP olabilir. Ekranın gösterebildiği
              // çözünürlüğe decode etmek raster belleğini ve ilk kare yükünü
              // ciddi ölçüde azaltır; kaynak dosyaya dokunulmaz.
              cacheWidth: decodeWidth,
              filterQuality: FilterQuality.low,
            ),

            // Üstteki düğmelerin parlak fotoğraflarda da okunması için.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 130,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x8C050506), Color(0x00050506)],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: topPadding + 8,
              left: 20,
              child: IconOrb(
                icon: Icons.close_rounded,
                semanticLabel: context.l10n.actionCancel,
                onPressed: onDiscard,
              ),
            ),
            Positioned(
              top: topPadding + 8,
              right: 20,
              child: Pressable(
                onPressed: onRetake,
                scale: 0.94,
                semanticLabel: replacementLabel ?? context.l10n.composeRetake,
                child: GlassSurface(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  tint: OnPhoto.canvasDeep.withValues(alpha: 0.78),
                  borderColor: OnPhoto.hairlineBright,
                  elevation: 10,
                  padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(replacementIcon, size: 16, color: OnPhoto.ink),
                      const SizedBox(width: 7),
                      Text(
                        replacementLabel ?? context.l10n.composeRetake,
                        style: OnPhotoText.label.copyWith(color: OnPhoto.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
