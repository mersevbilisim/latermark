import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../domain/note_reminder.dart';

/// Hatırlatma gününü seçtiren takvim.
///
/// Material'ın `showDatePicker`'ı kullanılmıyor. Sebebi tembellik değil,
/// malzeme: o diyalog kendi köşe yarıçapını, kendi tipografisini, kendi dalga
/// efektini ve kendi vurgu rengini getiriyor. Uygulamanın geri kalanı ince
/// çizgiler ve kor rengi bir vurgu üzerine kurulu; araya giren o pencere
/// "başka bir uygulamadan alıntı" gibi duruyor.
///
/// Izgaranın **kutusu yok**: kendi sayfasında duruyor ve sayfa zaten bir
/// yüzey. Bir zamanlar panelin içinde çerçeveli bir kart olarak yaşıyordu;
/// kartın içindeki kart, hiyerarşiyi kurmak yerine sınır sayısını artırıyordu.
///
/// Saat burada sorulmuyor — [ReminderClock] onun yeri. Ama bir güne dokunmak
/// yine de bir **an** üretir: seçili saat korunur, o günde geçersizse güne
/// uygun makul bir saat gelir.
class ReminderCalendar extends StatefulWidget {
  const ReminderCalendar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.now,
    this.maxDays = ReminderChoice.maxDays,
  });

  /// Seçili an; henüz bir gün seçilmediyse `null`.
  final DateTime? value;

  final ValueChanged<DateTime> onChanged;

  /// Ekran açıldığındaki referans an. Sabittir: gece yarısını geçen bir seçim
  /// sırasında ızgaranın altından "bugün" kaymasın.
  final DateTime now;

  /// Bugünden itibaren seçilebilecek en uzak gün.
  final int maxDays;

  @override
  State<ReminderCalendar> createState() => _ReminderCalendarState();
}

class _ReminderCalendarState extends State<ReminderCalendar> {
  /// Açılışta görünen ay: seçili günün ayı, ama hiçbir zaman bugünden geriye
  /// değil. Hatırlatması çalmış bir kayıtta saklanan an geçmişte kalır ve
  /// ekranı geçmiş bir aya açmak, kullanıcının **yeni** gün seçmesi gereken
  /// yerde ona kapalı bir ızgara göstermek olurdu.
  late DateTime _month =
      _monthOf(widget.value ?? widget.now).isAfter(_monthOf(widget.now))
      ? _monthOf(widget.value!)
      : _monthOf(widget.now);

  /// Ay değişiminin yönü; başlık ve ızgara o yöne doğru kayar.
  int _direction = 1;

  DateTime get _firstDay => reminderDayOf(widget.now);
  DateTime get _lastDay =>
      reminderDayOf(shiftLocalCalendarDays(widget.now, widget.maxDays));

  @override
  void didUpdateWidget(ReminderCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seçim dışarıdan değiştiyse takvim o aya gitsin; kullanıcı ekrana geri
    // döndüğünde "nerede kalmıştım" sorusuyla karşılaşmasın.
    final value = widget.value;
    if (value != null &&
        _monthOf(value) != _monthOf(oldWidget.value ?? value)) {
      _direction = _monthOf(value).isAfter(_month) ? 1 : -1;
      _month = _monthOf(value);
    }
  }

  /// Seçili günün saati; henüz seçim yoksa o gün için önerilen saat.
  TimeOfDay get _time {
    final value = widget.value;
    if (value != null) return TimeOfDay(hour: value.hour, minute: value.minute);
    return defaultReminderTime(now: widget.now, day: _firstDay);
  }

  /// Bir gün seçilebilir mi: aralıkta ve gününde hâlâ geçmemiş bir dakika
  /// varsa. Saat serbest yazılabildiği için bugün gece yarısına kadar açık.
  bool _isDaySelectable(DateTime day) {
    if (day.isBefore(_firstDay) || day.isAfter(_lastDay)) return false;
    return reminderEndOfDay(day).isAfter(widget.now);
  }

