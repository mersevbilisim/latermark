import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../shared/widgets/back_swipe_region.dart';

/// Kenardan geri çekilebilen **opak** sayfa rotası.
///
/// Detay sayfasındaki [BackSwipeRegion] burada işe yaramaz: o rota saydam
/// olduğu için sayfayı `Transform` ile itmek altındaki akışı gerçekten açığa
/// çıkarıyor. Ayarlar, yedekleme, hatırlatma planı gibi sayfalar ise opak;
/// aynı numarayı yapsak geride siyah bir boşluk kalırdı — Flutter, üstündeki
/// rota opaksa alttakini hiç çizmiyor.
///
/// Bu yüzden hareket sayfaya değil **rotanın kendi denetleyicisine** bağlı.
/// Parmak ilerledikçe `controller.value` düşüyor; değer 1'in altına inince
/// Flutter rotayı "geçiş hâlinde" sayıp altındaki sayfayı yeniden çizmeye
/// başlıyor. iOS'un kendi geri jesti de tam olarak böyle çalışıyor.
class BackSwipeRoute<T> extends PageRoute<T> {
  BackSwipeRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  /// Jest bu rotayı çekebilir mi.
  ///
  /// `popDisposition` sayesinde sayfaların kendi [PopScope] koruması burada da
  /// geçerli: kayıt sürerken yazma ekranı geri verilmiyor, jest de kilitli.
  bool get _gestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    // Sayfa hâlâ geliyor ya da üstüne bir başkası bindi: ortada çekilecek
    // yerleşmiş bir sayfa yok.
    if (animation?.status != AnimationStatus.completed) return false;
    if (secondaryAnimation?.status != AnimationStatus.dismissed) return false;
    if (navigator?.userGestureInProgress ?? true) return false;
    return true;
  }

  bool get _gestureInProgress =>
      (navigator?.userGestureInProgress ?? false) &&
      animation?.status != AnimationStatus.completed;

  _BackSwipeController _startGesture() =>
      _BackSwipeController(navigator: navigator!, controller: controller!);

  /// Jest yokkenki geçişin eğrisi.
  ///
  /// Her karede yenisini kurmak `CurvedAnimation`'ı sızdırır; rota bir tane
  /// tutup kendisiyle birlikte atıyor.
  CurvedAnimation? _eased;

  CurvedAnimation _easedOf(Animation<double> animation) =>
      _eased ??= CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: AppMotion.exit,
      );

  @override
  void dispose() {
    _eased?.dispose();
    super.dispose();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = _BackSwipeDetector(
      enabled: () => _gestureEnabled,
      onStart: _startGesture,
      child: child,
    );

    // Ağacın **biçimi** her iki kipte de aynı: tek bir kaydırma, tek bir
    // soldurma, altında sayfa. Kipe göre sarmalayıcı ekleyip çıkarmak
    // sayfanın yuvasını değiştiriyor ve altındaki bütün gövdeyi söküp
    // yeniden kuruyor — jest tam da parmak ilerlerken sahibini kaybediyor,
    // sayfa yolun ortasında donuyordu. Değişen yalnız değerler.
    final Animation<Offset> offset;
    final Animation<double> opacity;

    if (_gestureInProgress) {
      // Parmağın altındayken sayfa yatay kayıyor: hareketin yönü ile jestin
      // yönü aynı olmalı, yoksa sayfa "geri gitmiyor", soluyor gibi okunur.
      // Jest bitip yay tamamlanana kadar bu kip sürüyor.
      offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(animation);
      opacity = const AlwaysStoppedAnimation<double>(1);
    } else {
      // Jest yokken sayfa bugünkü gibi geliyor: panel alttan yükseliyor.
      final eased = _easedOf(animation);
      opacity = eased;
      offset = MediaQuery.disableAnimationsOf(context)
          ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
          : Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(eased);
    }

    return SlideTransition(
      position: offset,
      child: FadeTransition(opacity: opacity, child: page),
    );
  }
}

