import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/enum_labels.dart';
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

  /// Kayıtta zaten duran silme sözü — kullanıcı bunu daha önce verdi mi.
  ///
  /// Çağıranın söylemesi şart. Sayfa notu diskten de okuyor ama o okuma bir
  /// kare geç geliyor; bu arada Kaydet'e basan biri, hiç dokunmadığı sözü
  /// kapalı hâliyle geri yazardı. [NotesRepository.setReminder] kapalı gelen
  /// sözde hatırlatmadan türeyen silinme anını temizliyor — yani eksik
  /// geçilen bu tek bayrak, verilmiş bir sözü sessizce siler.
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
        cadence: widget.initial.cadence,
        now: _now,
      ) ??
      _defaultMoment;

  late ReminderCadence _cadence = widget.initial.cadence;

  /// Takvimdeki gün **gerçek bir seçim** mi, yoksa ekranın önerisi mi?
  ///
  /// Ekran boş bir takvimle karşılamıyor, "yarın aynı saatte" diye açılıyor.
  /// Ama bu bir öneri; kullanıcı ona bakıp yalnız saati yazdığında niyeti
  /// "yarın" değil, "yazdığım saatte" oluyordu. Öneri gün olarak sessizce
  /// kaldığı için "bir dakika sonra" dediğini sanan biri hatırlatmasını yirmi
  /// dört saat sonrasına kuruyordu — hata vermeden, ekranda bir şey değişmeden.
  ///
  /// Bu yüzden gün iki hâlde "çivili" sayılıyor: takvimden dokunulduğunda ve
  /// kayıtta zaten bir hatırlatma varken (o günü kullanıcı daha önce seçmiş).
  /// Çivili değilse yazılan saat, o saatin **bir sonraki** oluşumuna çözülür.
  late bool _dayPinned = widget.initial.isOn;

  /// "Hatırlattıktan bir saat sonra sil."
  late bool _deleteAfter = widget.initialDeleteAfter;

  bool _saving = false;
  bool _flowClosed = false;

  NotesRepository? _repository;
  Future<Note?>? _note;

  /// Diskten okunan kayıt. Tek soruyu cevaplıyor: kaydın kendi saklama süresi
  /// var mı. Hatırlatmanın kendisi buradan okunmuyor — onu çağıran veriyor ve
  /// kullanıcı bu ekranda değiştiriyor olabilir.
  Note? _loaded;

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
    _note = repository.noteById(widget.noteId)
      ..then(
        (note) {
          if (!mounted) return;
          setState(() => _loaded = note);
        },
        // Cascade türetilen future'ı yutuyor: hata dinleyicisiz kalırsa
        // bölgeye "yakalanmamış" olarak düşer. Künyedeki `FutureBuilder`
        // aynı okumayı zaten karşılıyor, burada susmak yeterli.
        onError: (Object _) {},
      );
  }

  /// Silme sözü bu kayıtta sunuluyor mu.
  ///
  /// Artık **her kayıtta**. Bir süre yalnız karesiz notlara sunuldu; gerekçe
  /// güvenilirlik değil sonuçtu — silinen kare geri getirilemez, metin yeniden
  /// yazılabilir.
  ///
  /// İki şey o çekinceyi kaldırdı. Silme yolu fotoğrafı eksiksiz topluyor
  /// (işlenmiş kare, küçük kopyası, saklanmışsa orijinali ve onun kopyası,
  /// bildirime iliştirilen kopya, arama satırı, Spotlight kaydı) ve bu tam
  /// olarak `notes_repository_test.dart` içinde **kareli** bir kayıtla
  /// sınanıyor. İkincisi ve daha önemlisi: söz verilen kayıtta `expiresAt`
  /// doluyor, kart da kalan ömrü diyaframıyla gösteriyor — kullanıcı arşivine
  /// baktığında o karenin gideceğini görüyor, sürprizle karşılaşmıyor.
  bool get _offersDeleteAfter => _loaded != null || _deleteAfter;

  /// Söz yalnız tek atışta ayakta. Tekrarlı bir hatırlatmayı ilk bildirimden
  /// sonra silmek, verilen sözün kendisini yerdi.
  bool get _promisesDelete => _deleteAfter && _cadence == ReminderCadence.once;

  /// Sözün, notun **kendi** saklama süresinin yerine geçtiği hâl.
  ///
  /// Kaydın hâlihazırdaki silinme anı hatırlatmadan türemiyorsa kullanıcı onu
  /// ayrıca seçmiş demektir; söz o süreyi kısaltabilir de uzatabilir de.
  /// Sessiz kalmasın diye anahtarın altında yazıyor.
  bool get _replacesRetention {
    final note = _loaded;
    if (note == null || note.expiresAt == null) return false;
    return !isReminderExpiry(
      remindAt: note.remindAt,
      expiresAt: note.expiresAt,
    );
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

  DateTime _momentForCadence(DateTime at, ReminderCadence cadence) {
    if (cadence != ReminderCadence.daily && cadence != ReminderCadence.weekly) {
      return at;
    }
    return nextNativeRepeatAt(pattern: at, now: _now, cadence: cadence);
  }

  void _selectMoment(DateTime at) {
    setState(() => _at = _momentForCadence(at, _cadence));
  }

  /// Takvimden gün seçmek öneriyi karara çevirir.
  void _selectDay(DateTime at) {
    _dayPinned = true;
    _selectMoment(at);
  }

  /// Ritim tarihten türetilmiyor, doğrudan seçiliyor.
  ///
  /// Eskiden tekrar tek bir anahtardı ve aralık "bugünden seçilen güne kaç gün
  /// var" diye hesaplanıyordu. 1 Eylül'ü seçip tekrarı açan biri "her ay"
  /// demek isterken kayıt "her 24 günde bir" oluyor, sonraki oluşum da 25
  /// Eylül'e kayıyordu — kimsenin kastetmediği bir ritim. Tarih dizinin
  /// **başladığı** an, ritim ise nasıl yineleneceği.
  void _setCadence(ReminderCadence cadence) {
    HapticFeedback.selectionClick();
    setState(() {
      _cadence = cadence;
      _at = _momentForCadence(_at, cadence);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();

    final navigator = Navigator.of(context);
    try {
      final saved = await _repository!.setReminder(
        widget.noteId,
        ReminderChoice(at: _at, cadence: _cadence),
        deleteAfterReminder: _promisesDelete,
      );
      if (!saved) {
        if (!mounted) return;
        setState(() => _saving = false);
        showToast(context, context.l10n.reminderFreeSpent, error: true);
        return;
      }
    } on ReminderAfterExpiryException {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, context.l10n.reminderAfterExpiry, error: true);
      return;
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
    final isPro = AppScope.preferences(context).proUnlocked;
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
                            onChanged: _selectDay,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Rule(),
                              const SizedBox(height: 18),
                              ReminderClock(
                                value: _at,
                                now: _now,
                                dayPinned: _dayPinned,
                                onChanged: _selectMoment,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Rule(),
                              const SizedBox(height: 18),
                              // Ritim, uygulamanın her yerdeki seçim rayında.
                              // Sonucun cümlesi kaydetmenin hemen üstünde
                              // zaten yazıyor — rayın altına ikinci kez
                              // yazmak aynı şeyi iki kere söylemek olurdu.
                              // Ücretsiz katmanda yalnız "Bir kez".
                              //
                              // Hak "üç bildirim" demek; tekrarlı bir
                              // hatırlatma tek hakla sınırsız bildirim
                              // üretirdi. Diğer ritimleri kilitli göstermek
                              // yerine hiç göstermiyoruz: rayda dokunulamayan
                              // dört seçenek, verilmeyen bir sözün reklamı
                              // olurdu.
                              ChoiceRail<ReminderCadence>(
                                key: const Key('reminder-cadence-rail'),
                                options: isPro
                                    ? ReminderCadence.values
                                    : const [ReminderCadence.once],
                                value: _cadence,
                                onChanged: _setCadence,
                                labelOf: (cadence) => switch (cadence) {
                                  ReminderCadence.once =>
                                    l10n.reminderCadenceOnce,
                                  ReminderCadence.daily =>
                                    l10n.reminderCadenceDaily,
                                  ReminderCadence.weekly =>
                                    l10n.reminderCadenceWeekly,
                                  ReminderCadence.monthly =>
                                    l10n.reminderCadenceMonthly,
                                  ReminderCadence.yearly =>
                                    l10n.reminderCadenceYearly,
                                },
                              ),
                              // Söz yalnız "Bir kez"de duruyor, ama yeri
                              // ritimden bağımsız ayrılıyor. Eskiden satır
                              // katlanıp açılıyordu ve sayfa her ritim
                              // dokunuşunda zıplıyordu — üstteki üç bölüm
                              // artan yeri paylaştığı için kaybolan satır
                              // takvimi de saati de yerinden oynatıyordu.
                              // Yer sabit kalınca yalnız satırın kendisi
                              // sönüyor.
                              if (_offersDeleteAfter)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: _DeleteAfterSlot(
                                    shown: _cadence == ReminderCadence.once,
                                    value: _deleteAfter,
                                    replacesRetention: _replacesRetention,
                                    onChanged: (value) =>
                                        setState(() => _deleteAfter = value),
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
                // Cümle **iki satırlık** yer tutuyor, bir satırlık değil.
                //
                // "Bir kez" seçiliyken tek satır ("27 Ağustos 21:30"), ritim
                // seçilince iki satır oluyordu ("Her hafta · sonraki …") ve
                // aradaki fark üstteki kaydırma alanını kısaltıp ritim rayını
                // her seçimde aşağı kaydırıyordu. Sabit yer, rayı yerine
                // çiviliyor; iki satıra çıkmayan diller de aynı hizada kalıyor.
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(16) * 1.32 * 2,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        _cadence.sentence(
                          l10n,
                          at: _at,
                          use24Hour: context.use24Hour,
                          deleteAfter: _promisesDelete,
                        ),
                        key: ValueKey((_at, _cadence, _promisesDelete)),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: palette.bodyStrong.copyWith(
                          color: palette.ember,
                        ),
                      ),
                    ),
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

/// Silme sözünün yeri: ritim ne olursa olsun ayrılıyor, yalnız "Bir kez"de
/// doluyor.
///
/// Katlanıp açılan bir satır değil — üstteki üç bölüm artan yeri paylaştığı
/// için katlanma takvimi ve saati de oynatıyordu. Yer sabit, sönen tek şey
/// satırın kendisi; sönükken ne dokunuşu ne de ekran okuyucuyu karşılıyor.
class _DeleteAfterSlot extends StatelessWidget {
  const _DeleteAfterSlot({
    required this.shown,
    required this.value,
    required this.replacesRetention,
    required this.onChanged,
  });

  final bool shown;
  final bool value;
  final bool replacesRetention;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !shown,
    child: ExcludeSemantics(
      excluding: !shown,
      child: AnimatedOpacity(
        key: const Key('reminder-delete-after-slot'),
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        opacity: shown ? 1 : 0,
        child: _DeleteAfterRow(
          value: value,
          replacesRetention: replacesRetention,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

/// "Hatırlattıktan 1 saat sonra sil."
///
/// Soldaki işaret bir ikon değil, uygulamanın kendi irisi: söz verildiğinde
/// kapanmaya başlar. Aynı iris not detayında kalan ömrü, silme onayında da
/// kararın kendisini gösteriyor — üç ekran tek bir cümle kuruyor.
class _DeleteAfterRow extends StatelessWidget {
  const _DeleteAfterRow({
    required this.value,
    required this.replacesRetention,
    required this.onChanged,
  });

  final bool value;

  /// Notun kendi saklama süresi var ve söz onun yerine geçiyor.
  final bool replacesRetention;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final label = l10n.reminderDeleteAfterLabel;
    // Açıklama yalnız gerçekten bir şeyin yerine geçen kayıtta var. Sözün ne
    // yaptığı adından belli; her notta bir satır daha yazmak, okunması
    // gereken tek uyarıyı da gürültüye çevirirdi.
    //
    // Yeri anahtardan bağımsız ayrılıyor, görünürlüğü ona bağlı: metni
    // dokunuşla var edip yok etmek satırı büyütüp küçültür, o da üstündeki
    // takvimi oynatırdı.
    final detail = replacesRetention ? l10n.reminderDeleteAfterOverride : null;

    // Satırın tamamı **tek** bir anahtar: adı, durumu ve eylemi aynı düğümde.
    // Önceden dıştaki dokunuş yüzeyi adsız bir düğme olarak ayrı listeleniyor,
    // içindeki anahtar da ikinci bir denetim gibi okunuyordu — aynı işi yapan
    // iki öğe.
    return Semantics(
      key: const Key('reminder-delete-after-row'),
      toggled: value,
      label: detail == null ? label : '$label. $detail',
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: NoteOptionRow(
          label: ExcludeSemantics(
            child: NoteOptionLabel(
              title: label,
              detail: detail,
              detailVisible: value,
              active: value,
              // Yuvada ikon değil uygulamanın kendi irisi duruyor: söz
              // verildiğinde kapanmaya başlıyor. Aynı iris not detayında
              // kalan ömrü, silme onayında da kararın kendisini gösteriyor —
              // üç ekran tek bir cümle kuruyor.
              leading: AnimatedSwitcher(
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
    this.dayPinned = true,
  });

  final DateTime value;
  final DateTime now;
  final ValueChanged<DateTime> onChanged;

  /// Gün kullanıcının kararıysa yazılan saat o günün üstüne biner. Gün yalnız
  /// ekranın önerisiyse yazılan saat kendi gününü seçer: bugün hâlâ o saate
  /// varılıyorsa bugün, varılmıyorsa yarın.
  final bool dayPinned;

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

  /// Yazılan saat geçmişte kalıyor ya da okunamıyor. Kayda geçersiz bir an
  /// yazılmıyor; görsel işaretin yanında VoiceOver'a doğrulama durumu ve canlı
  /// hata duyurusu da veriliyor.
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
    final time = TimeOfDay(hour: hour, minute: minute);
    final moment = widget.dayPinned
        ? reminderMomentOf(day, time)
        : _nextOccurrenceOf(time);
    if (!moment.isAfter(widget.now)) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    widget.onChanged(moment);
  }

  /// Yazılan saatin bir sonraki oluşumu — çalar saat mantığı.
  DateTime _nextOccurrenceOf(TimeOfDay time) {
    final today = reminderDayOf(widget.now);
    final onToday = reminderMomentOf(today, time);
    return onToday.isAfter(widget.now)
        ? onToday
        : reminderMomentOf(shiftLocalCalendarDays(today, 1), time);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.upper(context.l10n.reminderTimeLabel),
              style: palette.overline,
            ),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: _invalid
                  ? Semantics(
                      key: const Key('reminder-time-invalid-mark'),
                      container: true,
                      liveRegion: true,
                      label: MaterialLocalizations.of(context).invalidTimeLabel,
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: palette.danger,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
            validationResult: invalid
                ? SemanticsValidationResult.invalid
                : SemanticsValidationResult.none,
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