  /// Bir güne dokunmak saati de belirler: kullanıcının yazdığı saat o günde
  /// hâlâ geçerliyse korunur, değilse o güne uygun varsayılan gelir.
  ///
  /// Henüz hiçbir seçim yokken varsayılan **seçilen güne** göre hesaplanıyor:
  /// bugünün sabahı geçmiş olabilir ama gelecek haftanın sabahı geçmedi.
  void _selectDay(DateTime day) {
    final current = _time;
    final chosen =
        widget.value != null &&
            reminderMomentOf(day, current).isAfter(widget.now)
        ? current
        : defaultReminderTime(now: widget.now, day: day);
    widget.onChanged(reminderMomentOf(day, chosen));
  }

  void _shiftMonth(int months) {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = months;
      _month = DateTime(_month.year, _month.month + months);
    });
  }

  bool get _canGoBack => _month.isAfter(_monthOf(_firstDay));
  bool get _canGoForward => _monthOf(_lastDay).isAfter(_month);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('reminder-calendar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthBar(
          month: _month,
          direction: _direction,
          canGoBack: _canGoBack,
          canGoForward: _canGoForward,
          onShift: _shiftMonth,
        ),
        const SizedBox(height: 8),
        const _WeekdayRow(),
        const SizedBox(height: 2),
        _MonthGrid(
          month: _month,
          direction: _direction,
          selected: widget.value == null ? null : reminderDayOf(widget.value!),
          today: reminderDayOf(widget.now),
          isSelectable: _isDaySelectable,
          onSelected: _selectDay,
        ),
      ],
    );
  }
}

DateTime _monthOf(DateTime at) => DateTime(at.year, at.month);

/// Bir anın günü; saatler düşer.
DateTime reminderDayOf(DateTime at) => DateTime(at.year, at.month, at.day);

/// Gün ve saatten an.
DateTime reminderMomentOf(DateTime day, TimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

/// Günün son seçilebilir dakikası.
DateTime reminderEndOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59);

/// Bir gün için makul başlangıç: **şu anki saat**.
///
/// "Yarın" demek çoğu zaman "yarın bu saatte" demek. Bugün seçildiğinde aynı
/// dakika tanım gereği geçmişte kalır; o durumda bir sonraki tam saat alınır.
TimeOfDay defaultReminderTime({required DateTime now, required DateTime day}) {
  final sameClock = TimeOfDay(hour: now.hour, minute: now.minute);
  if (reminderMomentOf(day, sameClock).isAfter(now)) return sameClock;

  final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
  final end = reminderEndOfDay(day);
  final at = nextHour.isAfter(end) ? end : nextHour;
  return TimeOfDay(hour: at.hour, minute: at.minute);
}