/// Jest süresince rotanın denetleyicisini süren tutamak.
class _BackSwipeController {
  _BackSwipeController({required this.navigator, required this.controller}) {
    // Navigator'a "şu an parmak bu rotayı sürüyor" demek şart: yığın bu
    // sırada kendi kendine bir geçiş başlatmıyor.
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  void dragUpdate(double fraction) {
    controller.value -= fraction;
  }

  void dragEnd(double velocity) {
    // Eşikler detay sayfasındakiyle birebir aynı: uygulamada tek bir "geri"
    // hissi var, sayfaya göre değişen bir kas hafızası yok.
    final travelled = 1 - controller.value;
    final bool keepPage;
    if (velocity.abs() >= BackSwipeRegion.flingVelocity &&
        travelled >= BackSwipeRegion.minimumFlingTravel) {
      keepPage = velocity <= 0;
    } else {
      keepPage = travelled < BackSwipeRegion.commitFraction;
    }

    if (keepPage) {
      // Kalan yol kadar süre: yarıya gelmiş bir sayfa baştan gelirmiş gibi
      // uzun sürmüyor.
      final remaining = lerpDouble(
        AppMotion.medium.inMilliseconds,
        0,
        controller.value,
      )!;
      controller.animateTo(
        1,
        duration: Duration(milliseconds: math.min(remaining.floor(), 300)),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    } else {
      // `pop` rotayı geri sarmaya başlatıyor; süreyi kalan yola göre burada
      // devralıyoruz.
      navigator.pop();
      if (controller.isAnimating) {
        final remaining = lerpDouble(
          0,
          AppMotion.medium.inMilliseconds,
          controller.value,
        )!;
        controller.animateBack(
          0,
          duration: Duration(milliseconds: math.min(remaining.floor(), 300)),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
    }

    if (controller.isAnimating) {
      // Yay bitmeden "jest bitti" dersek geçiş ortada kipe dönüp sayfayı
      // zıplatır. Bitişi denetleyicinin kendisinden bekliyoruz.
      late final AnimationStatusListener listener;
      listener = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }

  /// Jest sahibini kaybetti (şerit ağaçtan düştü).
  ///
  /// Burada `didStopUserGesture` çağrılmazsa Navigator "hâlâ bir parmak var"
  /// sanır ve **bütün gezinme kilitlenir**. Sayfa da yerine dönmeli.
  void cancel() {
    // Kilidi açmak **önce** geliyor ve koşulsuz: burası atlanırsa Navigator
    // "hâlâ bir parmak var" sanır ve bütün gezinme durur. Sayfayı yerine
    // getirmek ikincil — rota zaten kapanıyorsa geri getirilecek bir şey de
    // yok ve denetleyicisi atılmış olabilir.
    navigator.didStopUserGesture();
    if (!navigator.mounted) return;
    try {
      controller.animateTo(1, duration: AppMotion.fast, curve: AppMotion.ease);
    } on Object {
      // Rota kapanırken denetleyici atılmış olabilir; geri getirilecek sayfa
      // kalmadığı için sessizce geçiyoruz.
    }
  }
}

/// Sayfanın başlangıç kenarındaki jest şeridi.
///
/// Ölçüsü ve davranışı [BackSwipeRegion] ile aynı: yalnız yatay çekişi
/// sahipleniyor, dokunuşlar altındaki geri düğmesine düşüyor.
class _BackSwipeDetector extends StatefulWidget {
  const _BackSwipeDetector({
    required this.child,
    required this.enabled,
    required this.onStart,
  });

  final Widget child;
  final ValueGetter<bool> enabled;
  final ValueGetter<_BackSwipeController> onStart;

  @override
  State<_BackSwipeDetector> createState() => _BackSwipeDetectorState();
}

class _BackSwipeDetectorState extends State<_BackSwipeDetector> {
  _BackSwipeController? _gesture;
  double _width = 1;
  double _direction = 1;

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled()) return;
    _gesture = widget.onStart();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _gesture?.dragUpdate(((details.primaryDelta ?? 0) * _direction) / _width);
  }

  void _onDragEnd(DragEndDetails details) {
    _gesture?.dragEnd((details.primaryVelocity ?? 0) * _direction / _width);
    _gesture = null;
  }

  void _onDragCancel() {
    _gesture?.dragEnd(0);
    _gesture = null;
  }

  @override
  void dispose() {
    // Ağaçtan düşerken elde kalan jest Navigator'ı kilitli bırakırdı.
    _gesture?.cancel();
    _gesture = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _width = math.max(1, media.size.width);
    _direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          width: BackSwipeRegion.edgeWidth + media.padding.left,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _onDragCancel,
          ),
        ),
      ],
    );
  }
}
