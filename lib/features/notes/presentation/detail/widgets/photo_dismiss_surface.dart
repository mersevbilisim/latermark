import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Fotoğrafı aşağı çekerek detay ekranını kapatan etkileşim yüzeyi.
///
/// Baskının üzerinde yakınlaştırma **yapılmaz**. Küçük bir çerçevenin içinde
/// büyütmek kareyi okunur kılmaz, yalnızca kırpar; üstelik pinch ve pan
/// hareketleri kapatma hareketiyle aynı gesture arena'sında yarışırdı. Burada
/// tek parmakla aşağı çekiş kapatır, dokunuş ise kareyi tam ekrana çıkarır —
/// her hareketin tek ve tartışmasız bir karşılığı olur.
class PhotoDismissSurface extends StatefulWidget {
  const PhotoDismissSurface({
    super.key,
    required this.child,
    required this.onDismissed,
    this.onTap,
    this.onDismissRequested,
    this.onProgressChanged,
    this.cornerRadius = 0,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onDismissed;

  /// Kareye dokunuldu: tam ekran görüntüleyiciyi açar.
  final VoidCallback? onTap;

  final FutureOr<bool> Function()? onDismissRequested;
  final ValueChanged<double>? onProgressChanged;

  /// Baskının dinlenme hâlindeki süperelips köşesi. Aşağı çekildikçe
  /// birkaç puan daha açılır ve fotoğraf yeniden fiziksel nesneye dönüşür.
  final double cornerRadius;

  /// Baskının kenarını zeminden ayıran saç teli. Açık temada beyaz bir karenin
  /// kâğıt zemine akmasını engeller; verilmezse çizilmez.
  final Color? borderColor;

  final String? semanticLabel;

  @override
  State<PhotoDismissSurface> createState() => _PhotoDismissSurfaceState();
}

/// Başparmağa yakın, dar bir tutamaçtan tüm detay rotasını aşağı çekmek için
/// kullanılan gesture kaynağı.
///
/// Bu yüzey bilinçli olarak yalnız kendisine ayrılmış şeritte çalışır. Böylece
/// metin alanının imleç seçimi, hatırlatma alanı ve sayfanın normal kaydırması
/// ile aynı gesture arena'sında yarışmaz. Görsel hareketi sahibi olan sayfa
/// [onOffsetChanged] ile uygular; bu sınıf yalnız fizik ve karar eşiğini tutar.
class PullDownDismissRegion extends StatefulWidget {
  const PullDownDismissRegion({
    super.key,
    required this.child,
    required this.onDismissed,
    this.onDismissRequested,
    this.onOffsetChanged,
    this.onProgressChanged,
  });

  final Widget child;
  final VoidCallback onDismissed;
  final FutureOr<bool> Function()? onDismissRequested;
  final ValueChanged<double>? onOffsetChanged;
  final ValueChanged<double>? onProgressChanged;

  @override
  State<PullDownDismissRegion> createState() => _PullDownDismissRegionState();
}

class _PullDownDismissRegionState extends State<PullDownDismissRegion>
    with SingleTickerProviderStateMixin {
  static const _minimumFlingTravel = 14.0;
  static const _dismissVelocity = 720.0;

  late final AnimationController _settleController;
  double _rawOffset = 0;
  double _visualOffset = 0;
  double _settleFrom = 0;
  double _settleTo = 0;
  double _viewportHeight = 1;
  bool _willDismiss = false;
  bool _preparingDismiss = false;

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
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_preparingDismiss) return;
    _settleController.stop();
    _willDismiss = false;
    _rawOffset = _visualOffset;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_preparingDismiss) return;
    _rawOffset += details.delta.dy;
    final visual = _rawOffset >= 0 ? _rawOffset : -math.sqrt(-_rawOffset) * 2.2;
    _setVisualOffset(visual);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_preparingDismiss) return;

    final velocity = details.primaryVelocity ?? 0;
    // Bu hareket alt kenarda başparmakla yapılıyor; fotoğraf yüzeyindeki
    // geniş galeri çekişinden bilinçli olarak daha kısa bir karar mesafesi.
    final distanceThreshold = math.min(82.0, _viewportHeight * .11);
    final distanceWins = _visualOffset >= distanceThreshold;
    final velocityWins =
        _visualOffset >= _minimumFlingTravel && velocity >= _dismissVelocity;

    if (distanceWins || velocityWins) {
      final request = widget.onDismissRequested;
      if (request == null) {
        _animateDismiss(velocity);
      } else {
        unawaited(_prepareDismiss(request, velocity));
      }
    } else {
      _returnToOrigin();
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
    _settleFrom = _visualOffset;
    _settleTo = _viewportHeight + 48;
    final remaining = math.max(0.0, _settleTo - _settleFrom);
    final velocityDuration = velocity > 0 ? remaining / velocity : 0.24;
    final milliseconds = (velocityDuration * 1000).clamp(170, 260).round();
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
    _settleFrom = _visualOffset;
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
    _setVisualOffset(
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
    _rawOffset = 0;
    _setVisualOffset(0);
  }

  void _setVisualOffset(double value) {
    _visualOffset = value;
    widget.onOffsetChanged?.call(value);
    widget.onProgressChanged?.call(_progressFor(value));
  }

  double _progressFor(double offset) =>
      (math.max(0, offset) / math.max(1, _viewportHeight * .48)).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    _viewportHeight = MediaQuery.sizeOf(context).height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _preparingDismiss ? null : _onDragStart,
      onVerticalDragUpdate: _preparingDismiss ? null : _onDragUpdate,
      onVerticalDragEnd: _preparingDismiss ? null : _onDragEnd,
      onVerticalDragCancel: _preparingDismiss ? null : _returnToOrigin,
      child: widget.child,
    );
  }
}

