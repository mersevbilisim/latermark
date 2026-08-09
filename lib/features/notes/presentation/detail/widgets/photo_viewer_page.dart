import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../home/widgets/note_photo.dart';

/// Baskıyı tam ekrana çıkarır: yakınlaştırma, kaydırma, aşağı bırakma.
///
/// Detaydaki baskı üzerinde de yakınlaştırma yapılabilirdi; yapılmıyor. Küçük
/// bir çerçevenin içinde büyütmek fotoğrafı okumaz, yalnızca kırpar. Kare
/// büyütülecekse önce **tüm ekranı** hak eder; o yüzden dokunuş burayı açar ve
/// detaydaki hareket yalnızca kapatmaya ayrılmış kalır.
Future<void> showPhotoViewer(
  BuildContext context, {
  required File photo,
  required Object heroTag,
  required DateTime createdAt,
  DateTime? updatedAt,
  double? aspect,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      // Rota opak değil: kare aşağı bırakılırken altındaki detay sayfası
      // gerçek zamanlı olarak geri görünür.
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, animation, _) => _PhotoViewer(
        photo: photo,
        heroTag: heroTag,
        createdAt: createdAt,
        updatedAt: updatedAt,
        aspect: aspect,
        entrance: animation,
      ),
      // Sahnenin kendi parçaları (perde, künye, kare) animasyonu ayrı ayrı
      // okur; tek bir dış geçiş hepsini aynı anda soldururdu.
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photo,
    required this.heroTag,
    required this.createdAt,
    required this.updatedAt,
    required this.aspect,
    required this.entrance,
  });

  final File photo;
  final Object heroTag;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Karenin gerçek en-boy oranı. Bilindiğinde Hero uçuşu, baskının tam
  /// dikdörtgeninden tam ekran dikdörtgenine düz bir ölçek olur; bilinmezse
  /// kare ekranı doldurur ve uçuş yine kabul edilebilir kalır.
  final double? aspect;

  final Animation<double> entrance;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer>
    with TickerProviderStateMixin {
  static const _axisSlop = 8.0;
  static const _minimumFlingTravel = 20.0;
  static const _dismissVelocity = 820.0;
  static const _zoomTolerance = 1.012;
  static const _doubleTapScale = 2.6;

  late final TransformationController _transform;
  late final AnimationController _zoom;
  late final AnimationController _settle;
  Animation<Matrix4>? _zoomFlight;

  Size _viewport = const Size(1, 1);
  Offset _rawDrag = Offset.zero;
  Offset _drag = Offset.zero;
  Offset _settleFrom = Offset.zero;
  Offset? _lastFocalPoint;
  Offset? _doubleTapAt;

  bool _dragCandidate = false;
  bool _axisResolved = false;
  bool _thresholdHapticPlayed = false;
  bool _leaving = false;
  bool _chrome = true;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _transform = TransformationController()..addListener(_onTransformChanged);
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_tickZoom);
    _settle = AnimationController(vsync: this)..addListener(_tickSettle);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransformChanged)
      ..dispose();
    _zoom
      ..removeListener(_tickZoom)
      ..dispose();
    _settle
      ..removeListener(_tickSettle)
      ..dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transform.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() < .0005) return;
    setState(() => _scale = scale);
  }

  bool get _zoomed => _scale > _zoomTolerance;

  double get _dismissThreshold => math.min(132.0, _viewport.height * .15);

  double _progressFor(double dy) =>
      (math.max(0, dy) / math.max(1, _viewport.height * .32)).clamp(0, 1);

  double get _progress => _progressFor(_drag.dy);

  // ---------------------------------------------------------------- gestures

  void _toggleChrome() {
    if (_leaving) return;
    HapticFeedback.selectionClick();
    setState(() => _chrome = !_chrome);
  }

  void _handleDoubleTap() {
    if (_leaving) return;
    HapticFeedback.selectionClick();

    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      final at = _doubleTapAt ?? _viewport.center(Offset.zero);
      const zoom = _doubleTapScale;
      // Dokunulan nokta yerinde kalır, kare onun etrafında büyür.
      target = Matrix4.identity()
        ..translateByDouble(-at.dx * (zoom - 1), -at.dy * (zoom - 1), 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
    }

    _zoomFlight = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoom, curve: Curves.easeOutQuint));
    _zoom
      ..value = 0
      ..forward();
  }

  void _tickZoom() {
    final flight = _zoomFlight;
    if (flight != null) _transform.value = flight.value;
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    _zoom.stop();

    // Kare büyütülmüşken parmak kaydırma içindir; kapatma yalnızca dinlenme
    // ölçeğinde, tek parmakla ve aşağı yönde uyanır.
    final canStart = !_leaving && details.pointerCount == 1 && !_zoomed;
    _dragCandidate = canStart;
    _axisResolved = false;

    if (canStart) {
      _settle.stop();
      _thresholdHapticPlayed = false;
      _rawDrag = _drag;
    }
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final previous = _lastFocalPoint;
    _lastFocalPoint = details.focalPoint;
    if (!_dragCandidate || previous == null) return;

    if (details.pointerCount != 1 || (details.scale - 1).abs() > .01) {
      _dragCandidate = false;
      if (_drag != Offset.zero) _returnToOrigin();
      return;
    }

    _rawDrag += details.focalPoint - previous;

    if (!_axisResolved) {
      if (_rawDrag.distance < _axisSlop) return;
      final downward =
          _rawDrag.dy > 0 && _rawDrag.dy.abs() > _rawDrag.dx.abs() * .72;
      if (!downward) {
        _dragCandidate = false;
        _rawDrag = Offset.zero;
        if (_drag != Offset.zero) _returnToOrigin();
        return;
      }
      _axisResolved = true;
      if (_chrome) setState(() => _chrome = false);
    }

    // Yukarı yön lastikli: kare kaçmaz ama parmağın hâlâ bir şeye bağlı
    // olduğunu bildirir.
    final dy = _rawDrag.dy >= 0 ? _rawDrag.dy : -math.sqrt(-_rawDrag.dy) * 2.4;
    _setDrag(Offset(_rawDrag.dx, dy));
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    if (!_dragCandidate || !_axisResolved) return;

    _dragCandidate = false;
    _axisResolved = false;

    final velocity = details.velocity.pixelsPerSecond;
    final committed =
        _drag.dy >= _dismissThreshold ||
        (_drag.dy >= _minimumFlingTravel &&
            velocity.dy >= _dismissVelocity &&
            velocity.dy.abs() > velocity.dx.abs() * .72);

    if (committed) {
      _leave();
    } else {
      _returnToOrigin();
    }
  }

  /// Kare ekrandan kaydırılıp atılmaz: geldiği baskıya geri uçar. Hero uçuşu
  /// parmağın bıraktığı yerden başlar, böylece hareket kesintisiz görünür.
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  void _returnToOrigin() {
    _settleFrom = _drag;
    _settle
      ..value = 0
      ..animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 400, damping: 34),
          0,
          1,
          0,
        ),
      );
  }

  void _tickSettle() {
    final t = _settle.value.clamp(0.0, 1.0);
    _setDrag(Offset.lerp(_settleFrom, Offset.zero, t)!);
    if (t >= 1) {
      _rawDrag = Offset.zero;
      if (!_chrome) setState(() => _chrome = true);
    }
  }

  void _setDrag(Offset value) {
    if (!mounted) return;
    setState(() => _drag = value);
    if (!_thresholdHapticPlayed && value.dy >= _dismissThreshold) {
      _thresholdHapticPlayed = true;
      HapticFeedback.selectionClick();
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    _viewport = MediaQuery.sizeOf(context);
    final progress = _progress;
    final chromeVisible = _chrome && !_zoomed && progress < .01;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Perde. Kare aşağı indikçe açılır ve altındaki detay sayfası
            // yeniden görünür; kapatma bir sayfa değişimi değil, karenin
            // yerine dönmesi gibi okunur.
            FadeTransition(
              opacity: widget.entrance,
              child: ColoredBox(
                color: OnPhoto.canvasDeep.withValues(
                  alpha: 1 - (progress * .92),
                ),
              ),
            ),

            Transform.translate(
              offset: _drag,
              child: Transform.scale(
                scale: 1 - (progress * .24),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleChrome,
                  onDoubleTapDown: (details) =>
                      _doubleTapAt = details.localPosition,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 6,
                    onInteractionStart: _onInteractionStart,
                    onInteractionUpdate: _onInteractionUpdate,
                    onInteractionEnd: _onInteractionEnd,
                    child: SizedBox.expand(child: _stage()),
                  ),
                ),
              ),
            ),

            _ViewerChrome(
              visible: chromeVisible,
              entrance: widget.entrance,
              createdAt: widget.createdAt,
              updatedAt: widget.updatedAt,
              onClose: _leave,
            ),
          ],
        ),
      ),
    );
  }

  /// Hero'nun taşıdığı dikdörtgen tam olarak **karenin kendisi**.
  ///
  /// Tüm ekranı taşısaydı uçuş sırasında kutunun oranı değişir, içindeki
  /// fotoğraf da kutunun içinde ayrıca kayardı. Kutuyu karenin oranına
  /// sabitlemek uçuşu tek ve düz bir ölçek hareketine indirger.
  Widget _stage() {
    final aspect = widget.aspect;

    final photo = Hero(
      tag: widget.heroTag,
      flightShuttleBuilder: _flightShuttle,
      child: NotePhoto(
        file: widget.photo,
        fit: aspect == null ? BoxFit.contain : BoxFit.cover,
      ),
    );

    if (aspect == null) return photo;

    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / aspect;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * aspect;
        }
        return Center(
          child: SizedBox(width: width, height: height, child: photo),
        );
      },
    );
  }

  /// Uçuş boyunca köşe yarıçapı da yol alır: baskı tam ekrana çıkarken
  /// köşelerini bırakır, geri dönerken yeniden kazanır.
  Widget _flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          animation.value.clamp(0.0, 1.0),
        );
        return ClipRSuperellipse(
          borderRadius: BorderRadius.circular(
            lerpDouble(AppShape.print, 0, t)!,
          ),
          child: NotePhoto(
            file: widget.photo,
            fit: widget.aspect == null ? BoxFit.contain : BoxFit.cover,
          ),
        );
      },
    );
  }
}

