import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Ekranın başlangıç kenarından yatay çekişle sayfayı geri veren yüzey.
///
/// iOS'ta bir sayfadan çıkmanın öğrenilmiş yolu budur; parmağın ekranın soluna
/// gitmesi "geri" demek. Latermark'ta detay rotası zaten saydam — sayfa sağa
/// kaydıkça altındaki akış gerçekten görünür, üstüne çizilmiş bir taklit değil.
/// Bu yüzden hareketi rota geçişine değil, sayfanın kendi gövdesine
/// bağlıyoruz: kullanıcı sayfayı iterken ana ekranı da geri çekiyor.
///
/// Şerit yalnız **yatay** çekişi sahiplenir. Dokunuşlar altındaki denetimlere
/// geçer (geri düğmesi tam bu bandın içinde duruyor) ve dikey hareketler
/// fotoğrafın aşağı çekme jestine kalır: iki eksen aynı arenada yarışmaz.
class BackSwipeRegion extends StatefulWidget {
  const BackSwipeRegion({
    super.key,
    required this.child,
    required this.onDismissed,
    this.onDismissRequested,
    this.onActiveChanged,
    this.enabled = true,
  });

  final Widget child;

  /// Karar verildi ve sayfa ekrandan çıktı: rotayı çekme zamanı.
  final VoidCallback onDismissed;

  /// Çıkmadan hemen önce sorulur. `false` dönerse sayfa yerine geri yaylanır —
  /// yazma kipindeki kaydetme kararı buradan geçiyor.
  final FutureOr<bool> Function()? onDismissRequested;

  /// Sayfa parmağın altında hareket etmeye başladı / durdu.
  ///
  /// Yalnız eşiği geçerken çağrılır, her karede değil: sahibi bununla Hero
  /// uçuşu gibi konumdan medet uman şeyleri kapatabilsin diye var.
  final ValueChanged<bool>? onActiveChanged;

  final bool enabled;

  /// Şeridin genişliği. iOS'un kenar bandıyla aynı ölçüde: daha genişi
  /// sayfanın kendi içeriğinden çalar, daha darı parmağı ıskalar.
  static const double edgeWidth = 22;

  /// Kararın mesafe eşiği: sayfa genişliğinin dörtte biri.
  ///
  /// Bu üç sayı opak rotaların geri jestiyle **paylaşılıyor** (bkz.
  /// `BackSwipeRoute`). Uygulamada tek bir "geri" hissi var; sayfaya göre
  /// değişen bir kas hafızası öğretmiyoruz.
  static const double commitFraction = 0.25;

  /// Kısa ama kararlı bir fiske de yeter; mesafe eşiğini beklemez.
  static const double flingVelocity = 700;

  /// Fiskenin sayılması için gereken en az yol (ekran genişliğinin oranı
  /// olarak da, puan olarak da aynı eşik kullanılıyor).
  static const double minimumFlingTravel = 16;

  @override
  State<BackSwipeRegion> createState() => _BackSwipeRegionState();
}

