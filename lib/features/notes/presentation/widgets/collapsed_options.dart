import 'package:flutter/material.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/aperture.dart';

/// Klavye açıkken anahtarların yerini alan tek satır.
///
/// İki ekran da kullanıyor: yeni kayıt ve not düzenleme. İkisinde de aynı
/// sorun vardı — klavye açıkken anahtarlar ya kırıntı bir pencereye
/// sıkışıyor ya da ekranın tamamen dışında kalıyordu.
///
/// İskelet ana ekrandaki zaman ayracının aynısı: solda söz, ortada saç teli,
/// sağda iris. Uygulamada tek bir "kapalı bölüm" dili var ve kullanıcı onu bir
/// kez öğreniyor.
///
/// Burada bir süre üç ikon durdu — hatırlatma, orijinal, konum — durum
/// göstersinler diye. İkisi de yanlıştı:
///
/// * Ekran `autofocus` ile açılıyor, yani klavye ilk karede yukarıda.
///   Kullanıcı anahtarların etiketli hâlini **hiç görmeden** bu satırla
///   karşılaşıyordu; tanıma değil bilmece oluyordu.
/// * Hatırlatmanın açık olduğunu alt şerit zaten söylüyor: kelime "KAYDET VE
///   HATIRLAT"a dönüyor ve o şerit her zaman klavyenin üstünde. Çan ikonu,
///   hemen altındaki etiketli ve daha güçlü işaretin tekrarıydı.
///
/// Geriye bir kapı kalıyor, kapı gibi de görünüyor.
///
/// Kor rengi **yalnızca iriste**. Söz bir süre kor denendi ve alt şeritteki
/// "KAYDET" ile karıştı — sebebi de rastlantı değil: `ColophonBar` birincil
/// eylemi tam olarak `palette.ember` ile boyuyor (`action.accent`). Aynı renk,
/// aynı `overline` kaydı, aynı büyük harf, üstelik hemen üstünde. Kor bu
/// dilde "birincil eylem" demek ve bu satır birincil eylem değil, ona giden
/// kapı. Ana ekrandaki kapalı ayraç da aynı bölüşmeyi yapıyor: söz mürekkep,
/// iris kor.
class CollapsedOptions extends StatelessWidget {
  const CollapsedOptions({super.key, required this.onExpand});

  /// Klavyeyi indirir; yerini aldığı anahtarlar da böylece geri gelir.
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      expanded: false,
      label: l10n.composeOptionsLabel,
      onTap: onExpand,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const Key('compose-options-collapsed'),
          behavior: HitTestBehavior.opaque,
          onTap: onExpand,
          // Dokunma hedefi Apple'ın 44pt asgarisinde; ölçüldü, satır 30pt'ydi
          // ve simülatörde fark edilmiyordu.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Text(
                  l10n.upper(l10n.composeOptionsLabel),
                  style: palette.overline.copyWith(color: palette.inkSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ColoredBox(
                    color: palette.hairline,
                    child: const SizedBox(height: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 15,
                  child: Aperture(
                    openness: 0.16,
                    twist: -0.38,
                    bladeCount: 7,
                    edgeTint: palette.ember,
                    bladeBase: palette.canvas,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kapı ile anahtarlar arasındaki geçiş.
///
/// İki iş birden yapıyor ve ikisi de gerekli:
///
/// * **Boy ve solma birlikte animasyonlu.** Dokununca anahtarların "pat" diye
///   belirmesi, kararın verildiği anı bir kesme yapıyordu. `AnimatedCrossFade`
///   boyu da soldurmayı da tek eğriyle sürüyor.
/// * **İki taraf da ağaçta kalıyor.** Anahtarlar `StatefulWidget` ve biri
///   izin/denetleyici işi yapıyor; dokunuşta ilk kez kurulsalardı o maliyet
///   geçişin ilk karesine binerdi. Kurulum bedeli sayfa açılışında ödeniyor.
///
/// Ölçüt klavye boşluğu değil **odak**: boşluk animasyonun ancak sonunda
/// sıfırlanıyor, ona bakmak açılmayı klavye tamamen indikten sonra başlatıp
/// iki hareketi arka arkaya diziyordu. Odak dokunuşta anında düşüyor, yani
/// anahtarlar klavye çekilirken açılıyor.
class OptionsFold extends StatelessWidget {
  const OptionsFold({
    super.key,
    required this.collapsed,
    required this.door,
    required this.options,
  });

  final bool collapsed;
  final Widget door;
  final Widget options;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
    duration: AppMotion.medium,
    sizeCurve: AppMotion.ease,
    firstCurve: AppMotion.ease,
    secondCurve: AppMotion.ease,
    alignment: Alignment.topCenter,
    crossFadeState: collapsed
        ? CrossFadeState.showFirst
        : CrossFadeState.showSecond,
    // `AnimatedCrossFade` sönen tarafı ağaçta bırakıyor ve **dokunuşa
    // kapatmıyor**: saydam bir `Opacity` hâlâ vuruş alıyor. Kapatılmazsa
    // görünmeyen anahtar tıklanabilir kalır — kullanıcının göremediği bir
    // şeyi değiştirmesi demek.
    firstChild: IgnorePointer(ignoring: !collapsed, child: door),
    secondChild: IgnorePointer(ignoring: collapsed, child: options),
  );
}
