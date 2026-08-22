import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../l10n/l10n_context.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/purchase_service.dart';
import 'paywall_page.dart';

/// Paywall'u mağaza servisine bağlayan katman.
///
/// [PaywallPage] mağazadan habersiz: fiyatı ve bekleme durumunu dışarıdan
/// alır. Bağlama işi burada toplanıyor, böylece ekranı test etmek için mağaza
/// kurmak gerekmiyor.
Future<void> showPaywall(BuildContext context, {PaywallReason? reason}) async {
  final repository = AppScope.of(context);
  final notes = await repository.watchNotes().first;
  if (!context.mounted) return;

  await Navigator.of(context).push(
    AppRoutes.lift(
      _PaywallHost(
        latestPhoto: notes.isEmpty ? null : repository.imageOf(notes.first),
        noteCount: notes.length,
        reason: reason,
      ),
    ),
  );
}

/// Paywall'un hangi kapıdan açıldığı.
///
/// Ekranın tepesine o kapıya özel bir açıklama koymak için: kullanıcı neden
/// buraya geldiğini bilmeli. Bağlamsız bir satış ekranı reklam gibi okunur.
enum PaywallReason { noteLimit, reminder, widget, customRetention, backup }

class _PaywallHost extends StatefulWidget {
  const _PaywallHost({
    required this.latestPhoto,
    required this.noteCount,
    required this.reason,
  });

  final File? latestPhoto;
  final int noteCount;
  final PaywallReason? reason;

  @override
  State<_PaywallHost> createState() => _PaywallHostState();
}

class _PaywallHostState extends State<_PaywallHost> {
  PurchaseService? _purchases;
  StreamSubscription<void>? _purchasedSub;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final purchases = context.purchases;
    if (purchases == _purchases) return;

    _purchases = purchases;
    _purchasedSub?.cancel();
    // Satın alma tamamlanınca ekran kendiliğinden kapanır: kullanıcı ödedikten
    // sonra hâlâ satış ekranına bakıyor olmamalı.
    _purchasedSub = purchases.onPurchased.listen((_) => _closePaywall());
  }

  void _closePaywall() {
    // Restore hem purchaseStream'den hem de kesin entitlement sorgusundan
    // başarı döndürebilir. Aynı sonucun iki teslimi paywall'ın altındaki
    // sayfayı da pop etmemeli.
    if (!mounted || _closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _restore() async {
    final result = await context.purchases.restore();
    // Kullanıcı StoreKit hesabı istemi açıkken X/back ile çıkmış olabilir.
    // Route ters animasyonda hâlâ mounted olsa da artık sonuç göstermemeli ve
    // ikinci bir pop ile alttaki sayfayı kapatmamalı.
    if (!mounted || _closing) return;

    if (result == true) {
      // Bazı StoreKit sürümleri mevcut hakkı kesin sorguda döndürürken restore
      // purchaseStream'ine yeni bir olay bırakmayabilir. Her iki yolda da aynı
      // kapanış noktasını kullan.
      _closePaywall();
      return;
    }

    showToast(
      context,
      result == false
          ? context.l10n.paywallRestoreNotFound
          : context.l10n.paywallRestoreFailed,
      error: result == null,
    );
  }

  @override
  void dispose() {
    _purchasedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.purchases;

    return ValueListenableBuilder<String?>(
      valueListenable: purchases.price,
      builder: (context, price, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: purchases.busy,
          builder: (context, busy, _) {
            return PopScope<void>(
              onPopInvokedWithResult: (didPop, _) {
                // Sistem geri tuşu ve iOS geri sürüklemesi PaywallPage'deki X
                // callback'inden geçmez; başarılı pop'u yine de hemen işaretle.
                if (didPop) _closing = true;
              },
              child: PaywallPage(
                price: price,
                latestPhoto: widget.latestPhoto,
                noteCount: widget.noteCount,
                reason: widget.reason,
                busy: busy,
                // Hak henüz doğrulanmadan kilitli bir kontrole dokunan Pro
                // kullanıcı da buraya düşebiliyor; ona satış göstermiyoruz.
                unlocked: AppScope.preferences(context).proUnlocked,
                onPurchase: price == null ? null : purchases.buy,
                // Bütün programatik kapanışlar aynı yarış korumasından geçer.
                onClose: _closePaywall,
                // Eşzamanlı satın alma/restore çağrılarını StoreKit'e yığma.
                // Link devre dışı kaldığında Pressable bunu görsel olarak da
                // hemen belli eder; sonuç mesajı aşağıdaki handler'dan gelir.
                onRestore: busy ? null : _restore,
                // Sınıra çarpan kullanıcı ödemeden de devam edebilmeli: bir
                // kare silmek yer açar. Ücretsiz katman süresiz kullanılabilir.
                onFreeUpSpace: widget.reason == PaywallReason.noteLimit
                    ? _closePaywall
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
