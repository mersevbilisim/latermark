import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import 'pressable.dart';

/// Ekrandaki tek baskın eylem: mürekkep renginde dolu bir hap.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onPressed: busy ? null : onPressed,
      scale: 0.98,
      haptic: HapticFeedback.mediumImpact,
      semanticLabel: label,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.canvas,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: palette.canvas),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: palette.bodyStrong.copyWith(
                      color: palette.canvas,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// İkincil, sessiz eylem: yalnızca ince bir çerçeve.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = tint ?? palette.inkSoft;

    return Pressable(
      onPressed: onPressed,
      scale: 0.98,
      semanticLabel: label,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.hairline),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
            ],
            Text(label, style: palette.bodyStrong.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
