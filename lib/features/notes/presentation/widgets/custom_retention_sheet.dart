import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../l10n/enum_labels.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/retention.dart';

/// Özel saklama süresini soran panel. Kabul edilirse dakika döner.
///
/// Çark (`CupertinoPicker`) yerine sayı + birim: uygulamanın hatırlatma alanı
/// zaten aynı kalıbı kullanıyor ve çark bu tasarım diline yabancı bir malzeme.
Future<int?> showCustomRetentionSheet(
  BuildContext context, {
  int initialMinutes = 0,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    // Hatırlatma paneliyle aynı ritim: iki yüzey aynı uygulamada aynı hızla
    // açılmalı.
    sheetAnimationStyle: AnimationStyle(
      curve: AppMotion.ease,
      duration: AppMotion.medium,
      reverseCurve: AppMotion.exit,
      reverseDuration: AppMotion.fast,
    ),
    builder: (context) => _CustomRetentionSheet(initialMinutes: initialMinutes),
  );
}

/// Süre birimi. Dakika cinsinden karşılığı burada duruyor.
enum _Unit {
  hours(60),
  days(1440),
  weeks(10080);

  const _Unit(this.minutes);
  final int minutes;
}

class _CustomRetentionSheet extends StatefulWidget {
  const _CustomRetentionSheet({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomRetentionSheet> createState() => _CustomRetentionSheetState();
}

class _CustomRetentionSheetState extends State<_CustomRetentionSheet> {
  late _Unit _unit;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();

    // Kullanıcının girdiği birimi geri veriyoruz: "3 gün" seçen biri paneli
    // yeniden açtığında "72 saat" görmemeli.
    final minutes = widget.initialMinutes > 0 ? widget.initialMinutes : 360;
    _unit = minutes % _Unit.weeks.minutes == 0
        ? _Unit.weeks
        : minutes % _Unit.days.minutes == 0
        ? _Unit.days
        : _Unit.hours;
    _amount = TextEditingController(
      text: (minutes ~/ _unit.minutes).toString(),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _minutes {
    final value = int.tryParse(_amount.text) ?? 0;
    return (value * _unit.minutes).clamp(0, RetentionChoice.maxCustomMinutes);
  }

  bool get _valid => _minutes >= RetentionChoice.minCustomMinutes;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.canvasLift,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppShape.panel),
            ),
            side: BorderSide(color: palette.hairlineBright, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.retentionCustomTitle, style: palette.title),
              const SizedBox(height: 6),
              Text(
                l10n.retentionCustomDescription,
                style: palette.caption.copyWith(
                  color: palette.inkFaint,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: TextField(
                      controller: _amount,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      keyboardAppearance: Brightness.dark,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: palette.display.copyWith(fontSize: 30, height: 1),
                      cursorColor: palette.ember,
                      cursorWidth: 2,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: palette.hairlineBright),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: palette.ember,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _UnitRail(value: _unit, onChanged: _setUnit),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              // Ne seçtiğini normalleştirilmiş hâliyle göstermek, "48 saat"
              // yazan birine "2 gün" olduğunu söylüyor.
              Text(
                _valid
                    ? formatMinutes(l10n, _minutes)
                    : l10n.retentionCustomHours(1),
                style: palette.bodyStrong.copyWith(
                  color: _valid ? palette.ember : palette.inkFaint,
                ),
              ),

              const SizedBox(height: 18),
              PrimaryButton(
                label: l10n.actionSave,
                onPressed: _valid
                    ? () => Navigator.of(context).pop(_minutes)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setUnit(_Unit unit) {
    HapticFeedback.selectionClick();
    setState(() => _unit = unit);
  }
}

/// Saat / Gün / Hafta seçimi.
class _UnitRail extends StatelessWidget {
  const _UnitRail({required this.value, required this.onChanged});

  final _Unit value;
  final ValueChanged<_Unit> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    String labelOf(_Unit unit) => switch (unit) {
      _Unit.hours => l10n.retentionUnitHours,
      _Unit.days => l10n.retentionUnitDays,
      _Unit.weeks => l10n.retentionUnitWeeks,
    };

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
        child: Row(
          children: [
            for (final unit in _Unit.values)
              Expanded(
                child: Pressable(
                  onPressed: () => onChanged(unit),
                  scale: 0.97,
                  semanticLabel: labelOf(unit),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: unit == value
                          ? palette.canvasLift
                          : Colors.transparent,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: AppShape.all(AppShape.chip),
                        side: BorderSide(
                          color: unit == value
                              ? palette.ember.withValues(alpha: 0.28)
                              : Colors.transparent,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        labelOf(unit),
                        textAlign: TextAlign.center,
                        style: palette.label.copyWith(
                          color: unit == value ? palette.ink : palette.inkSoft,
                          fontWeight: unit == value
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
