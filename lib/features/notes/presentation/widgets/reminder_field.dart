import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/pro_badge.dart';
import 'note_option_label.dart';

/// Hatırlatma alanının tek seferde uygulanan sonucu.
///
/// Sheet içindeki denemeler bu değer dönene kadar nota yazılmaz. Kullanıcı
/// vazgeçerse Compose/Edit Note state'i hiç değişmez.
@immutable
class ReminderSelection {
  const ReminderSelection({required this.days, required this.repeats});

  final int days;
  final bool repeats;
}

/// Hatırlatmayı not formundan ayıran, geçici seçim yüzeyi.
///
/// Yazı klavyesi önce kapanır; hızlı aralıklar, özel gün sayısı ve tekrar kipi
/// aynı yüzeyde seçilir. Böylece Compose ve Edit Note içinde iki ayrı form
/// satırı klavyenin altında kalmaz, ama özel aralık ve tekrar yetenekleri de
/// kaybolmaz.
Future<ReminderSelection?> showReminderSheet(
  BuildContext context, {
  required int initialDays,
  required bool initialRepeats,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<ReminderSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    builder: (context) => _ReminderSheet(
      initialDays: initialDays,
      initialRepeats: initialRepeats,
    ),
  );
}

/// Compose ve Edit Note'ta görünen tek, özet hatırlatma satırı.
///
/// Satır yalnızca mevcut kararı gösterir. Düzenleme ayrı bir sheet'te olduğu
/// için not klavyesiyle yarışmaz; bir gün sayısı ile tekrar kipini aynı anda
/// görüp onaylamak da mümkün olur.
class ReminderField extends StatelessWidget {
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
  final int days;
  final ValueChanged<int> onChanged;

  /// Hatırlatma bu aralıkta tekrarlansın mı.
  final bool repeats;
  final ValueChanged<bool>? onRepeatsChanged;

  /// Bildirim izni yokken `true`. İstek kaybolmaz ama durum açıkça görünür.
  final bool blocked;
  final VoidCallback? onOpenSystemSettings;

  /// Pro'ya özel: ücretsiz katmanda alan görünür ama düzenlenemez.
  final bool locked;
  final VoidCallback? onLockedTap;

  /// Compose/Edit Note içindeki açıklamalı seçenek etiketi.
  final bool prominent;

  /// Bundan uzağı için hatırlatma yerine takvim daha doğru araçtır.
  static const maxDays = 365;

