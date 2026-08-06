import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/aperture.dart';
import '../../../../../shared/widgets/icon_orb.dart';

/// Vizörün altındaki denetim çubuğu: objektif değiştir · deklanşör · flaş.
class CaptureBar extends StatelessWidget {
  const CaptureBar({
    super.key,
    required this.onCapture,
    required this.onFlip,
    required this.onCycleFlash,
    required this.flashMode,
    required this.busy,
    required this.canFlip,
  });

  final VoidCallback onCapture;
  final VoidCallback onFlip;
  final VoidCallback onCycleFlash;
  final FlashMode flashMode;

  /// Çekim sürerken diyafram kapalı kalır ve dokunuşları yok sayar.
  final bool busy;

  final bool canFlip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: MediaQuery.paddingOf(context).bottom + 26,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconOrb(
            icon: Icons.cameraswitch_outlined,
            semanticLabel: 'Objektifi değiştir',
            onPressed: canFlip && !busy ? onFlip : null,
            size: 46,
          ),
          ApertureButton(
            size: 84,
            glow: false,
            locked: busy,
            onPressed: onCapture,
          ),
          IconOrb(
            icon: _flashIcon,
            semanticLabel: 'Flaş: $_flashLabel',
            onPressed: busy ? null : onCycleFlash,
            size: 46,
            active: flashMode != FlashMode.off,
          ),
        ],
      ),
    );
  }

  IconData get _flashIcon => switch (flashMode) {
    FlashMode.off => Icons.flash_off_rounded,
    FlashMode.auto => Icons.flash_auto_rounded,
    _ => Icons.flash_on_rounded,
  };

  String get _flashLabel => switch (flashMode) {
    FlashMode.off => 'kapalı',
    FlashMode.auto => 'otomatik',
    _ => 'açık',
  };
}

/// Deklanşöre basıldığında ekranı bir an dolduran beyaz patlama.
///
/// [animation] 0'dan 1'e sürüldüğünde parlaklık 0.92'den 0'a düşer; yani
/// dinlenme konumu 1'dir. Sürücü denetleyici bu yüzden `value: 1` ile kurulur.
class ShutterFlash extends StatelessWidget {
  const ShutterFlash({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.92, end: 0.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: const ColoredBox(
          color: OnPhoto.flash,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
