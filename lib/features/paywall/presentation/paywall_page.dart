import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_shape.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/life_rule.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../notes/presentation/home/widgets/note_photo.dart';
import '../domain/pro_limits.dart';
import 'paywall_host.dart' show PaywallReason;
import '../../../core/utils/legal_links.dart';

/// Pro satın alma ekranı.
///
/// Ürün **tek seferlik** (non-consumable): abonelik, yenileme ve deneme süresi
/// yok. Bu yalnızca teknik bir ayrıntı değil, ekranın en güçlü argümanı —
/// "abonelik yok" bugün başlı başına bir özellik ve uygulamanın kişiliğiyle de
/// örtüşüyor: her ay kendini hatırlatan bir ürün, unutmayı vaat eden bir
/// uygulamaya yakışmazdı.
///
/// İkna aracı olarak uygulamanın **kendi görsel dilbilgisi** kullanılıyor.
/// Akıştaki her süreli kaydın altında tükenen bir ömür çizgisi var; burada aynı
/// çizgi iki kez çiziliyor — biri tükenmiş, biri dolu. Kullanıcı bu işareti
/// zaten öğrendiği için teklif tek bakışta anlaşılıyor.
///
/// Bilinçli olarak **yapılmayanlar**: geri sayım sayacı, "son 3 saat" uyarısı,
/// kapatma düğmesini geciktirmek. Baskı taktikleri hem bu sakin dille çelişir
/// hem de iade oranını yükseltir.
///
/// Satın alma çağrısı burada yok: [onPurchase] dışarıdan verilir.
class PaywallPage extends StatelessWidget {
  const PaywallPage({
    super.key,
    required this.price,
    this.latestPhoto,
    this.noteCount = 0,
    this.freeLimit = 30,
    this.busy = false,
    this.reason,
    this.onPurchase,
    this.onRestore,
    this.onFreeUpSpace,
  });

  /// Mağazadan gelen biçimlendirilmiş fiyat (ör. `$14.99`, `14,99 €`).
  ///
  /// Para birimini kendimiz biçimlendirmiyoruz: mağaza kullanıcının ülkesine
  /// göre hazır metin veriyor, bölgesel tutarlar birebir çevrilmiş de olmuyor.
  ///
  /// `null` ise mağaza cevabı henüz gelmedi; fiyat yerine bir yer tutucu
  /// çizilir ve satın alma düğmesi kapalı kalır. Sabit bir fiyat yazıp sonra
  /// değiştirmek, kullanıcıya bir an yanlış tutar göstermek olurdu.
  final String? price;

  /// Kullanıcının en son karesi. Ekranın tepesinde durur.
  ///
  /// Stok görsel yerine kişinin kendi fotoğrafı: teklif soyut bir özellik
  /// listesi değil, elindekinin devamı olarak okunuyor.
  final File? latestPhoto;

  final int noteCount;
  final int freeLimit;

  /// Hangi kapıdan gelindiği. Verilirse tepede o kapıya özel açıklama çıkar.
  final PaywallReason? reason;

  /// Mağaza akışı sürerken düğme bekleme durumuna geçer.
  final bool busy;

  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;