/// Ay adı ve iki ok. Ay adı kayarak değişir; hangi yöne gidildiği görünür.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.direction,
    required this.canGoBack,
    required this.canGoForward,
    required this.onShift,
  });

  final DateTime month;
  final int direction;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final title = DateFormat.yMMMM(l10n.localeName).format(month);

    return Row(
      children: [
        _MonthArrow(
          key: const Key('reminder-month-previous'),
          icon: Icons.chevron_left_rounded,
          enabled: canGoBack,
          semanticLabel: DateFormat.yMMMM(
            l10n.localeName,
          ).format(DateTime(month.year, month.month - 1)),
          onPressed: () => onShift(-1),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            switchInCurve: AppMotion.ease,
            transitionBuilder: (child, animation) {
              final faded = FadeTransition(opacity: animation, child: child);
              // Hareket azaltıldığında ay adı yana kaymadan soluyor.
              if (MediaQuery.disableAnimationsOf(context)) return faded;
              return SlideTransition(
                position: Tween(
                  begin: Offset(0.12 * direction, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: faded,
              );
            },
            child: Text(
              l10n.upper(title),
              key: ValueKey(title),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: palette.overline.copyWith(
                color: palette.ink,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        _MonthArrow(
          key: const Key('reminder-month-next'),
          icon: Icons.chevron_right_rounded,
          enabled: canGoForward,
          semanticLabel: DateFormat.yMMMM(
            l10n.localeName,
          ).format(DateTime(month.year, month.month + 1)),
          onPressed: () => onShift(1),
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    super.key,
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onPressed: enabled ? onPressed : null,
      scale: 0.9,
      semanticLabel: semanticLabel,
      minimumTarget: const Size.square(44),
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(
          icon,
          size: 21,
          color: enabled ? palette.inkSoft : palette.inkGhost,
        ),
      ),
    );
  }
}

/// Haftanın günlerinin baş harfleri. Sıra kullanıcının yereline göre.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final material = MaterialLocalizations.of(context);
    final first = material.firstDayOfWeekIndex;

    return Row(
      children: [
        for (var column = 0; column < 7; column++)
          Expanded(
            child: Text(
              material.narrowWeekdays[(first + column) % 7],
              textAlign: TextAlign.center,
              maxLines: 1,
              style: palette.caption.copyWith(
                color: palette.inkFaint,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ayın günleri. Komşu ayların günleri **çizilmiyor**: ızgaranın kenarında
/// soluk bir sürü rakam, seçilebilir olanların arasında gürültü yapıyor.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.direction,
    required this.selected,
    required this.today,
    required this.isSelectable,
    required this.onSelected,
  });

  final DateTime month;
  final int direction;
  final DateTime? selected;
  final DateTime today;
  final bool Function(DateTime day) isSelectable;
  final ValueChanged<DateTime> onSelected;

  /// Satır sayısı ayın uzunluğuna göre 5 ile 6 arasında değişir. Sabit altı
  /// satır, aylar arasında gezinirken sayfanın boyunun oynamasını önlüyor.
  static const _rows = 6;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final cellHeight = math.max(44.0, scaler.scale(15) + 24);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    // Dart'ta pazartesi 1, pazar 7; Material'ın indeksinde pazar 0.
    final leading = (firstOfMonth.weekday % 7 - firstWeekday + 7) % 7;

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.ease,
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (MediaQuery.disableAnimationsOf(context)) return faded;
        return SlideTransition(
          position: Tween(
            begin: Offset(0.06 * direction, 0),
            end: Offset.zero,
          ).animate(animation),
          child: faded,
        );
      },
      child: Column(
        key: ValueKey(month),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < _rows; row++)
            SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final dayNumber = row * 7 + column - leading + 1;
                          if (dayNumber < 1 || dayNumber > dayCount) {
                            return const SizedBox.shrink();
                          }
                          final day = DateTime(
                            month.year,
                            month.month,
                            dayNumber,
                          );
                          return _DayCell(
                            day: day,
                            selected: day == selected,
                            isToday: day == today,
                            enabled: isSelectable(day),
                            onPressed: () => onSelected(day),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bir gün. Seçim kutuyla değil, rakamın altındaki kısa çentikle söyleniyor;
/// bugünün işareti ise bir nokta. İkisi de kartın künyesindeki hatırlatma
/// çentiğiyle aynı dili konuşuyor.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onPressed,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      key: Key('reminder-day-${day.year}-${day.month}-${day.day}'),
      onPressed: enabled ? onPressed : null,
      scale: 0.9,
      semanticLabel: context.l10n.calendarDate(day),
      semanticHint: isToday ? context.l10n.dayToday : null,
      selected: selected,
      minimumTarget: const Size.square(44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            maxLines: 1,
            style: palette.label.copyWith(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
              // Geçmiş günler soluk ama **okunur**: hayalet tonda ızgaranın
              // o kısmı boşluk gibi görünüyor, ay da yarım kalmış duruyordu.
              color: !enabled
                  ? palette.inkFaint
                  : selected
                  ? palette.ember
                  : palette.ink,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 3,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: selected
                  ? Container(
                      key: const ValueKey('selected'),
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: palette.ember,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : isToday
                  ? Container(
                      key: const ValueKey('today'),
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: enabled ? palette.ember : palette.inkFaint,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
