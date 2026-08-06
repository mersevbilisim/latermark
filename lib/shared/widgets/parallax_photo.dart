import 'package:flutter/widgets.dart';

/// Kaydırma sırasında fotoğrafı çerçevesinin içinde ağır ağır gezdirir.
///
/// Kart ekranda yükselirken kare, kartın kendisinden daha yavaş hareket eder.
/// Etki neredeyse fark edilmeyecek kadar küçüktür ama akışa katı bir listede
/// olmayan bir derinlik verir.
///
/// Çocuğa kartın yüksekliğinden [overscan] oranında daha uzun bir kutu verilir;
/// gezdirilen mesafe tam olarak bu fazlalıktır. Böylece etkinin şiddeti
/// fotoğrafın en-boy oranından bağımsız kalır.
class ParallaxPhoto extends StatelessWidget {
  const ParallaxPhoto({super.key, required this.child, this.overscan = 0.16});

  /// [BoxFit.cover] ile çizilen bir görsel olmalı.
  final Widget child;

  final double overscan;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    // Kaydırılabilir bir ata yoksa (detay ekranı, testler) sade hâline düşer.
    if (scrollable == null) return child;

    return Flow(
      clipBehavior: Clip.none,
      delegate: _ParallaxDelegate(
        scrollable: scrollable,
        itemContext: context,
        overscan: overscan,
      ),
      children: [child],
    );
  }
}

class _ParallaxDelegate extends FlowDelegate {
  _ParallaxDelegate({
    required this.scrollable,
    required this.itemContext,
    required this.overscan,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext itemContext;
  final double overscan;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
      height: constraints.maxHeight * (1 + overscan),
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final viewport = scrollable.context.findRenderObject() as RenderBox?;
    final item = itemContext.findRenderObject() as RenderBox?;

    if (viewport == null || item == null || !item.attached) {
      context.paintChild(0);
      return;
    }

    final offset = item.localToGlobal(
      item.size.centerLeft(Offset.zero),
      ancestor: viewport,
    );
    final extent = scrollable.position.viewportDimension;
    if (extent <= 0) {
      context.paintChild(0);
      return;
    }

    // 1 = kart görüş alanının altında, 0 = üstünde.
    final progress = (offset.dy / extent).clamp(0.0, 1.0);
    final slack = context.size.height * overscan;

    context.paintChild(
      0,
      transform: Matrix4.translationValues(0, -slack * progress, 0),
    );
  }

  @override
  bool shouldRepaint(_ParallaxDelegate old) =>
      old.scrollable != scrollable ||
      old.itemContext != itemContext ||
      old.overscan != overscan;
}