class _BackSwipeRegionState extends State<BackSwipeRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController;

  /// Sayfanın geri yönünde kat ettiği yol. Negatifi (ileri çekiş) yay gibi
  /// direnir; sayfa asla ters yöne kaymaz.
  final ValueNotifier<double> _travel = ValueNotifier(0);

  double _rawTravel = 0;
  double _settleFrom = 0;
  double _settleTo = 0;
  double _viewportWidth = 1;
  bool _willDismiss = false;
  bool _preparingDismiss = false;
  bool _active = false;

  /// Geri yönün işareti: soldan sağa dillerde sayfa sağa gider.
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(vsync: this)
      ..addListener(_tickSettle)
      ..addStatusListener(_finishSettle);
  }

  @override
  void dispose() {
    _settleController
      ..removeListener(_tickSettle)
      ..removeStatusListener(_finishSettle)
      ..dispose();
    _travel.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_preparingDismiss) return;
    _settleController.stop();
    _willDismiss = false;
    _rawTravel = _travel.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_preparingDismiss) return;
    _rawTravel += (details.primaryDelta ?? 0) * _direction;
    _setTravel(_rawTravel >= 0 ? _rawTravel : -math.sqrt(-_rawTravel) * 2.2);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_preparingDismiss) return;

    final velocity = (details.primaryVelocity ?? 0) * _direction;
    final travel = _travel.value;
    final distanceWins =
        travel >= _viewportWidth * BackSwipeRegion.commitFraction;
    final velocityWins =
        travel >= BackSwipeRegion.minimumFlingTravel &&
        velocity >= BackSwipeRegion.flingVelocity;

    if (!distanceWins && !velocityWins) {
      _returnToOrigin();
      return;
    }

    final request = widget.onDismissRequested;
    if (request == null) {
      _animateDismiss(velocity);
    } else {
      unawaited(_prepareDismiss(request, velocity));
    }
  }

  Future<void> _prepareDismiss(
    FutureOr<bool> Function() request,
    double velocity,
  ) async {
    _preparingDismiss = true;
    var allowed = false;
    try {
      allowed = await request();
    } catch (_) {
      allowed = false;
    }

    if (!mounted) return;
    _preparingDismiss = false;
    if (allowed) {
      _animateDismiss(velocity);
    } else {
      _returnToOrigin();
    }
  }

  void _animateDismiss(double velocity) {
    _willDismiss = true;
    _settleFrom = _travel.value;
    _settleTo = _viewportWidth;
    final remaining = math.max(0.0, _settleTo - _settleFrom);
    final velocityDuration = velocity > 0 ? remaining / velocity : 0.24;
    final milliseconds = (velocityDuration * 1000).clamp(150, 260).round();
    _settleController
      ..value = 0
      ..animateTo(
        1,
        duration: Duration(milliseconds: milliseconds),
        curve: Curves.easeOutCubic,
      );
  }

  void _returnToOrigin() {
    _willDismiss = false;
    _settleFrom = _travel.value;
    _settleTo = 0;
    _settleController
      ..value = 0
      ..animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 420, damping: 36),
          0,
          1,
          0,
        ),
      );
  }

  void _tickSettle() {
    _setTravel(
      _settleFrom +
          ((_settleTo - _settleFrom) * _settleController.value.clamp(0, 1)),
    );
  }

  void _finishSettle(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_willDismiss) {
      widget.onDismissed();
      return;
    }
    _rawTravel = 0;
    _setTravel(0);
  }

  void _setTravel(double value) {
    _travel.value = value;
    final active = value.abs() > 0.5;
    if (active == _active) return;
    _active = active;
    widget.onActiveChanged?.call(active);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _viewportWidth = math.max(1, media.size.width);
    _direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;

    // Ağacın biçimi hareketten bağımsız: `Transform` duruyorken de yerinde
    // kalıyor. Koşullu sarmalamak, sayfanın altındaki elemanın yuvasını
    // değiştirip bütün gövdeyi söküp yeniden kuruyordu — not akışı yeniden
    // abone oluyor ve sayfa parmağın ilk hareketinde bir kare boşalıyordu.
    final listening = widget.enabled && !_preparingDismiss;

    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: _travel,
            child: widget.child,
            builder: (context, travel, child) => Transform.translate(
              offset: Offset(travel * _direction, 0),
              child: child,
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          width: BackSwipeRegion.edgeWidth + media.padding.left,
          child: GestureDetector(
            // Yarı geçirgen: yalnız yatay çekiş sahipleniliyor, dokunuş
            // altındaki geri düğmesine düşüyor.
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            onHorizontalDragStart: listening ? _onDragStart : null,
            onHorizontalDragUpdate: listening ? _onDragUpdate : null,
            onHorizontalDragEnd: listening ? _onDragEnd : null,
            onHorizontalDragCancel: listening ? _returnToOrigin : null,
          ),
        ),
      ],
    );
  }
}
