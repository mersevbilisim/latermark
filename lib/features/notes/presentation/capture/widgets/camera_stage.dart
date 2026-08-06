import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Canlı önizlemeyi ekranı tamamen kaplayacak biçimde yerleştirir.
///
/// `CameraPreview` kendi en-boy oranını dayatır (dikeyde `1 / aspectRatio`).
/// Bunu aynı orana sahip bir kutuya koyup [BoxFit.cover] ile büyütmek,
/// sensörün oranı ne olursa olsun siyah kenar bırakmadan doldurur.
class CameraStage extends StatelessWidget {
  const CameraStage({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1,
            height: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
