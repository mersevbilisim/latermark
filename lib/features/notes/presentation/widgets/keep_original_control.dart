import 'package:flutter/material.dart';

import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/ember_switch.dart';
import 'note_option_label.dart';

/// "Gerçek boyutu da koru" anahtarı.
///
/// Uygulamanın sıkıştırması fiş, park yeri ve seri numarası için doğru: uzun
/// kenar 2048'e iniyor, dosya birkaç kat küçülüyor, okunurluk kalıyor. Ama
/// insanlar bazen not niyetiyle değil **anı kalsın** diye kare atıyor; orada
/// kaybedilen çözünürlüğün karşılığı yok.
///
/// **Her zaman kapalı başlar ve tercih hatırlanmaz.** Bilinçli: seçenek açık
/// kaldığında kullanıcı farkında olmadan her karesini iki kez saklamaya başlar
/// ve bunu ancak depolama dolduğunda görür. Karar kare kare veriliyor.
///
/// Anahtar yalnız *ek* saklamayı açıyor. İşlenmiş kare her hâlükârda yazılıyor
/// ve ızgara, arama, ana ekran ile widget'lar onu çiziyor; orijinal yalnızca
/// detay ekranında ve kullanıcının açıkça istediği paylaşımda okunuyor.
class KeepOriginalControl extends StatelessWidget {
  const KeepOriginalControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = NoteOptionLabel(
      icon: Icons.hd_outlined,
      title: l10n.keepOriginalLabel,
      // Açıklama duruyor çünkü bedeli görünmez: kullanıcı yerin iki katına
      // çıktığını ancak söylenirse bilir.
      detail: l10n.keepOriginalDetail,
      active: value,
    );

    return GestureDetector(
      key: const Key('keep-original-row'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: MergeSemantics(
        child: NoteOptionRow(
          label: ExcludeSemantics(child: label),
          trailing: EmberSwitch(
            key: const Key('keep-original-switch'),
            value: value,
            onChanged: onChanged,
            semanticLabel: l10n.keepOriginalLabel,
          ),
        ),
      ),
    );
  }
}