  /// Sınıra çarpıldığında sunulan ödemesiz çıkış: bir kare silip devam et.
  final VoidCallback? onFreeUpSpace;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              22,
              0,
              22,
              MediaQuery.paddingOf(context).bottom + 180,
            ),
            children: [
              SizedBox(height: topInset + 62),

              if (latestPhoto != null) ...[
                ClipRSuperellipse(
                  borderRadius: AppShape.all(AppShape.print),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: NotePhoto(
                      file: latestPhoto!,
                      decodeWidth: MediaQuery.sizeOf(context).width - 44,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],

              if (reason == PaywallReason.noteLimit) ...[
                _LimitNotice(onFreeUpSpace: onFreeUpSpace),
                const SizedBox(height: 24),
              ],

              Text(
                l10n.paywallHeadline,
                style: palette.display.copyWith(height: 1.1),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.paywallSubtitle,
                style: palette.body.copyWith(
                  color: palette.inkSoft,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 28),
              const _LifeComparison(),

              const SizedBox(height: 28),
              _Features(freeLimit: freeLimit),

              if (noteCount > 0) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.paywallOwnedCount(noteCount),
                  style: palette.caption.copyWith(color: palette.inkFaint),
                ),
              ],

              const SizedBox(height: 26),
              _PriceBlock(price: price),
            ],
          ),

          // Kapatma sabit durduğu için içerik altından geçiyor; okunurluğu
          // koruyan perde alttakiyle aynı — gradyan, blur değil.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.canvas,
                      palette.canvas,
                      palette.canvas.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: SizedBox(height: topInset + 62, width: double.infinity),
              ),
            ),
          ),
          Positioned(
            top: topInset + 2,
            left: 0,
            child: Pressable(
              onPressed: () => Navigator.of(context).maybePop(),
              scale: 0.9,
              semanticLabel: l10n.paywallClose,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: palette.inkSoft,
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Footer(
              busy: busy,
              onPurchase: onPurchase,
              onRestore: onRestore,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sınıra çarparak gelen kullanıcıya durumu ve **ödemesiz çıkışı** anlatır.
///
/// Çıkışı gizlemek dönüşümü yükseltmez, güveni düşürür: kullanıcı sıkıştığını
/// hisseder. Silerek devam edebileceğini görmek, satın almayı bir mecburiyet
/// değil tercih hâline getiriyor.
class _LimitNotice extends StatelessWidget {
  const _LimitNotice({required this.onFreeUpSpace});

  final VoidCallback? onFreeUpSpace;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.canvasLift,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.all(AppShape.control),
          side: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.paywallLimitTitle, style: palette.bodyStrong),
            const SizedBox(height: 5),
            Text(
              l10n.paywallLimitBody(ProLimits.freeNotes),
              style: palette.caption.copyWith(
                color: palette.inkSoft,
                height: 1.4,
              ),
            ),
            if (onFreeUpSpace != null) ...[
              const SizedBox(height: 11),
              Pressable(
                onPressed: onFreeUpSpace,
                scale: 0.97,
                semanticLabel: l10n.paywallLimitDelete,
                child: Text(
                  l10n.paywallLimitDelete,
                  style: palette.label.copyWith(color: palette.ember),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Teklifi tek bakışta anlatan karşılaştırma.
///
/// Akıştaki ömür çizgisinin aynısı: üstte tükenmiş, altta dolu. Metin
/// okumadan da anlaşılıyor, çünkü kullanıcı bu işareti kartlarda öğrendi.
class _LifeComparison extends StatelessWidget {
  const _LifeComparison();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(context, context.l10n.paywallLifeFree, 0.18, palette.inkFaint),
        const SizedBox(height: 14),
        _row(context, context.l10n.paywallLifePro, 1, palette.ember),
      ],
    );
  }

  Widget _row(BuildContext context, String label, double left, Color tint) {
    final palette = context.palette;

    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label, style: palette.caption.copyWith(color: tint)),
        ),
        Expanded(child: LifeRule(left: left, fill: tint, height: 3)),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.freeLimit});

  final int freeLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // "Abonelik yok" ilk sırada: 2026'da bu, özellik listesinin en güçlü
    // maddesi ve rakiplerin çoğundan ayrıldığı yer.
    final items = <(String, String)>[
      (
        l10n.paywallFeatureNoSubscription,
        l10n.paywallFeatureNoSubscriptionDetail,
      ),
      (
        l10n.paywallFeatureUnlimited,
        l10n.paywallFeatureUnlimitedDetail(freeLimit),
      ),
      (
        l10n.paywallFeatureCustomRetention,
        l10n.paywallFeatureCustomRetentionDetail,
      ),
      (l10n.paywallFeatureReminders, l10n.paywallFeatureRemindersDetail),
      (l10n.paywallFeatureWidget, l10n.paywallFeatureWidgetDetail),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, detail) in items)
          _FeatureRow(title: title, detail: detail),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.check_rounded, size: 15, color: palette.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: palette.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: palette.caption.copyWith(
                    color: palette.inkFaint,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fiyat bloğu.
///
/// Tek ürün olduğu için seçim yok; seçim olmayınca da kart, radyo düğmesi ya
/// da vurgulu çerçeveye gerek kalmıyor. Fiyat büyük, altında ne olduğu tek
/// satır. Kıyas ölçütü aylık bir plan değil — abonelik fikrinin kendisi.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.price});

  final String? price;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hairline(),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (price == null)
              _PricePlaceholder(palette: palette)
            else
              Text(
                price!,
                style: palette.display.copyWith(fontSize: 38, height: 1),
              ),
            const SizedBox(width: 10),
            Text(
              l10n.paywallOneTime,
              style: palette.body.copyWith(color: palette.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.paywallNoSubscription,
          style: palette.caption.copyWith(
            color: palette.ember,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Fiyat gelene kadar duran sessiz blok.
class _PricePlaceholder extends StatelessWidget {
  const _PricePlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 34,
      decoration: ShapeDecoration(
        color: palette.canvasLift,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.all(AppShape.chip),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.hairline,
      child: const SizedBox(height: 0.5, width: double.infinity),
    );
  }
}

/// Eylem ve güven satırı.
///
/// Zeminle aynı renkte, üstten yumuşayan bir perdenin üzerinde durur; liste
/// altından geçerken okunurluk bozulmasın diye. Blur yok — perde bedelsiz.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.busy,
    required this.onPurchase,
    required this.onRestore,
  });

  final bool busy;
  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.canvas.withValues(alpha: 0),
            palette.canvas,
            palette.canvas,
          ],
          stops: const [0, 0.32, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          34,
          22,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: l10n.paywallCta,
              busy: busy,
              onPressed: onPurchase,
            ),
            const SizedBox(height: 12),
            // Geri yükleme görünür yerde: cihaz değiştiren kullanıcı için
            // tek çıkış yolu bu ve App Review da bunu arıyor.
            //
            // Yanındaki yasal bağlantılar da App Store'un beklediği şey;
            // satın alma ekranında bulunmaları zorunlu.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FooterLink(label: l10n.paywallRestore, onTap: onRestore),
                const _FooterDot(),
                _FooterLink(
                  label: l10n.legalPrivacy,
                  onTap: () => LegalLinks.open(LegalLinks.privacy(context)),
                ),
                const _FooterDot(),
                _FooterLink(
                  label: l10n.legalTerms,
                  onTap: () => LegalLinks.open(LegalLinks.terms),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Pressable(
        onPressed: onTap,
        scale: 0.96,
        semanticLabel: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.palette.caption.copyWith(
              color: context.palette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  const _FooterDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        '·',
        style: context.palette.caption.copyWith(color: context.palette.inkGhost),
      ),
    );
  }
}
