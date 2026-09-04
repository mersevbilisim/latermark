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
    this.semanticHint,
    this.semanticValue,
    this.selected,
    this.checked,
    this.minimumTarget,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// Basılı tutma. Kendi titreşimini üretir; kısa dokunuşla karışmaz.
  final VoidCallback? onLongPressed;

  final double scale;
  final VoidCallback? haptic;
  final String? semanticLabel;
  final String? semanticHint;
  final String? semanticValue;

  /// Seçilebilir bağlamlarda öğenin işaretli olup olmadığı. Yalnız görsel bir
  /// halka bırakmak ekran okuyucuda seçimi görünmez kılardı; `null` verildiğinde
  /// öğe seçilebilir sayılmaz.
  final bool? selected;

  /// Onay kutusu davranışı gösteren denetimlerde işaret durumu. `null` ise
  /// öğe işaretlenebilir sayılmaz.
  final bool? checked;

  /// Dokunma alanının alt sınırı. Görünen kutu daha küçük olabilir; kap
  /// büyür, çizim büyümez. Apple'ın ölçüsü 44×44.
  final Size? minimumTarget;

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

  void _activate() {
    widget.haptic?.call();
    widget.onPressed!();
  }

  void _longPress() {
    _setDown(false);
    HapticFeedback.mediumImpact();
    widget.onLongPressed!();
  }

  @override
  Widget build(BuildContext context) {
    // Ad verildiyse düğmenin **adı odur**; içindeki yazı ona eklenmez.
    //
    // Eklenirse aynı söz iki kez okunuyordu: etiket hem `Semantics`'e hem
    // içindeki `Text`'e yazıldığı için VoiceOver "Metin yaz, Metin yaz"
    // diyordu. Ad verilmediğinde ise birleşme **isteniyor**: ayar satırı
    // başlığıyla açıklamasını birlikte okutuyor.
    //
    // `excludeSemantics` altındaki GestureDetector'ın dokunma ve basılı tutma
    // eylemlerini de siliyor. Eylemler bu yüzden düğümün kendisinde de
    // duruyor — yoksa geriye ekran okuyucunun okuduğu ama çalıştıramadığı bir
    // düğme kalırdı.
    final named = widget.semanticLabel != null;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      value: widget.semanticValue,
      selected: widget.selected,
      checked: widget.checked,
      excludeSemantics: named,
      onTap: named && _enabled ? _activate : null,
      onLongPress: named && widget.onLongPressed != null ? _longPress : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: _enabled ? _activate : null,
        onLongPress: widget.onLongPressed == null ? null : _longPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          child: AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.4,
            duration: AppMotion.fast,
            child: widget.minimumTarget == null
                ? widget.child
                : _MinimumTarget(
                    size: widget.minimumTarget!,
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Görünen çocuğu ortalayan, en az [size] kadar yer kaplayan kap.
///
/// `SizedBox` yerine `ConstrainedBox` + `Center`: çocuk zaten büyükse
/// küçültülmüyor, yalnızca küçükse çevresine dokunulabilir boşluk açılıyor.
class _MinimumTarget extends StatelessWidget {
  const _MinimumTarget({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minWidth: size.width, minHeight: size.height),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}
