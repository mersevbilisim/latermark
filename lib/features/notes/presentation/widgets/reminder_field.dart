import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../../../shared/widgets/pro_badge.dart';
import 'note_option_label.dart';

/// "Beni kaç gün sonra hatırlat?"
///
/// Sıfır kapalı demek ve varsayılan budur — yani hiçbir şey yapmazsan kayıt
/// sessiz kalır. Hatırlatma istemek bilinçli bir hareket olmalı: uygulamanın
/// sözü "unut", her kaydın peşinden koşması bu sözü bozardı.
///
/// Kontrol tek satır ve tek alan. Buraya ikinci bir süre seçicisi koymak
/// (otomatik silme gibi) iki benzer görünüp zıt iş yapan kontrol üretirdi;
/// saklama süresi bu yüzden Ayarlar'a taşındı.
///
/// Tekrar, rakamın yanına sıkıştırılmış anonim bir simge değil; ana
/// alanın hemen altında ne olacağını cümleyle söyleyen bir kip satırıdır.
/// Böylece "3" + tekrar seçimi, açıkken doğrudan "Her 3 günde bir
/// hatırlatılır" diye okunur.
class ReminderField extends StatefulWidget {
  const ReminderField({
    super.key,
    required this.days,
    required this.onChanged,
    this.repeats = false,
    this.onRepeatsChanged,
    this.blocked = false,
    this.locked = false,
    this.onOpenSystemSettings,
    this.onLockedTap,
    this.prominent = false,
  });

  /// Hatırlatma aralığı (gün). `0` ise hatırlatma yok.
  ///
  /// [repeats] kapalıyken "kaç gün sonra", açıkken "kaç günde bir".
  final int days;

  final ValueChanged<int> onChanged;

  /// Hatırlatma bu aralıkta tekrarlansın mı.
  final bool repeats;

  final ValueChanged<bool>? onRepeatsChanged;

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

  /// Compose ekranındaki açıklamalı sol label. Panel içindeki kompakt kullanım
  /// için varsayılan kapalıdır.
  final bool prominent;

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
      _onDaysChanged(0);
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
    _onDaysChanged(clamped);
  }

  /// Süre sıfırlanınca tekrar da kendiliğinden kapanır.
  ///
  /// "Sıfır günde bir" diye bir şey yok; açık kalmış bir tekrar bayrağı, süre
  /// yeniden verildiğinde kullanıcının istemediği bir kipi geri getirirdi.
  void _onDaysChanged(int value) {
    widget.onChanged(value);
    if (value == 0 && widget.repeats) widget.onRepeatsChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = widget.days > 0;

    if (widget.locked) {
      return _LockedField(
        onTap: widget.onLockedTap,
        prominent: widget.prominent,
      );
    }

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
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _submit,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            keyboardAppearance: palette.brightness,
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
        // Son ek esnek: tekrar kipinin metni "gün sonra"dan uzun ve dile göre
        // daha da uzuyor ("Tage · wiederholt"). Sabit bıraksaydık dar ekran ve
        // büyük yazı ölçeğinin birleştiği yerde satır taşardı; kısalması,
        // rakamın ekrandan taşmasına yeğdir.
        Flexible(
          child: Text(
            switch ((active, widget.repeats)) {
              (false, _) => context.l10n.reminderSuffixOff,
              (true, true) => context.l10n.reminderSuffixRepeating,
              (true, false) => context.l10n.reminderSuffixActive,
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: palette.caption.copyWith(color: palette.inkFaint),
          ),
        ),
      ],
    );

    final Widget reminderRow;
    if (widget.prominent) {
      reminderRow = NoteOptionRow(
        wideControl: true,
        label: NoteOptionLabel(
          icon: Icons.notifications_none_rounded,
          title: context.l10n.reminderLabel,
          detail: context.l10n.composeReminderDescription,
          active: active,
        ),
        trailing: trailing,
      );
    } else {
      reminderRow = Row(
        children: [
          Text(
            context.l10n.reminderLabel,
            style: palette.label.copyWith(
              color: active ? palette.ink : palette.inkSoft,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reminderRow,
        const SizedBox(height: 12),
        _RepeatControl(
          days: widget.days,
          repeats: widget.repeats,
          enabled: active,
          onChanged: widget.onRepeatsChanged,
        ),
      ],
    );
  }
}

/// Hatırlatmanın kipini açıkça söyleyen satır: bir kez mi, her X
/// günde bir mi.
///
/// Simge yalnızca yön buldurur; anlamı başlık, durum ve dinamik cümle taşır.
/// Kart, pill veya platform switch'i yok: tek bir cetvel ve tipografik durum
/// işareti Latermark'ın editoryal dilinde kalır.
class _RepeatControl extends StatelessWidget {
  const _RepeatControl({
    required this.days,
    required this.repeats,
    required this.enabled,
    required this.onChanged,
  });

  final int days;
  final bool repeats;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = enabled && onChanged != null;
    final selected = enabled && repeats;
    final detail = !enabled
        ? context.l10n.reminderRepeatNeedsInterval
        : selected
        ? context.l10n.reminderRepeatSummary(days)
        : context.l10n.reminderRepeatOnce;
    final state = context.l10n.upper(
      selected ? context.l10n.flashOn : context.l10n.flashOff,
    );

    return Semantics(
      button: true,
      enabled: live,
      toggled: selected,
      label: '${context.l10n.reminderRepeatToggle}. $detail',
      child: ExcludeSemantics(
        child: Pressable(
          key: const Key('reminder-repeat-control'),
          onPressed: live ? () => onChanged!(!selected) : null,
          scale: 0.99,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: palette.hairlineBright, width: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 11, 0, 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 19,
                      color: switch ((live, selected)) {
                        (false, _) => palette.inkGhost,
                        (true, true) => palette.ember,
                        (true, false) => palette.inkFaint,
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.reminderRepeatToggle,
                          style: palette.label.copyWith(
                            color: live ? palette.ink : palette.inkFaint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          key: const Key('reminder-repeat-detail'),
                          style: palette.caption.copyWith(
                            color: selected ? palette.ember : palette.inkFaint,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state,
                        style: palette.overline.copyWith(
                          color: selected ? palette.ember : palette.inkFaint,
                          letterSpacing: 1.25,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox.square(
                        dimension: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selected
                                  ? palette.ember
                                  : palette.hairlineBright,
                            ),
                          ),
                          child: selected
                              ? Center(
                                  child: ColoredBox(
                                    color: palette.ember,
                                    child: const SizedBox.square(dimension: 6),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  const _LockedField({required this.onTap, required this.prominent});

  final VoidCallback? onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onPressed: onTap,
      scale: 0.99,
      semanticLabel: '${context.l10n.reminderLabel}, ${context.l10n.proBadge}',
      child: ExcludeSemantics(
        child: prominent
            ? NoteOptionRow(
                // Kilitli hâl de aynı yerleşimi kullanır; Pro açıldığında
                // satırın yeri değişmesin.
                wideControl: true,
                label: NoteOptionLabel(
                  icon: Icons.notifications_none_rounded,
                  title: context.l10n.reminderLabel,
                  detail: context.l10n.composeReminderDescription,
                  active: false,
                ),
                trailing: const ProGateMark(),
              )
            : Row(
                children: [
                  Text(
                    context.l10n.reminderLabel,
                    style: palette.label.copyWith(color: palette.inkSoft),
                  ),
                  const Spacer(),
                  const ProGateMark(),
                ],
              ),
      ),
    );
  }
}
