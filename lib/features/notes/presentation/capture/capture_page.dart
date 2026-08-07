import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/icon_orb.dart';
import '../compose/compose_page.dart';
import 'widgets/camera_notice.dart';
import 'widgets/camera_stage.dart';
import 'widgets/capture_bar.dart';
import 'widgets/focus_reticle.dart';
import 'widgets/frame_guides.dart';
import '../../../../l10n/l10n_context.dart';

/// Vizör.
///
/// Kamera donanımının tüm yaşam döngüsü burada toplanır: izin, bağlanma,
/// uygulamanın arka plana alınması, objektif değişimi ve çekim. Alt widget'lar
/// yalnızca çizer.
class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

enum _Status {
  /// Donanım bağlanıyor.
  starting,
  ready,

  /// Kullanıcı kamera iznini vermemiş.
  denied,

  /// Cihazda kamera yok (ör. simülatör).
  absent,
  failed,
}

class _CapturePageState extends State<CapturePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Patlama eğrisi 0'da parlak, 1'de saydamdır. Bu yüzden *bitmiş* değerde
  /// başlar; aksi halde ekran açılır açılmaz bembeyaz olur.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );

  CameraController? _controller;
  List<CameraDescription> _lenses = const [];
  int _lensIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  _Status _status = _Status.starting;
  String _failure = '';

  bool _capturing = false;
  Offset? _focusAt;
  int _focusTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flash.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Arka plana geçerken donanımı bırakmak zorunlu; aksi halde geri
        // dönüşte önizleme donuk kalır.
        _controller = null;
        controller.dispose();
        if (mounted) setState(() => _status = _Status.starting);
      case AppLifecycleState.resumed:
        if (_lenses.isNotEmpty) _bind(_lenses[_lensIndex]);
    }
  }

  Future<void> _boot() async {
    try {
      _lenses = await availableCameras();
    } on CameraException catch (error) {
      _reportFailure(error);
      return;
    }

    if (_lenses.isEmpty) {
      if (mounted) setState(() => _status = _Status.absent);
      return;
    }

    final back = _lenses.indexWhere(
      (lens) => lens.lensDirection == CameraLensDirection.back,
    );
    _lensIndex = back >= 0 ? back : 0;
    await _bind(_lenses[_lensIndex]);
  }

  Future<void> _bind(CameraDescription lens) async {
    // Yeni denetleyiciyi kurmadan önce eskisini bırak: iki açık oturum bazı
    // cihazlarda kamerayı tamamen kilitliyor.
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = CameraController(
      lens,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flashMode);
    } on CameraException catch (error) {
      await controller.dispose();
      _reportFailure(error);
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _status = _Status.ready;
      _capturing = false;
    });
  }

  void _reportFailure(CameraException error) {
    if (!mounted) return;
    setState(() {
      _status = switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => _Status.denied,
        _ => _Status.failed,
      };
      _failure = error.description ?? error.code;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }

    setState(() => _capturing = true);
    _flash.forward(from: 0);

    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      // Vizör yığından çıkar: kaydettikten sonra doğrudan ana ekrana dönülür.
      Navigator.of(
        context,
      ).pushReplacement(AppRoutes.lift(ComposePage(capture: shot)));
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _capturing = false);
      _reportFailure(error);
    }
  }

  Future<void> _flip() async {
    if (_lenses.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() {
      _lensIndex = (_lensIndex + 1) % _lenses.length;
      _status = _Status.starting;
    });
    await _bind(_lenses[_lensIndex]);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };

    HapticFeedback.selectionClick();
    setState(() => _flashMode = next);
    try {
      await controller.setFlashMode(next);
    } on CameraException {
      // Flaşı olmayan objektiflerde sessizce geç.
    }
  }

  Future<void> _focus(Offset local, Size stage) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _focusAt = local;
      _focusTick++;
    });

    final point = Offset(
      (local.dx / stage.width).clamp(0.0, 1.0),
      (local.dy / stage.height).clamp(0.0, 1.0),
    );

    try {
      if (controller.value.focusPointSupported) {
        await controller.setFocusPoint(point);
      }
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(point);
      }
    } on CameraException {
      // Odak noktası desteklenmiyorsa halka yine de görünür; sorun değil.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnPhoto.canvasDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(),

          // Üstteki kapatma düğmesi her durumda erişilebilir kalmalı.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 20,
            child: IconOrb(
              icon: Icons.close_rounded,
              semanticLabel: context.l10n.actionClose,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),

          if (_status == _Status.ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CaptureBar(
                onCapture: _capture,
                onFlip: _flip,
                onCycleFlash: _cycleFlash,
                flashMode: _flashMode,
                busy: _capturing,
                canFlip: _lenses.length > 1,
              ),
            ),

          ShutterFlash(animation: _flash),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return switch (_status) {
      _Status.ready => LayoutBuilder(
        builder: (context, constraints) {
          final stage = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _focus(details.localPosition, stage),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraStage(controller: _controller!),
                const FrameGuides(),
                if (_focusAt case final point?)
                  Positioned(
                    left: point.dx - FocusReticle.size / 2,
                    top: point.dy - FocusReticle.size / 2,
                    child: FocusReticle(key: ValueKey(_focusTick)),
                  ),
              ],
            ),
          );
        },
      ),
      _Status.starting => const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: OnPhoto.inkFaint,
          ),
        ),
      ),
      _Status.denied => CameraNotice(
        icon: Icons.no_photography_outlined,
        title: context.l10n.cameraDeniedTitle,
        message: context.l10n.cameraDeniedBody,
        actionLabel: context.l10n.actionGoBack,
        onAction: () => Navigator.of(context).maybePop(),
      ),
      _Status.absent => CameraNotice(
        icon: Icons.videocam_off_outlined,
        title: context.l10n.cameraNotFoundTitle,
        message: context.l10n.cameraNotFoundBody,
        actionLabel: context.l10n.actionGoBack,
        onAction: () => Navigator.of(context).maybePop(),
      ),
      _Status.failed => CameraNotice(
        icon: Icons.error_outline_rounded,
        title: context.l10n.cameraFailedTitle,
        message: _failure.isEmpty ? context.l10n.cameraFailedBody : _failure,
        actionLabel: context.l10n.actionRetry,
        onAction: () {
          setState(() => _status = _Status.starting);
          _boot();
        },
      ),
    };
  }
}