/// Tam ekranın üstündeki tek satırlık künye ve kapatma.
///
/// Kare zemin değil fotoğraf olduğu için buradaki hiçbir öğe bir kaba
/// oturtulmaz; okunurluğu üstteki ve alttaki çok yumuşak perde ile glifin
/// kendi gölgesi sağlar. Yüzey eklemek, bakılan şeyin önüne arayüz koymaktır.
class _ViewerChrome extends StatelessWidget {
  const _ViewerChrome({
    required this.visible,
    required this.entrance,
    required this.createdAt,
    required this.updatedAt,
    required this.onClose,
  });

  final bool visible;
  final Animation<double> entrance;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);

    return IgnorePointer(
      ignoring: !visible,
      child: FadeTransition(
        opacity: entrance,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(child: _ChromeScrim()),

              Positioned(
                top: safe.top,
                left: 4,
                child: _ViewerAction(
                  icon: Icons.close_rounded,
                  semanticLabel: context.l10n.actionClose,
                  onPressed: onClose,
                ),
              ),

              Positioned(
                left: 20,
                right: 20,
                bottom: safe.bottom + 18,
                child: Center(
                  child: _StampSheet(
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karenin künyesi: eklenme ve — varsa — son güncellenme.
///
/// Tek satırlık gri bir altyazı yerine iki sütunlu bir veri bloğu. Etiketler
/// sağa yaslı küçük kapiteller, değerler sola yaslı tabular rakamlar, aralarında
/// dikey bir saç teli. Sütunlar birbirini hizaladığı için iki satır tek bir
/// künye levhası gibi okunur — fotoğrafın önüne yüzey koymadan.
class _StampSheet extends StatelessWidget {
  const _StampSheet({required this.createdAt, required this.updatedAt});

  final DateTime createdAt;
  final DateTime? updatedAt;

  static const _rowExtent = 17.0;
  static const _shadow = [Shadow(color: Color(0x8C000000), blurRadius: 10)];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edited = updatedAt;

    final labelStyle = AppType.overline.copyWith(
      color: OnPhoto.inkFaint,
      fontSize: 9.5,
      height: 1,
      letterSpacing: 1.5,
      shadows: _shadow,
    );
    final valueStyle = AppType.label.copyWith(
      color: OnPhoto.ink,
      fontSize: 12.5,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: _shadow,
    );

    Widget cell(String text, TextStyle style, Alignment alignment) => SizedBox(
      height: _rowExtent,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );

    // Sütunlar içeriklerine göre daralır; blok bir bütün olarak ortalanır.
    // `Flexible` kullanıldığında sütunlar boş alanı eşit paylaşıyor, ayraç
    // ortada kalsa da kısa etiket ile uzun değer bloğu görsel olarak sağa
    // kaydırıyordu. Uzun çevirilerde taşmamak için blok gerektiğinde küçülür.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                cell(
                  l10n.upper(l10n.addedLabel),
                  labelStyle,
                  Alignment.centerRight,
                ),
                if (edited != null) ...[
                  const SizedBox(height: 7),
                  cell(
                    l10n.upper(l10n.lastUpdatedLabel),
                    labelStyle,
                    Alignment.centerRight,
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 1,
              child: ColoredBox(color: OnPhoto.ink.withValues(alpha: 0.22)),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell(l10n.stamp(createdAt), valueStyle, Alignment.centerLeft),
                if (edited != null) ...[
                  const SizedBox(height: 7),
                  cell(l10n.stamp(edited), valueStyle, Alignment.centerLeft),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Parlak bir karenin üstünde bile glifin okunmasını sağlayan çok hafif ışık
/// düşüşü. Bulanıklık değil, yalnızca gradyan.
class _ChromeScrim extends StatelessWidget {
  const _ChromeScrim();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.paddingOf(context).top + 96,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x59000000), Color(0x00000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: MediaQuery.paddingOf(context).bottom + 88,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x4D000000), Color(0x00000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _ViewerAction extends StatefulWidget {
  const _ViewerAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_ViewerAction> createState() => _ViewerActionState();
}

class _ViewerActionState extends State<_ViewerAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.86 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              widget.icon,
              size: 24,
              color: OnPhoto.ink,
              shadows: const [Shadow(color: Color(0x73000000), blurRadius: 12)],
            ),
          ),
        ),
      ),
    );
  }
}
