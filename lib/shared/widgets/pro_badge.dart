import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../l10n/l10n_context.dart';
import 'aperture.dart';

/// Pro kapısının Latermark'a ait işareti.
///
/// Hazır bir kilit ikonu veya kapsül kullanmaz. Uygulamanın deklanşöründen
/// öğrenilmiş, neredeyse kapalı bir diyafram ile küçük `PRO` dizgisini yan yana
/// getirir. Böylece ücretli kapı anlaşılır kalırken başka bir uygulamadan
/// alınmış rozet gibi görünmez.
class ProGateMark extends StatelessWidget {
  const ProGateMark({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      container: true,
      label: context.l10n.proBadge,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox.square(
                dimension: 14,
                child: Aperture(
                  openness: 0.08,
                  twist: 0.18,
                  edgeTint: palette.inkFaint,
                  bladeBase: palette.canvas,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.proBadge,
              style: palette.overline.copyWith(
                color: palette.inkSoft,
                fontSize: 10,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kapının **açık** hâli.
///
/// [ProGateMark] neredeyse kapalı bir diyaframdır: kilitli kapı. Hak alındıktan
/// sonra kullanılacak işaret de bu yüzden yeni bir sembol değil, aynı sembolün
/// zıt durumu — açılmış iris ve vurgu rengi. Kenarlıklı bir "PRO" kapsülü
/// başka bir uygulamadan ödünç alınmış gibi durur; açılan diyafram uygulamanın
/// kendi cümlesini kurar.
///
/// Diyafram göründüğünde bir kez açılır. Döngü yok, parıltı yok: kapı
/// açılıyor, o kadar.
class ProOwnedMark extends StatelessWidget {
  const ProOwnedMark({
    super.key,
    required this.label,
    this.size = 21,
    this.centered = true,
  });

  /// İşaretin yanındaki cümle.
  final String label;

  final double size;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return MergeSemantics(
      child: Row(
        mainAxisSize: centered ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: centered
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: SizedBox.square(
                dimension: size,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.08, end: 1),
                  duration: const Duration(milliseconds: 720),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, _) => Aperture(
                    openness: value,
                    twist: 0.18 * (1 - value),
                    edgeTint: palette.ember,
                    bladeBase: palette.canvas,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              label,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: palette.bodyStrong.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}