  Future<void> _open(BuildContext context) async {
    final selection = await showReminderSheet(
      context,
      initialDays: days,
      initialRepeats: repeats,
    );
    if (selection == null || !context.mounted) return;

    // Önce süreyi yazmak ReminderControl'ün izin kuralını yalnızca kesinleşen
    // seçim için çalıştırır; sheet içinde gezinirken sistem istemi açılmaz.
    if (selection.days != days) onChanged(selection.days);
    if (selection.repeats != repeats) {
      onRepeatsChanged?.call(selection.repeats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = days > 0;

    if (locked) {
      return _LockedField(onTap: onLockedTap, prominent: prominent);
    }

    final control = Pressable(
      key: const Key('reminder-field-control'),
      onPressed: () => _open(context),
      scale: 0.99,
      semanticLabel: _semanticLabel(context),
      child: ExcludeSemantics(
        child: prominent
            ? NoteOptionRow(
                label: NoteOptionLabel(
                  icon: Icons.notifications_none_rounded,
                  title: context.l10n.reminderLabel,
                  detail: context.l10n.composeReminderDescription,
                  active: active,
                ),
                trailing: _ReminderSummary(days: days, repeats: repeats),
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.reminderLabel,
                      style: context.palette.label.copyWith(
                        color: active
                            ? context.palette.ink
                            : context.palette.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ReminderSummary(days: days, repeats: repeats),
                ],
              ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        if (active && blocked) ...[
          const SizedBox(height: 10),
          _BlockedNotice(onOpenSystemSettings: onOpenSystemSettings),
        ],
      ],
    );
  }

  String _semanticLabel(BuildContext context) {
    final value = days == 0
        ? context.l10n.retentionOff
        : repeats
        ? context.l10n.reminderRepeatSummary(days)
        : '${context.l10n.retentionCustomDays(days)}. '
              '${context.l10n.reminderRepeatOnce}';
    return '${context.l10n.reminderLabel}. $value';
  }
}

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({required this.days, required this.repeats});

  final int days;
  final bool repeats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = days > 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  active
                      ? context.l10n.retentionCustomDays(days)
                      : context.l10n.retentionOff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: palette.bodyStrong.copyWith(
                    color: active ? palette.ember : palette.inkFaint,
                    fontSize: 15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 2),
                  Text(
                    repeats
                        ? context.l10n.reminderRepeatToggle
                        : context.l10n.reminderRepeatOnce,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.caption.copyWith(
                      color: palette.inkFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: active ? palette.ember : palette.inkGhost,
          ),
        ],
      ),
    );
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.initialDays,
    required this.initialRepeats,
  });

  final int initialDays;
  final bool initialRepeats;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  static const _presets = [0, 1, 7];

  late int _days = widget.initialDays.clamp(0, ReminderField.maxDays);
  late bool _repeats = _days > 0 && widget.initialRepeats;
  late bool _customMode = !_presets.contains(_days);
  late final TextEditingController _custom = TextEditingController(
    text: _days > 0 ? _days.toString() : '',
  );
  late final FocusNode _customFocus = FocusNode();

  @override
  void dispose() {
    _custom.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _selectPreset(int days) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _customMode = false;
      _days = days;
      if (days == 0) _repeats = false;
      _custom.text = days > 0 ? days.toString() : '';
      _custom.selection = TextSelection.collapsed(offset: _custom.text.length);
    });
  }

  void _setCustom(String raw) {
    final parsed = int.tryParse(raw);
    final days = (parsed ?? 0).clamp(0, ReminderField.maxDays);
    if (parsed != null && parsed != days) {
      _custom.text = days.toString();
      _custom.selection = TextSelection.collapsed(offset: _custom.text.length);
    }
    setState(() {
      _customMode = true;
      _days = days;
      if (days == 0) _repeats = false;
    });
  }

  void _activateCustom() {
    if (!_customMode) setState(() => _customMode = true);
  }

  void _selectCustom() {
    HapticFeedback.selectionClick();
    _activateCustom();
    _customFocus.requestFocus();
    _custom.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _custom.text.length,
    );
  }

  void _setRepeats(bool value) {
    if (_days == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _repeats = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    // Klavye sheet'i yukarı iter; güvenli alan ise yüzeyin *içinde* SafeArea
    // tarafından karşılanır. Sistem alt boşluğunu burada da uygularsak yüzey
    // telefonun alt kenarından kopuk, yüzen bir kart gibi görünüyordu.
    final bottom = media.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        key: const Key('reminder-sheet'),
        decoration: ShapeDecoration(
          color: palette.canvasLift,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppShape.panel),
            ),
            side: BorderSide(color: palette.hairlineBright, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(onCancel: () => Navigator.of(context).pop()),
                const SizedBox(height: 6),
                Text(
                  context.l10n.composeReminderDescription,
                  style: palette.caption.copyWith(
                    color: palette.inkFaint,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _QuickChoices(
                  days: _days,
                  customMode: _customMode,
                  onPresetSelected: _selectPreset,
                  onCustomSelected: _selectCustom,
                ),
                const SizedBox(height: 18),
                _CustomDaysField(
                  controller: _custom,
                  focusNode: _customFocus,
                  onTap: _activateCustom,
                  onChanged: _setCustom,
                ),
                const SizedBox(height: 18),
                _ModeRail(
                  enabled: _days > 0,
                  repeats: _repeats,
                  onChanged: _setRepeats,
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _selectionSummary(context),
                    key: ValueKey((_days, _repeats)),
                    style: palette.bodyStrong.copyWith(
                      color: _days > 0 ? palette.ember : palette.inkFaint,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  key: const Key('reminder-sheet-save'),
                  label: context.l10n.actionOK,
                  onPressed: _customMode && _days == 0
                      ? null
                      : () => Navigator.of(context).pop(
                          ReminderSelection(days: _days, repeats: _repeats),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _selectionSummary(BuildContext context) {
    if (_days == 0) return context.l10n.reminderRepeatNeedsInterval;
    if (_repeats) return context.l10n.reminderRepeatSummary(_days);
    return '${context.l10n.retentionCustomDays(_days)} · '
        '${context.l10n.reminderRepeatOnce}';
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(context.l10n.reminderLabel, style: context.palette.title),
        ),
        const SizedBox(width: 12),
        Pressable(
          key: const Key('reminder-sheet-cancel'),
          onPressed: onCancel,
          semanticLabel: context.l10n.actionCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Text(
              context.l10n.actionCancel,
              style: context.palette.label.copyWith(
                color: context.palette.inkSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickChoices extends StatelessWidget {
  const _QuickChoices({
    required this.days,
    required this.customMode,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final int days;
  final bool customMode;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.retentionOff,
      context.l10n.retentionCustomDays(1),
      context.l10n.retentionCustomDays(7),
      context.l10n.retentionCustom,
    ];
    final style = context.palette.label.copyWith(fontWeight: FontWeight.w500);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final fourColumnWidth = (constraints.maxWidth - gap * 3) / 4;
        final fourColumns = labels.every(
          (label) =>
              _textWidth(label, style, scaler, direction) <=
              fourColumnWidth - 16,
        );
        final columns = fourColumns ? 4 : 2;
        final cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final labelWidth = math.max(1.0, cellWidth - 16);
        final cellHeight = math.max(
          44.0,
          labels
                  .map(
                    (label) => _textHeight(
                      label,
                      style,
                      scaler,
                      direction,
                      labelWidth,
                    ),
                  )
                  .reduce(math.max) +
              20,
        );

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: _Preset(
                key: const Key('reminder-preset-0'),
                label: labels[0],
                selected: !customMode && days == 0,
                onPressed: () => onPresetSelected(0),
              ),
            ),
            SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: _Preset(
                key: const Key('reminder-preset-1'),
                label: labels[1],
                selected: !customMode && days == 1,
                onPressed: () => onPresetSelected(1),
              ),
            ),
            SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: _Preset(
                key: const Key('reminder-preset-7'),
                label: labels[2],
                selected: !customMode && days == 7,
                onPressed: () => onPresetSelected(7),
              ),
            ),
            SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: _Preset(
                key: const Key('reminder-preset-custom'),
                label: labels[3],
                selected: customMode,
                onPressed: onCustomSelected,
              ),
            ),
          ],
        );
      },
    );
  }

  double _textWidth(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double _textHeight(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
      textAlign: TextAlign.center,
      maxLines: 3,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}

class _Preset extends StatelessWidget {
  const _Preset({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onPressed: onPressed,
      scale: 0.97,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: ShapeDecoration(
          color: selected ? palette.canvasSunk : Colors.transparent,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppShape.all(AppShape.chip),
            side: BorderSide(
              color: selected
                  ? palette.ember.withValues(alpha: 0.52)
                  : palette.hairlineBright,
              width: 0.5,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 3,
          textAlign: TextAlign.center,
          style: palette.label.copyWith(
            color: selected ? palette.ember : palette.inkSoft,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CustomDaysField extends StatelessWidget {
  const _CustomDaysField({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.retentionCustom,
            style: palette.label.copyWith(color: palette.inkSoft),
          ),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            key: const Key('reminder-custom-days'),
            controller: controller,
            focusNode: focusNode,
            onTap: onTap,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            keyboardAppearance: palette.brightness,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: palette.bodyStrong.copyWith(
              color: palette.ember,
              fontSize: 18,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            cursorColor: palette.ember,
            cursorWidth: 2,
            decoration: InputDecoration(
              isDense: true,
              hintText: '—',
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
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
          context.l10n.retentionUnitDays,
          style: palette.caption.copyWith(color: palette.inkFaint),
        ),
      ],
    );
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({
    required this.enabled,
    required this.repeats,
    required this.onChanged,
  });

  final bool enabled;
  final bool repeats;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.canvasSunk,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.all(AppShape.control),
          side: BorderSide(color: palette.hairlineBright, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _Mode(
                  key: const Key('reminder-mode-once'),
                  label: context.l10n.reminderRepeatOnce,
                  icon: Icons.notifications_none_rounded,
                  enabled: enabled,
                  selected: enabled && !repeats,
                  onPressed: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _Mode(
                  key: const Key('reminder-mode-repeat'),
                  label: context.l10n.reminderRepeatToggle,
                  icon: Icons.repeat_rounded,
                  enabled: enabled,
                  selected: enabled && repeats,
                  onPressed: () => onChanged(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: Pressable(
        onPressed: enabled ? onPressed : null,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: ShapeDecoration(
            color: selected ? palette.canvasLift : Colors.transparent,
            shape: RoundedSuperellipseBorder(
              borderRadius: AppShape.all(AppShape.chip),
              side: BorderSide(
                color: selected
                    ? palette.ember.withValues(alpha: 0.30)
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: !enabled
                    ? palette.inkGhost
                    : selected
                    ? palette.ember
                    : palette.inkFaint,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: palette.label.copyWith(
                    color: !enabled
                        ? palette.inkGhost
                        : selected
                        ? palette.ink
                        : palette.inkSoft,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Süre verilmiş ama bildirim izni yokken görünen satır.
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
