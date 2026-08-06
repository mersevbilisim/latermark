import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'glass_surface.dart';

/// Kısa, sessiz bildirim. Material'ın varsayılan çubuğu bu dile yabancı
/// durduğu için içeriği cam bir hap ile değiştirilir.
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final palette = context.palette;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: EdgeInsets.zero,
        content: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          tint: palette.glassStrong,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 17,
                color: error ? palette.danger : palette.ember,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: palette.label.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
