import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/aperture.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/choice_rail.dart';
import '../../../../shared/widgets/colophon_bar.dart';
import '../../../../shared/widgets/ember_switch.dart';
import '../../../reminders/reminder_service.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_reminder.dart';
import '../home/widgets/note_photo.dart';
import '../widgets/note_option_label.dart';
import '../widgets/reminder_calendar.dart';
import '../widgets/reminder_control.dart';

/// Kare kaydedildikten sonra açılan tek soruluk ekran: **ne zaman dönsün?**
///
/// Kayıt ekranında hatırlatma bir evet/hayırdı; burada karşılığı veriliyor.
/// Bu ayrım bilinçli: yazarken klavyenin üstünde takvim açmak, iki işi aynı
/// anda yaptırıp ikisini de yarım bırakıyordu. Not artık diskte — bu ekrandan
/// vazgeçmek kaydı değil, yalnız hatırlatmayı iptal eder.
///
/// Sayfanın tamamı **tek bir işaret** üzerine kurulu: seçili olanın altındaki
/// kısa kor çentik. Gün ızgarasında, saatin altında, tekrar seçeneğinin
/// yanında hep aynı çentik; ekranda dolu kutu, pil ya da onay kutusu yok.
class ReminderSchedulePage extends StatefulWidget {
  const ReminderSchedulePage({
    super.key,
    required this.noteId,
    this.initial = const ReminderChoice.off(),
    this.initialDeleteAfter = false,
    this.onFlowClosed,
    this.now,
  });

  final int noteId;

  /// Kayıtlı hatırlatma; yeni bir karede kapalı gelir.
  final ReminderChoice initial;

  /// Kayıtlı notun silinme anı hatırlatmasından mı türemiş — yani kullanıcı
  /// bu sözü daha önce vermiş mi.
  final bool initialDeleteAfter;

  /// Kameradan başlayan dış yönlendirme zincirinin son halkası. Yazma ekranı
  /// bu sayfaya yerini bıraktığı için zinciri artık bu sayfa kapatıyor.
  final VoidCallback? onFlowClosed;

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  @override
  State<ReminderSchedulePage> createState() => _ReminderSchedulePageState();
}

class _ReminderSchedulePageState extends State<ReminderSchedulePage> {
  /// Sayfa boyunca sabit referans an. Her karede `DateTime.now()` okumak,
  /// gece yarısını geçen bir seçimde ızgaranın altından "bugün"ü kaydırırdı.
  late final DateTime _now = widget.now ?? DateTime.now();

  /// Seçili an.
  ///
  /// Boş bir takvimle karşılamıyoruz: kullanıcı anahtarı açarak niyetini
  /// zaten söyledi, ekran da bir öneriyle açılıyor — yarın, aynı saatte.
  /// Tekrarlı bir kayıtta saklanan değer dizinin ilk halkasıdır ve geçmişte
  /// kalmış olabilir; gösterilen, bekleyen oluşum.
  late DateTime _at =
      pendingReminderAt(
        remindAt: widget.initial.at,
        everyDays: widget.initial.everyDays,
        now: _now,
      ) ??
      _defaultMoment;

  late int _everyDays = widget.initial.everyDays;

  /// "Hatırlattıktan bir saat sonra sil." Yalnız tek atışta anlamlı.
  late bool _deleteAfter = widget.initialDeleteAfter;

  bool _saving = false;
  bool _flowClosed = false;

  NotesRepository? _repository;
  Future<Note?>? _note;