class _PhotoDismissSurfaceState extends State<PhotoDismissSurface>
    with SingleTickerProviderStateMixin {
  static const _axisSlop = 8.0;
  static const _minimumFlingTravel = 24.0;
  static const _dismissVelocity = 880.0;
  static const _horizontalFollow = 0.86;

  late final AnimationController _settleController;

  Offset _rawOffset = Offset.zero;
  Offset _visualOffset = Offset.zero;
  Offset _settleFrom = Offset.zero;
  Offset _settleTo = Offset.zero;
  Offset? _lastFocalPoint;
  double _viewportHeight = 1;
  bool _dismissCandidate = false;
  bool _axisResolved = false;
  bool _willDismiss = false;
  bool _preparingDismiss = false;
  bool _thresholdHapticPlayed = false;

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
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;

    final canStart = !_preparingDismiss && details.pointerCount == 1;
    _dismissCandidate = canStart;
    _axisResolved = false;

    if (canStart) {
      _settleController.stop();
      _willDismiss = false;
      _thresholdHapticPlayed = false;
      // Kullanıcı geri dönüş yayı tamamlanmadan fotoğrafı yeniden yakalarsa
      // hareket kaldığı yerden devam eder.
      _rawOffset = Offset(
        _visualOffset.dx / _horizontalFollow,
        _visualOffset.dy,
      );
    }
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final previous = _lastFocalPoint;
    _lastFocalPoint = details.focalPoint;
    if (!_dismissCandidate || previous == null) return;

    final zooming =
        details.pointerCount != 1 || (details.scale - 1).abs() > .01;
    if (zooming) {
      _dismissCandidate = false;
      if (_visualOffset != Offset.zero) _returnToOrigin();
      return;
    }

    _rawOffset += details.focalPoint - previous;

    if (!_axisResolved) {
      if (_rawOffset.distance < _axisSlop) return;

      // Dikey niyet belirginleşmeden fotoğrafı oynatmıyoruz. Yatay veya yukarı
      // hareketler yanlışlıkla ekran kapatmaya dönüşmüyor.
      final isDownwardIntent =
          _rawOffset.dy > 0 && _rawOffset.dy.abs() > _rawOffset.dx.abs() * .72;
      if (!isDownwardIntent) {
        _dismissCandidate = false;
        _rawOffset = Offset.zero;
        if (_visualOffset != Offset.zero) _returnToOrigin();
        return;
      }
      _axisResolved = true;
    }

    final vertical = _rawOffset.dy >= 0
        ? _rawOffset.dy
        : -math.sqrt(-_rawOffset.dy) * 2.4;
    _setVisualOffset(Offset(_rawOffset.dx * _horizontalFollow, vertical));
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    if (!_dismissCandidate || !_axisResolved) return;

    _dismissCandidate = false;
    _axisResolved = false;

    final velocity = details.velocity.pixelsPerSecond;
    final distanceThreshold = _distanceThreshold;
    final distanceWins = _visualOffset.dy >= distanceThreshold;
    final velocityWins =
        _visualOffset.dy >= _minimumFlingTravel &&
        velocity.dy >= _dismissVelocity &&
        velocity.dy.abs() > velocity.dx.abs() * .72;

    if (distanceWins || velocityWins) {
      final request = widget.onDismissRequested;
      if (request == null) {
        _animateDismiss(velocity);
      } else {
        unawaited(_prepareDismiss(request, velocity));
      }
    } else {
      _returnToOrigin();
    }
  }

  Future<void> _prepareDismiss(
    FutureOr<bool> Function() request,
    Offset velocity,
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

  void _animateDismiss(Offset velocity) {
    _willDismiss = true;
    final horizontalMomentum = (velocity.dx * .055).clamp(-90.0, 90.0);
    _settleFrom = _visualOffset;
    _settleTo = Offset(
      _visualOffset.dx + horizontalMomentum,
      _viewportHeight + 48,
    );
    _settleController
      ..value = 0
      ..animateTo(
        1,
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
      );
  }

  void _returnToOrigin() {
    _willDismiss = false;
    _settleFrom = _visualOffset;
    _settleTo = Offset.zero;
    _settleController
      ..value = 0
      ..animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 390, damping: 34),
          0,
          1,
          0,
        ),
      );
  }

  void _tickSettle() {
    _setVisualOffset(
      Offset.lerp(_settleFrom, _settleTo, _settleController.value.clamp(0, 1))!,
    );
  }

  void _finishSettle(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_willDismiss) {
      widget.onDismissed();
      return;
    }
    _rawOffset = Offset.zero;
    _setVisualOffset(Offset.zero);
  }

  void _setVisualOffset(Offset value) {
    if (!mounted) return;
    setState(() => _visualOffset = value);
    if (!_thresholdHapticPlayed && value.dy >= _distanceThreshold) {
      _thresholdHapticPlayed = true;
      HapticFeedback.selectionClick();
    }
    widget.onProgressChanged?.call(_progressFor(value.dy));
  }

  /// Fotoğraf oranından bağımsız, aynı cihazda aynı hissedilen karar mesafesi.
  double get _distanceThreshold => math.min(104.0, _viewportHeight * .12);

  double _progressFor(double dy) =>
      (math.max(0, dy) / math.max(1, _viewportHeight * .28)).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sliver içindeki fotoğrafın yüksekliği değil, cihazın görünür
        // yüksekliği kapatma fiziğini belirler. Yatay ve portre baskı aynıdır.
        _viewportHeight = MediaQuery.sizeOf(context).height;
        final progress = _progressFor(_visualOffset.dy);
        final scale = 1 - (progress * .055);
        final tilt = constraints.maxWidth <= 0
            ? 0.0
            : (_visualOffset.dx / constraints.maxWidth).clamp(-0.5, 0.5) * 0.06;
        final radius = widget.cornerRadius + (progress * 8);

        final border = widget.borderColor;

        return Transform.translate(
          offset: _visualOffset,
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Semantics(
                button: widget.onTap != null,
                label: widget.semanticLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          widget.onTap!();
                        },
                  onScaleStart: _onInteractionStart,
                  onScaleUpdate: _onInteractionUpdate,
                  onScaleEnd: _onInteractionEnd,
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.child,
                        if (border != null)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                // Kırpma yolunun tam üstünde durduğu için
                                // çizginin yarısı kesilir: 1 puanlık kalem,
                                // ekranda yarım puanlık saç teli bırakır.
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(radius),
                                  side: BorderSide(color: border, width: 1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
