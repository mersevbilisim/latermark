import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_shape.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/pro_badge.dart';
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
    this.unlocked = false,
    this.reason,
    this.onPurchase,
    this.onRestore,
    this.onClose,
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

  /// Kullanıcı Pro hakkına zaten sahip.
  ///
  /// Bu ekrana Pro biri de düşebiliyor: hak henüz doğrulanmadan kilitli bir
  /// kontrole dokunmak yeter. Ona fiyat ve "Pro'ya geç" düğmesi göstermek,
  /// ödediği şeyi yeniden satmaya çalışmak olurdu.
  final bool unlocked;

  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;
  final VoidCallback? onClose;

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
              // 320 px genişlik, 1.3 yazı ölçeği, en uzun desteklenen çeviri
              // ve iki ayrı 44 px bağlantı satırı birlikte ölçülerek ayrıldı.
              // Son özellik footer'ın hit-test perdesinin altında kalmasın.
              MediaQuery.paddingOf(context).bottom + 400,
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
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
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
              price: price,
              unlocked: unlocked,
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
            Text(
              l10n.paywallLimitTitle(ProLimits.freeNotes),
              style: palette.bodyStrong,
            ),
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
        Expanded(
          child: LifeRule(left: left, fill: tint, height: 3),
        ),
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
      (l10n.paywallFeatureBackup, l10n.paywallFeatureBackupDetail),
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

/// Fiyat gelene kadar duran sessiz blok.
class _PricePlaceholder extends StatelessWidget {
  const _PricePlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 25,
      decoration: ShapeDecoration(
        color: palette.canvasLift,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.all(AppShape.chip),
        ),
      ),
    );
  }
}

/// Eylem ve güven satırı.
///
/// Zeminle aynı renkte, üstten yumuşayan bir perdenin üzerinde durur; liste
/// altından geçerken okunurluk bozulmasın diye. Blur yok — perde bedelsiz.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.price,
    required this.busy,
    required this.unlocked,
    required this.onPurchase,
    required this.onRestore,
  });

  final String? price;
  final bool busy;
  final bool unlocked;
  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final veil = palette.canvasSunk;

    return DecoratedBox(
      key: const Key('paywall-footer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            veil.withValues(alpha: 0),
            veil.withValues(alpha: 0.72),
            veil.withValues(alpha: 0.9),
            veil.withValues(alpha: 0.97),
          ],
          // `canvasSunk`, zeminin biraz daha koyu kâğıdı. Perde fiyat satırına
          // ulaşmadan güçlenir ama hiçbir noktada tam opak olmaz; alttaki akış
          // yalnızca siluet olarak kalırken footer ayrı bir mat panele dönüşmez.
          stops: const [0, 0.08, 0.18, 1],
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
            if (unlocked)
              ProOwnedMark(label: l10n.paywallOwned)
            else ...[
              _PurchaseSummary(price: price),
              const SizedBox(height: 14),
              PrimaryButton(
                label: l10n.paywallCta,
                busy: busy,
                onPressed: onPurchase,
              ),
            ],
            const SizedBox(height: 12),
            // Geri yükleme görünür yerde: cihaz değiştiren kullanıcı için
            // tek çıkış yolu bu ve App Review da bunu arıyor.
            //
            // Yanındaki yasal bağlantılar da App Store'un beklediği şey;
            // satın alma ekranında bulunmaları zorunlu.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // İki yasal bağlantı üst tabanı, restore ise alttaki ortalı
                // noktayı oluşturur. Böylece üç uzun etiket tek satıra
                // sıkışmaz; restore da ayrı bir kullanıcı eylemi olarak okunur.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 2,
                      child: _FooterLink(
                        label: l10n.legalPrivacy,
                        onTap: () =>
                            LegalLinks.open(LegalLinks.privacy(context)),
                      ),
                    ),
                    const _FooterDot(),
                    Flexible(
                      flex: 3,
                      child: _FooterLink(
                        label: l10n.legalTerms,
                        onTap: () => LegalLinks.open(LegalLinks.terms),
                      ),
                    ),
                  ],
                ),
                // Geri yükleme yalnızca satın alma teklif edilirken anlamlı;
                // hakkı olan biri için yapacak bir şeyi yok.
                if (!unlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _FooterLink(
                          label: l10n.paywallRestore,
                          onTap: onRestore,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiyatı satın alma eylemiyle aynı bakış alanında tutan kısa özet.
///
/// Tek ürün olduğu için seçim kartına gerek yok. Mağazanın biçimlendirdiği
/// fiyat ve ürünün tek seferlik olduğu bilgisi, CTA'nın hemen üzerinde tek bir
/// tipografik cümle gibi durur. Paywall'ın güçlü vaadi olan "abonelik yok"
/// metni de taşınırken kaybolmaz; fiyatın altında küçük bir dipnot olarak
/// kalır. Uzun çeviriler [Wrap] ile doğal olarak ikinci satıra geçebilir.
class _PurchaseSummary extends StatelessWidget {
  const _PurchaseSummary({required this.price});

  final String? price;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (price == null)
                _PricePlaceholder(palette: palette)
              else
                Text(
                  price!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.title.copyWith(fontSize: 27, height: 1),
                ),
              Text(
                l10n.paywallOneTime,
                style: palette.label.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            l10n.paywallNoSubscription,
            style: palette.caption.copyWith(color: palette.ember),
          ),
        ],
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
    return Pressable(
      onPressed: onTap,
      scale: 0.96,
      semanticLabel: label,
      // Caption metni tek başına yaklaşık 14 px yüksek. Yalnızca metnin
      // boyutunu hit-test alanı yapmak simülatörde fareyle fark edilmese de
      // fiziksel cihazda parmağın dokunuşu sıkça kaçırmasına yol açıyor.
      // iOS'un yerleşik kontrolleriyle aynı tabanı kullan: görünüm küçük ve
      // sakin kalırken görünmez dokunma yüzeyi en az 44 logical px olsun.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.center,
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // Yasal metni ellipsis ile belirsizleştirme. Yalnız 320 px + 1.3
            // ölçek gibi uç durumda birkaç puan küçülür; 44 px dokunma alanı
            // değişmez ve etiketin tamamı okunur.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: context.palette.caption.copyWith(
                  color: context.palette.inkSoft,
                ),
              ),
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
        style: context.palette.caption.copyWith(
          color: context.palette.inkGhost,
        ),
      ),
    );
  }
}
