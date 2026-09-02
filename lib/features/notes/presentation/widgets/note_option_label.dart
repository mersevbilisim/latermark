import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Compose içindeki isteğe bağlı kayıt bilgisinin sol tarafı.
///
/// Kart veya rozet değildir. İnce ikon, kısa kayıt işareti ve iki tipografik
/// seviye; sağdaki gerçek kontrolün ne yaptığını daha dokunmadan anlatır.
class NoteOptionLabel extends StatelessWidget {
  const NoteOptionLabel({
    super.key,
    required this.icon,
    required this.title,
    required this.active,
    this.detail,
    this.busy = false,
  });

  final IconData icon;
  final String title;

  /// Altındaki açıklama satırı. Boş bırakılabilir: bir anahtarın ne yaptığı
  /// adından anlaşılıyorsa, altına bir cümle daha koymak satırı iki kata
  /// çıkarıp hiçbir şey söylemiyor.
  final String? detail;

  final bool active;

  /// Satır bir iş bekliyor mu.
  ///
  /// Gösterge ikonun **yerine** giriyor, yanına değil: yuva zaten 21 puan ve
  /// takas yerleşimi hiç kıpırdatmıyor. Anahtara dokunmuyor, yani bekleme
  /// sürerken kullanıcı vazgeçebiliyor — konum sabitlemesi uzun sürebilir ve
  /// o süre boyunca denetimi kilitlemek kullanıcıyı esir alırdı.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.ember : palette.inkFaint;

    final detail = this.detail;

    return Row(
      crossAxisAlignment: detail == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // Yalnız ikon. Altındaki kısa dikey çizgi bir "kayıt işareti" olsun
        // diye vardı; satırın kendisi zaten kayıt dilinde konuşuyor ve çizgi
        // hizasız bir çentik gibi duruyordu.
        ExcludeSemantics(
          child: SizedBox(
            width: 21,
            height: 21,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: busy
                  ? Center(
                      key: const ValueKey('busy'),
                      child: SizedBox.square(
                        dimension: 15,
                        // Bekleyen satır kor rengine dönüyor: iş sürerken
                        // sönük durmak, dokunuşun karşılıksız kaldığı
                        // izlenimini veriyordu.
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: palette.ember,
                        ),
                      ),
                    )
                  : Icon(icon, key: ValueKey(icon), size: 18, color: color),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: palette.bodyStrong.copyWith(
                  color: active ? palette.ink : palette.inkSoft,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    detail,
                    key: ValueKey(detail),
                    style: palette.caption.copyWith(
                      color: palette.inkFaint,
                      fontSize: 12.5,
                      height: 1.32,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Label ile mevcut seçim alanını uzun dil ve Dynamic Type'a göre yerleştirir.
class NoteOptionRow extends StatelessWidget {
  const NoteOptionRow({
    super.key,
    required this.label,
    required this.trailing,
    this.wideControl = false,
  });

  final Widget label;
  final Widget trailing;

  /// Kontrol, etiketle yan yana sığmayacak kadar geniş.
  ///
  /// Hatırlatma alanı böyle: sayı ile zaman eki tek başına dar olsa da,
  /// açıklamalı etiketin yanında telefon eninde okunur alan bırakmıyor.
  /// Kontrolün genişliğini ölçüp karar veremiyoruz — satır `IntrinsicHeight`
  /// içinde, `LayoutBuilder` orada geçersiz. O yüzden bunu çağıran söylüyor.
  final bool wideControl;

  /// Geniş kontrolün yan yana durabilmesi için gereken satır genişliği:
  /// Kontrol + 14 px ara + etikete okunur bir 180 px.
  static const _wideControlThreshold = 394.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Compose bu satıra iki yanda 22 px verir. Parent genişliğini öğrenmek
    // için LayoutBuilder kullanmak cazip görünse de satır IntrinsicHeight'lı
    // kaydırma gövdesinin içinde: Flutter LayoutBuilder'dan intrinsic ölçü
    // isteyemez. Aynı kullanılabilir genişliği ekran ölçüsünden çıkarmak hem
    // deterministik hem de o geçersiz ölçüm döngüsünü tamamen kaldırır.
    final availableWidth = media.size.width - 44;
    final textScale = media.textScaler.scale(1);
    // Geniş kontrolde tek ölçüt telefon genişliği değil: etiketin okunur
    // kalması. 200 px'lik bir kontrol, ancak tablet enindeki bir satırda
    // etiketle yan yana durabilir.
    final stacked =
        availableWidth < (wideControl ? _wideControlThreshold : 300) ||
        textScale > 1.25;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 10),
          Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: label),
        const SizedBox(width: 14),
        // Kontrol satırın yarısından fazlasını yiyemez. Row, esnek olmayan
        // çocuğu sınırsız genişlikle ölçüyor; kontrol büyüdükçe etiket
        // sıkışıp kendi içinde taşıyordu. Sınır, kontrolün kendi esnek
        // parçalarını da devreye sokar.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: availableWidth * 0.6),
          child: trailing,
        ),
      ],
    );
  }
}
