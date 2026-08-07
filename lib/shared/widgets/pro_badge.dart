import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_shape.dart';
import '../../l10n/l10n_context.dart';

/// Kor rengi "PRO" işareti.
///
/// Paylaşılan bir widget olması bilinçli: rozet hem Ayarlar'daki Pro kartında
/// hem de hatırlatma alanının kilitli hâlinde görünüyor. İki yerde iki ayrı
/// kopya olsaydı biri değişip diğeri kalırdı ve kullanıcı aynı şeyin iki
/// farklı görüntüsünü görürdü. Rozetin işi bir marka taşımak değil, bir
/// **durumu** göstermek — o yüzden her yerde birebir aynı olmalı.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.emberGlow,
        shape: AppShape.border(
          AppShape.chip,
          side: BorderSide(color: palette.ember, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          context.l10n.proBadge,
          style: palette.caption.copyWith(
            color: palette.ember,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
