import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../shared/widgets/pressable.dart';

/// "Beni kaç gün sonra hatırlat?"
///
/// Sıfır kapalı demek ve varsayılan budur — yani hiçbir şey yapmazsan kayıt
/// sessiz kalır. Hatırlatma istemek bilinçli bir hareket olmalı: uygulamanın
/// sözü "unut", her kaydın peşinden koşması bu sözü bozardı.
///
/// Kontrol tek satır ve tek alan. Buraya ikinci bir süre seçicisi koymak
/// (otomatik silme gibi) iki benzer görünüp zıt iş yapan kontrol üretirdi;
/// saklama süresi bu yüzden Ayarlar'a taşındı.
class ReminderField extends StatefulWidget {
  const ReminderField({
    super.key,
    required this.days,
    required this.onChanged,
    this.blocked = false,
    this.locked = false,
    this.onOpenSystemSettings,
    this.onLockedTap,
  });

  /// Kaç gün sonra hatırlatılacağı. `0` ise hatırlatma yok.
  final int days;

  final ValueChanged<int> onChanged;

  /// Bildirim izni yokken `true`. Kullanıcı süre verse bile bildirim
  /// gönderilemeyeceği için bunu sessizce yutmak yerine söylüyoruz.
  final bool blocked;

  final VoidCallback? onOpenSystemSettings;

  /// Pro'ya özel: ücretsiz katmanda alan görünür ama düzenlenemez.
  ///
  /// Gizlemek yerine göstermek bilinçli. Kullanıcı olmayan bir özelliği
  /// isteyemez; kilitli ama görünür bir alan hem özelliği öğretiyor hem de
  /// satın alma sebebini tam ihtiyaç anında önüne koyuyor.
  final bool locked;

  final VoidCallback? onLockedTap;

  /// Makul bir üst sınır: bundan uzağı için hatırlatma değil, takvim gerekir.
  static const maxDays = 365;

  @override
  State<ReminderField> createState() => _ReminderFieldState();
}

class _ReminderFieldState extends State<ReminderField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.days.toString());
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  /// Alan boş bırakılırsa kapalıya döner; kullanıcı silip çıktığında ekranda
  /// anlamsız bir boşluk kalmasın.
  void _onFocusChange() {
    if (_focus.hasFocus) return;
    if (_controller.text.isEmpty) {
      _controller.text = '0';
      widget.onChanged(0);
    }
  }

  void _submit(String raw) {
    final parsed = int.tryParse(raw) ?? 0;
    final clamped = parsed.clamp(0, ReminderField.maxDays);
    if (clamped.toString() != raw) {
      _controller.text = clamped.toString();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = widget.days > 0;

    if (widget.locked) return _LockedField(onTap: widget.onLockedTap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(palette, active),
        if (active && widget.blocked) ...[
          const SizedBox(height: 10),
          _BlockedNotice(onOpenSystemSettings: widget.onOpenSystemSettings),
        ],
      ],
    );
  }

  Widget _field(AppPalette palette, bool active) {
    return Row(
      children: [
        Text(
          context.l10n.reminderLabel,
          style: palette.label.copyWith(
            color: active ? palette.ink : palette.inkSoft,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 54,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _submit,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            keyboardAppearance: Brightness.dark,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: palette.bodyStrong.copyWith(
              fontSize: 17,
              color: active ? palette.ember : palette.inkFaint,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            cursorColor: palette.ember,
            cursorWidth: 2,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: palette.hairlineBright),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: palette.ember, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          active ? context.l10n.reminderSuffixActive : context.l10n.reminderSuffixOff,
          style: palette.caption.copyWith(color: palette.inkFaint),
        ),
      ],
    );
  }
}

/// Süre verilmiş ama bildirim izni yokken görünen satır.
///
/// Sessizce hiçbir şey yapmamak en kötüsü olurdu: kullanıcı hatırlatma
/// kurduğunu sanıp beklerdi. Kayıt yine de kaydedilir — izin sonradan
/// verildiğinde hatırlatma kendiliğinden devreye girer.
class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({this.onOpenSystemSettings});

  final VoidCallback? onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notifications_off_outlined,
          size: 15,
          color: palette.inkFaint,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.l10n.reminderBlocked,
            style: palette.caption.copyWith(
              color: palette.inkFaint,
              height: 1.35,
            ),
          ),
        ),
        if (onOpenSystemSettings != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpenSystemSettings,
            child: Text(
              context.l10n.actionOpen,
              style: palette.label.copyWith(color: palette.ember),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ücretsiz katmandaki hâli: aynı satır, ama kilitli ve Pro işaretli.
class _LockedField extends StatelessWidget {
  const _LockedField({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onPressed: onTap,
      scale: 0.99,
      semanticLabel: context.l10n.reminderLabel,
      child: Row(
        children: [
          Text(
            context.l10n.reminderLabel,
            style: palette.label.copyWith(color: palette.inkSoft),
          ),
          const Spacer(),
          const _ProBadge(),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.emberGlow,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.all(AppShape.chip),
          side: BorderSide(color: palette.ember, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          context.l10n.proBadge,
          style: palette.caption.copyWith(
            color: palette.ember,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
