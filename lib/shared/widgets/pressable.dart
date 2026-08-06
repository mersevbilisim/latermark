import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';

/// Dokunulduğunda hafifçe içeri çöken sarmalayıcı.
///
/// Material'ın dalga efekti bu tasarım diline yabancı; geri bildirim yerine
/// ölçekten ve titreşimden gelir.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPressed,
    this.scale = 0.97,
    this.haptic = HapticFeedback.selectionClick,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// Basılı tutma. Kendi titreşimini üretir; kısa dokunuşla karışmaz.
  final VoidCallback? onLongPressed;

  final double scale;
  final VoidCallback? haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool value) {
    if (!_enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: _enabled
            ? () {
                widget.haptic?.call();
                widget.onPressed!();
              }
            : null,
        onLongPress: widget.onLongPressed == null
            ? null
            : () {
                _setDown(false);
                HapticFeedback.mediumImpact();
                widget.onLongPressed!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          child: AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.4,
            duration: AppMotion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
