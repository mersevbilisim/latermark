import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import 'pressable.dart';

/// Ekrandaki tek baskın eylem: mürekkep renginde dolu bir hap.
class PrimaryButton extends StatefulWidget {
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

  /// İş sürüyor: düğme **anında** tıklanamaz olur, ama spinner hemen
  /// görünmez — bkz. [_spinnerDelay].
  final bool busy;

  /// Spinner'ın görünmesi için işin sürmesi gereken en kısa süre.
  ///
  /// Kaydetme çoğu zaman bundan hızlı bitiyor ve o durumda spinner'ı
  /// göstermek yardım değil, göz kırpması gibi bir titreme olurdu — ekranda
  /// belirip aynı karede kaybolan bir şey, işin uzun sürdüğünü değil arayüzün
  /// tökezlediğini anlatır. Gecikme, geri bildirimi yalnızca gerçekten
  /// beklenen durumlara saklıyor.
  static const _spinnerDelay = Duration(milliseconds: 180);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  Timer? _delay;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _scheduleSpinner();
  }

  @override
  void didUpdateWidget(PrimaryButton old) {
    super.didUpdateWidget(old);
    if (widget.busy == old.busy) return;

    _delay?.cancel();
    if (widget.busy) {
      _scheduleSpinner();
    } else if (_spinning) {
      setState(() => _spinning = false);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _scheduleSpinner() {
    _delay = Timer(PrimaryButton._spinnerDelay, () {
      if (mounted) setState(() => _spinning = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = widget.label;
    final icon = widget.icon;
    final busy = _spinning;

    return Pressable(
      // Tıklama koruması spinner'ı beklemiyor: gecikme yalnızca görsel.
      onPressed: widget.busy ? null : widget.onPressed,
      scale: 0.98,
      haptic: HapticFeedback.mediumImpact,
      semanticLabel: label,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(palette.ember, Colors.white, 0.10)!,
              palette.ember,
              Color.lerp(palette.ember, Colors.black, 0.16)!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.ember.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        alignment: Alignment.center,
        // Etiketle spinner arasında geçiş yumuşatılıyor: sert takas, düğmenin
        // içeriğinin yerinden oynadığı izlenimi veriyordu.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: busy
              ? const SizedBox.square(
                  key: ValueKey(true),
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : FittedBox(
                  key: const ValueKey(false),
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        style: palette.bodyStrong.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
          borderRadius: BorderRadius.circular(12),
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
