import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_motion.dart';

/// Kapanıp açılan bir sliver bölümü, boyunu animasyonla veren sarmalayıcı.
///
/// Akordiyon eskiden içeriği ağaca **koyup çıkararak** çalışıyordu: kapalı
/// bölümün kayıtları hiç çizilmiyordu ve bu, uzun bir arşivde asıl kazancın
/// kendisi. Ama açılıp kapanma da o yüzden bir anda oluyordu — perde yoktu,
/// içerik ya vardı ya yoktu.
///
/// Burada o kazanç korunuyor. Dinlenme hâlinde bu sınıf **hiçbir şey
/// yapmıyor**: kapalıyken içerik yine hiç kurulmuyor, açıkken sliver olduğu
/// gibi geçiyor. Yeni kod yalnızca geçişin birkaç yüz milisaniyesinde
/// çalışıyor. Kaydırma yüzeyi uygulamanın en çok kullanılan yeri; oradaki bir
/// geometri hatası, sert açılan bir bölümden çok daha pahalı olurdu.
class CollapsibleSliver extends StatefulWidget {
  const CollapsibleSliver({
    super.key,
    required this.collapsed,
    required this.sliver,
  });

  final bool collapsed;

  /// Bölümün asıl içeriği. Kapalıyken hiç kurulmuyor.
  final Widget sliver;

  @override
  State<CollapsibleSliver> createState() => _CollapsibleSliverState();
}

class _CollapsibleSliverState extends State<CollapsibleSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    value: widget.collapsed ? 0 : 1,
  );

  @override
  void didUpdateWidget(CollapsibleSliver old) {
    super.didUpdateWidget(old);
    if (widget.collapsed == old.collapsed) return;
    // Açılış ve kapanış aynı eğriyi kullanmıyor: açılırken hızlı başlayıp
    // yumuşak duruyor, kapanırken tersi. Tek eğri kullanmak kapanışı
    // isteksiz gösteriyordu.
    _controller.animateTo(
      widget.collapsed ? 0 : 1,
      curve: widget.collapsed ? AppMotion.exit : AppMotion.ease,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Dinlenme hâllerinde ara katman hiç devreye girmiyor.
        if (t == 0) return const SliverToBoxAdapter();
        if (t == 1) return widget.sliver;
        return _CollapseExtent(
          factor: t,
          // Geçiş sırasında dokunuş alınmıyor: yarı görünür bir kartın
          // altındaki kayda basmak kullanıcının kastettiği şey değil.
          sliver: SliverIgnorePointer(sliver: widget.sliver),
        );
      },
    );
  }
}

class _CollapseExtent extends SingleChildRenderObjectWidget {
  const _CollapseExtent({required this.factor, required Widget sliver})
    : super(child: sliver);

  final double factor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCollapseExtent(factor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCollapseExtent renderObject,
  ) => renderObject.factor = factor;
}

/// Çocuğunun boyunu [factor] oranında kısaltıp fazlasını kırpar.
///
/// Çocuk kendi tam boyuyla yerleşmeye devam ediyor; kısalan yalnızca dışarıya
/// bildirilen geometri. Böylece `SliverList` tembelliğini koruyor — geçiş
/// sırasında da yalnızca ekrana giren kayıtlar kuruluyor.
class _RenderCollapseExtent extends RenderProxySliver {
  _RenderCollapseExtent(this._factor);

  double _factor;

  set factor(double value) {
    if (_factor == value) return;
    _factor = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    final childGeometry = child!.geometry!;
    final scrollExtent = childGeometry.scrollExtent * _factor;
    final visible = math.max(0.0, scrollExtent - constraints.scrollOffset);
    final paintExtent = math.min(
      math.min(childGeometry.paintExtent, visible),
      constraints.remainingPaintExtent,
    );

    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      // Boyanan alan, çocuğun gerçekte kapladığı yerden küçük: kırpma şart.
      maxPaintExtent: scrollExtent,
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !geometry!.visible) return;
    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(
        0,
        0,
        constraints.crossAxisExtent,
        geometry!.paintExtent,
      ),
      super.paint,
    );
  }
}
