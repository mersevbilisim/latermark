import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'glass_surface.dart';

/// Kısa, sessiz bildirim. Material'ın varsayılan çubuğu bu dile yabancı
/// durduğu için içeriği cam bir hap ile değiştirilir.
void showToast(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'Eylem etiketi ve geri çağrısı birlikte verilmelidir.',
  );
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
        duration: onAction == null
            ? const Duration(seconds: 3)
            : const Duration(seconds: 6),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: EdgeInsets.zero,
        content: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          tint: palette.canvasLift,
          elevation: 18,
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
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: palette.ember,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
}