  DateTime get _defaultMoment {
    final tomorrow = shiftLocalCalendarDays(_now, 1);
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      tomorrow.hour,
      tomorrow.minute,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository == _repository) return;
    _repository = repository;
    // Tek okuma yetiyor: kare bu ekran açıkken değişmiyor, künye de
    // kaydedilmiş hâli gösteriyor.
    _note = repository.noteById(widget.noteId);
  }

  @override
  void dispose() {
    _closeFlow();
    super.dispose();
  }

  void _closeFlow() {
    if (_flowClosed) return;
    _flowClosed = true;
    widget.onFlowClosed?.call();
  }

  /// Takvimden seçilen gün, tekrar açıkken aralığı da tazeler: "6 Eylül" diyen
  /// kullanıcı tekrarı da o güne göre kurmuş olur.
  int _intervalFor(DateTime at) =>
      math.max(1, localCalendarDaysBetween(_now, at));

  void _selectMoment(DateTime at) {
    setState(() {
      _at = at;
      if (_everyDays > 0) _everyDays = _intervalFor(at);
    });
  }

  void _setRepeats(bool value) {
    HapticFeedback.selectionClick();
    setState(() => _everyDays = value ? _intervalFor(_at) : 0);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();

    final navigator = Navigator.of(context);
    try {
      await _repository!.setReminder(
        widget.noteId,
        ReminderChoice(at: _at, everyDays: _everyDays),
        deleteAfterReminder: _deleteAfter,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, context.l10n.toastSaveFailed, error: true);
      return;
    }
    if (!mounted) return;
    navigator.pop();
  }

  void _skip() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final blocked =
        AppScope.reminderPermission(context) == ReminderPermissionState.denied;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: PopScope(
        canPop: !_saving,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                child: _SavedFrame(note: _note, repository: _repository),
              ),
              const _Rule(),
              Expanded(
                // Üç bölüm sayfanın boyuna yayılıyor: artan yer sonda tek bir
                // boşluk olarak birikmiyor, aralara paylaşılıyor. İçerik
                // sığmadığında (büyük yazı, açık klavye) yayılacak yer kalmaz
                // ve sayfa kendiliğinden kaymaya döner.
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight - 32,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReminderCalendar(
                            value: _at,
                            now: _now,
                            onChanged: _selectMoment,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Rule(),
                              const SizedBox(height: 18),
                              ReminderClock(
                                value: _at,
                                now: _now,
                                onChanged: _selectMoment,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Rule(),
                              const SizedBox(height: 18),
                              // Tekrar kipi ikili bir karar; uygulamanın her
                              // yerdeki seçim rayı bunu tek satırda söylüyor.
                              // Sonucun cümlesi kaydetmenin hemen üstünde
                              // zaten yazıyor — rayın altına ikinci kez
                              // yazmak aynı şeyi iki kere söylemek olurdu.
                              ChoiceRail<bool>(
                                key: const Key('reminder-cadence-rail'),
                                options: const [false, true],
                                value: _everyDays > 0,
                                onChanged: _setRepeats,
                                labelOf: (repeats) => repeats
                                    ? l10n.reminderRepeatTitle
                                    : l10n.reminderOnceTitle,
                              ),
                              // Silme sözü yalnız tek atışta duruyor: sürekli
                              // hatırlatılan bir kareyi ilk bildirimden sonra
                              // silmek, verilen sözün kendisini yerdi.
                              AnimatedSize(
                                duration: AppMotion.medium,
                                curve: AppMotion.ease,
                                alignment: Alignment.topCenter,
                                child: _everyDays > 0
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: _DeleteAfterRow(
                                          value: _deleteAfter,
                                          onChanged: (value) => setState(
                                            () => _deleteAfter = value,
                                          ),
                                        ),
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
              if (blocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                  child: ReminderBlockedNotice(
                    onOpenSystemSettings: () =>
                        context.reminders.openSystemSettings(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    l10n.reminderValue(
                      at: _at,
                      everyDays: _everyDays,
                      use24Hour: context.use24Hour,
                    ),
                    key: ValueKey((_at, _everyDays)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: palette.bodyStrong.copyWith(color: palette.ember),
                  ),
                ),
              ),
              ColophonBar(
                actions: [
                  ColophonAction(
                    key: const ValueKey('reminder-schedule-skip'),
                    label: l10n.reminderSkip,
                    semanticLabel: l10n.reminderSkip,
                    onPressed: _saving ? null : _skip,
                  ),
                  ColophonAction(
                    key: const ValueKey('reminder-schedule-save'),
                    label: l10n.actionSave,
                    semanticLabel: l10n.actionSave,
                    accent: true,
                    busy: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kaydedilen karenin künyesi ve ekranın tek sorusu.
///
/// Baskının kendisi burada duruyor: planlanan şey bir "öğe" değil, az önce
/// çekilmiş o kare. Fotoğraf gelene kadar yerini boş bir yüzey tutuyor;
/// yüksekliği sabit olduğu için soru satırı kaymıyor.
class _SavedFrame extends StatelessWidget {
  const _SavedFrame({required this.note, required this.repository});

  final Future<Note?>? note;
  final NotesRepository? repository;

  static const _size = 54.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRSuperellipse(
          borderRadius: AppShape.all(AppShape.print),
          child: SizedBox(
            width: _size,
            height: _size,
            child: ColoredBox(
              color: palette.canvasSunk,
              child: FutureBuilder<Note?>(
                future: note,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  final store = repository;
                  if (value == null || store == null) {
                    return const SizedBox.shrink();
                  }
                  return NotePhoto(
                    file: store.imageOf(value),
                    decodeWidth: _size,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.ember,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      l10n.upper(l10n.reminderScheduleSaved),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: palette.overline.copyWith(color: palette.ember),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                l10n.reminderScheduleQuestion,
                style: palette.title.copyWith(fontSize: 19),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Hatırlattıktan 1 saat sonra sil."
///
/// Soldaki işaret bir ikon değil, uygulamanın kendi irisi: söz verildiğinde
/// kapanmaya başlar. Aynı iris not detayında kalan ömrü, silme onayında da
/// kararın kendisini gösteriyor — üç ekran tek bir cümle kuruyor.
class _DeleteAfterRow extends StatelessWidget {
  const _DeleteAfterRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = context.l10n.reminderDeleteAfterLabel;

    return GestureDetector(
      key: const Key('reminder-delete-after-row'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: MergeSemantics(
        child: NoteOptionRow(
          label: ExcludeSemantics(
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 21,
                  child: AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child: Aperture(
                      key: ValueKey(value),
                      openness: value ? 0.22 : 0.72,
                      twist: value ? -0.34 : 0,
                      bladeCount: 7,
                      edgeTint: value ? palette.ember : palette.inkFaint,
                      bladeBase: palette.canvas,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: palette.bodyStrong.copyWith(
                      color: value ? palette.ink : palette.inkSoft,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: EmberSwitch(
            key: const Key('reminder-delete-after-switch'),
            value: value,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

/// Bölümleri ayıran saç teli. Kutu yerine çizgi: sayfanın kendisi zaten bir
/// yüzey, her bölümü ayrıca çerçevelemek sınır sayısını artırmaktan başka bir
/// şey yapmıyor.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.hairline,
    child: const SizedBox(height: 1, width: double.infinity),
  );
}

/// Günün hangi saatinde hatırlatılacağı.
///
/// Çark (`CupertinoPicker`) yerine yazılan iki sayı: çark bu tasarım diline
/// yabancı bir malzeme ve iki basamağı bulmak için parmakla nişan almayı
/// gerektiriyor. Rakamlar burada ekranın en büyük tipografisi ve sayfanın
/// ekseninde duruyor — dokunulacak yerin nerede olduğu ayrıca söylenmiyor,
/// görülüyor. Altlarındaki çentik ızgaradaki seçili günün çentiğiyle aynı.
class ReminderClock extends StatefulWidget {
  const ReminderClock({
    super.key,
    required this.value,
    required this.now,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime now;
  final ValueChanged<DateTime> onChanged;

  @override
  State<ReminderClock> createState() => _ReminderClockState();
}

class _ReminderClockState extends State<ReminderClock> {
  late final TextEditingController _hourField = TextEditingController(
    text: _twoDigits(widget.value.hour),
  );
  late final TextEditingController _minuteField = TextEditingController(
    text: _twoDigits(widget.value.minute),
  );
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();

  /// Yazılan saat geçmişte kalıyor ya da okunamıyor. Yalnızca görsel: kayda
  /// geçersiz bir an yazılmıyor, rakamlar tehlike rengine dönüyor.
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _hourFocus.addListener(() => _syncField(_hourFocus, _hourField, true));
    _minuteFocus.addListener(
      () => _syncField(_minuteFocus, _minuteField, false),
    );
  }

  @override
  void dispose() {
    _hourField.dispose();
    _minuteField.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReminderClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hazır saatlerden biri seçildiyse ya da gün değişince saat uzlaştıysa
    // alanlar da onu göstersin. Kullanıcı yazarken araya girilmiyor: kendi
    // rakamının altından değişen bir alan, yazmayı imkânsız kılardı.
    if (widget.value != oldWidget.value &&
        !_hourFocus.hasFocus &&
        !_minuteFocus.hasFocus) {
      _hourField.text = _twoDigits(widget.value.hour);
      _minuteField.text = _twoDigits(widget.value.minute);
      if (_invalid) _invalid = false;
    }
  }

  /// Odaklanınca rakamların tamamı seçilir, odak gidince iki haneye tamamlanır.
  ///
  /// Seçmeden alan iki haneliyken yazmak hiçbir şey yapmıyordu: uzunluk sınırı
  /// yeni rakamı yutuyor, kullanıcı önce silmek zorunda kalıyordu. Odak
  /// bırakıldığında da "7" değil "07" görünmeli; sayı hizası bozulmasın.
  void _syncField(FocusNode focus, TextEditingController field, bool isHour) {
    if (focus.hasFocus) {
      field.selection = TextSelection(
        baseOffset: 0,
        extentOffset: field.text.length,
      );
      setState(() {});
      return;
    }
    final typed = int.tryParse(field.text);
    final fallback = isHour ? widget.value.hour : widget.value.minute;
    field.text = _twoDigits(
      typed == null || typed > (isHour ? 23 : 59) ? fallback : typed,
    );
    setState(() => _invalid = false);
  }

  void _applyTyped() {
    final hour = int.tryParse(_hourField.text);
    final minute = int.tryParse(_minuteField.text);
    final day = reminderDayOf(widget.value);

    // Saat iki haneye doldu: sıra dakikada. Bu, anın geçerli olup olmadığından
    // **önce** geliyor: bugün 18:04'te "18" yazan biri henüz 18:00'ı, yani
    // geçmişi yazmış oluyor. Geçerliliği bekleseydik odak saatte kalır, iki
    // hane dolu olduğu için yeni rakam da girilemez ve kullanıcı kırmızı bir
    // alanda kilitlenirdi — oysa düzeltecek olan zaten dakika.
    if (_hourFocus.hasFocus &&
        _hourField.text.length == 2 &&
        hour != null &&
        hour <= 23) {
      _minuteFocus.requestFocus();
    }

    if (hour == null || minute == null || hour > 23 || minute > 59) {
      setState(() => _invalid = true);
      return;
    }
    final moment = reminderMomentOf(day, TimeOfDay(hour: hour, minute: minute));
    if (!moment.isAfter(widget.now)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    widget.onChanged(moment);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          context.l10n.upper(context.l10n.reminderTimeLabel),
          style: palette.overline,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Digits(
              name: 'hour',
              controller: _hourField,
              focus: _hourFocus,
              invalid: _invalid,
              semanticLabel: MaterialLocalizations.of(
                context,
              ).timePickerHourLabel,
              onChanged: _applyTyped,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                ':',
                style: palette.display.copyWith(
                  color: _invalid ? palette.danger : palette.inkFaint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _Digits(
              name: 'minute',
              controller: _minuteField,
              focus: _minuteFocus,
              invalid: _invalid,
              semanticLabel: MaterialLocalizations.of(
                context,
              ).timePickerMinuteLabel,
              onChanged: _applyTyped,
            ),
          ],
        ),
      ],
    );
  }
}

/// İki basamak ve altındaki çentik. Kutu yok: alanın sınırı, yazılan sayının
/// altındaki çizgi — ızgaradaki seçili günün çentiğiyle aynı işaret.
class _Digits extends StatelessWidget {
  const _Digits({
    required this.name,
    required this.controller,
    required this.focus,
    required this.invalid,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String name;
  final TextEditingController controller;
  final FocusNode focus;
  final bool invalid;
  final String semanticLabel;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = invalid ? palette.danger : palette.ink;
    final scaler = MediaQuery.textScalerOf(context);
    final width = math.max(52.0, scaler.scale(34) * 1.25);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: Semantics(
            label: semanticLabel,
            textField: true,
            child: TextField(
              key: Key('reminder-time-$name'),
              controller: controller,
              focusNode: focus,
              onChanged: (_) => onChanged(),
              onTapOutside: (_) => focus.unfocus(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              keyboardAppearance: palette.brightness,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              style: palette.display.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              cursorColor: palette.ember,
              cursorWidth: 2,
              cursorHeight: 30,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.only(bottom: 6),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          width: width,
          height: 2,
          color: invalid
              ? palette.danger
              : focus.hasFocus
              ? palette.ember
              : palette.hairlineBright,
        ),
      ],
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
