import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../../domain/note_reminder.dart';
import '../../widgets/reminder_control.dart';
import 'photo_dismiss_surface.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/colophon_bar.dart';
import '../../../../../core/utils/app_format.dart';

/// Detay marjının yerinde düzenleme hâli.
///
/// Ayrı bir modal yüzey açılmaz. Kullanıcının okuduğu metin aynı koordinatta
/// bir yazı alanına dönüşür; fotoğraf yalnızca klavyeye yer açar. Böylece
/// "başka bir form" değil, doğrudan aynı nota müdahale ediliyormuş gibi olur.
class EditNoteSheet extends StatefulWidget {
  const EditNoteSheet({
    super.key,
    required this.note,
    required this.repository,
    required this.controller,
    required this.onSaved,
    required this.onScheduleReminder,
  });

  final Note note;
  final NotesRepository repository;
  final EditNoteController controller;
  final VoidCallback onSaved;

  /// Anahtar açıkken kaydetmenin ikinci yarısı: gün, saat ve tekrar kararı.
  /// Rotayı sayfa açıyor — panel kendi ayağının altındaki zemini çekemez.
  final ValueChanged<ReminderChoice> onScheduleReminder;

  @override
  State<EditNoteSheet> createState() => _EditNoteSheetState();
}

/// Fotoğrafla interaktif kapatma başladığında editördeki değerleri
/// güvenle kalıcılaştırmak için sayfa ile editör arasındaki dar köprü.
///
/// Kaydetme mantığı ve alanların sahibi yine [EditNoteSheet]. Sayfanın metin
/// controller'larını devralmasına gerek kalmadan, kapatma hareketinin
/// kaydedilmemiş bir değişikliği sessizce kaybetmesi engellenir.
class EditNoteController {
  _EditNoteSheetState? _editor;
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  final ValueNotifier<bool> _remindMe = ValueNotifier(false);

  ValueListenable<bool> get saving => _saving;

  /// Hatırlatma anahtarının hâli. Alt eylem şeridi panelin dışında duruyor
  /// ama kelimesi panelin kararına bağlı: anahtar açıkken "Kaydet" tek başına
  /// yalan söylerdi, arkasından bir ekran daha geliyor.
  ValueListenable<bool> get remindMe => _remindMe;

  bool get isSaving => _saving.value;

  Future<bool> saveForDismiss() {
    final editor = _editor;
    if (editor == null) return Future<bool>.value(false);
    return editor._persist(closeEditor: false);
  }

  Future<bool> saveAndClose() {
    final editor = _editor;
    if (editor == null) return Future<bool>.value(false);
    return editor._persist(closeEditor: true);
  }

  void _setSaving(bool value) {
    if (_saving.value != value) _saving.value = value;
  }

  void _setRemindMe(bool value) {
    if (_remindMe.value != value) _remindMe.value = value;
  }

  void _attach(_EditNoteSheetState editor) => _editor = editor;

  void _detach(_EditNoteSheetState editor) {
    if (identical(_editor, editor)) _editor = null;
  }

  void dispose() {
    _saving.dispose();
    _remindMe.dispose();
  }
}

class _EditNoteSheetState extends State<EditNoteSheet> {
  /// Yazı alanının pes etmeyeceği taban. Künye ve hatırlatma ne kadar
  /// uzarsa uzasın, yazacak yer bunun altına inmiyor.
  static const double _minBodyExtent = 120;

  late final TextEditingController _text = TextEditingController(
    text: widget.note.body,
  );
  late final FocusNode _focus = FocusNode();

  /// Notun kayıtlı hatırlatması. Panel bunu değiştirmiyor; yalnızca planlama
  /// ekranına başlangıç değeri olarak taşıyor.
  late final ReminderChoice _reminder = ReminderChoice(
    at: widget.note.remindAt,
    everyDays: widget.note.remindEveryDays,
  );

  /// Kullanıcı bu kare için hatırlatma istiyor mu.
  late bool _remindMe = widget.note.remindAt != null;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      // Şerit bu kareyi çizerken haber vermek "build sırasında setState"
      // olurdu; kelime bir kare sonra, henüz ekranın dışındayken yerine
      // oturuyor.
      widget.controller._setRemindMe(_remindMe);
    });
  }

  @override
  void didUpdateWidget(EditNoteSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller._detach(this);
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _text.text != widget.note.body ||
      _remindMe != (widget.note.remindAt != null);

  /// Kaydedilecek hatırlatma. Anahtar kapalıysa kayıtlı olan da silinir;
  /// açıksa kayıtlı değer korunur ve gerisini planlama ekranı yazar.
  ReminderChoice get _effectiveReminder =>
      _remindMe ? _reminder : const ReminderChoice.off();

  void _setRemindMe(bool value) {
    setState(() => _remindMe = value);
    widget.controller._setRemindMe(value);
  }

  Future<bool> _persist({required bool closeEditor}) async {
    if (widget.controller.isSaving) return false;

    if (!_hasChanges) {
      if (closeEditor) _finish();
      return true;
    }

    widget.controller._setSaving(true);

    try {
      await widget.repository.update(
        widget.note,
        body: _text.text,
        reminder: _effectiveReminder,
      );
    } catch (_) {
      if (!mounted) return false;
      widget.controller._setSaving(false);
      showToast(context, context.l10n.toastEditFailed, error: true);
      return false;
    }

    if (!mounted) return true;
    widget.controller._setSaving(false);
    if (closeEditor) _finish();
    return true;
  }

  /// Yazma bağlamını kapatır; anahtar açıksa kararın ikinci yarısına geçer.
  void _finish() {
    widget.onSaved();
    if (_remindMe) widget.onScheduleReminder(_reminder);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      key: const ValueKey('edit-note-sheet-surface'),
      color: palette.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Yazı alanı kalan yeri kaplar ve **kendi içinde** kayar. Eskiden
          // metinle birlikte uzuyordu: künye, hatırlatma ve ray aşağı kayıyor,
          // uzun bir notta seçenekler ekrandan çıkıyordu. Uzayan şey artık
          // düzen değil, metin.
          //
          // Altındaki sessiz boşluk da alanın kendisine ait: dokunulan yere
          // imleç gidiyor, ayrı bir "boşluğa dokunma" hilesi gerekmiyor.
          //
          // Taban `ConstrainedBox` ile veriliyor. Paneli saran sliver boyunu
          // çocuğun *doğal* yüksekliğinden hesapladığı için bu taban aynı
          // zamanda panelin en küçük boyuna giriyor: künye ve hatırlatma
          // sığmıyorsa alan sıfıra inmiyor, sayfa kayıyor.
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minBodyExtent),
              // Alan `Positioned.fill` ile yerleştiriliyor: konumlandırılmış
              // çocuklar intrinsic hesabına girmez. Paneli saran sliver boyunu
              // çocuğun doğal yüksekliğinden hesapladığı için, aksi hâlde
              // metnin boyu panelin boyu olurdu — tam da kaçındığımız şey.
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                      child: TextField(
                        key: const ValueKey('edit-note-body-field'),
                        controller: _text,
                        focusNode: _focus,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        keyboardAppearance: palette.brightness,
                        style: palette.title.copyWith(
                          fontSize: 23,
                          height: 1.24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.55,
                        ),
                        cursorColor: palette.ember,
                        cursorWidth: 2,
                        cursorRadius: const Radius.circular(1),
                        decoration: InputDecoration.collapsed(
                          hintText: context.l10n.composeHint,
                          hintStyle: palette.title.copyWith(
                            fontSize: 23,
                            height: 1.24,
                            color: palette.inkGhost,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              context.l10n.upper(
                context.l10n.stamp(
                  widget.note.createdAt,
                  use24Hour: context.use24Hour,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: palette.overline.copyWith(
                color: palette.inkFaint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ColoredBox(
              color: palette.hairline,
              child: const SizedBox(height: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            // Etiket tarafı compose ile aynı dili konuşur: ikon, başlık ve
            // altında ne işe yaradığını söyleyen bir satır. Sağdaki kontrol
            // değişmiyor — iki ekranda aynı alanın iki farklı görünmesi için
            // bir sebep yok.
            child: ReminderControl(value: _remindMe, onChanged: _setRemindMe),
          ),
          // Sabit alt eylem rayı içeriğin üstünde yüzmez.
          SizedBox(height: EditNoteActionRail.extentOf(context) + 16),
        ],
      ),
    );
  }
}

/// Düzenleme eylemleri ekranın alt kenarında sabit kalır.
///
/// Üstteki dar tutamak yalnız kapatma hareketine ayrıldığı için aşağı çekme,
/// metin seçimi veya hatırlatma alanının yatay/dokunma hareketleriyle çakışmaz.
class EditNoteActionRail extends StatelessWidget {
  const EditNoteActionRail({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onDismissed,
    required this.onDismissRequested,
    this.onDismissOffsetChanged,
    this.onDismissProgressChanged,
  });

  static const double _handleExtent = 40;
  static const double _actionsExtent = 54;

  final EditNoteController controller;
  final VoidCallback onCancel;
  final VoidCallback onDismissed;
  final Future<bool> Function() onDismissRequested;
  final ValueChanged<double>? onDismissOffsetChanged;
  final ValueChanged<double>? onDismissProgressChanged;

  static double _bottomInsetOf(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return safeBottom < 10 ? 10 : safeBottom;
  }

  static double extentOf(BuildContext context) =>
      _handleExtent + _actionsExtent + _bottomInsetOf(context);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      key: const ValueKey('edit-action-rail'),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SizedBox(
        height: extentOf(context),
        child: Column(
          children: [
            PullDownDismissRegion(
              key: const ValueKey('edit-pull-down-region'),
              onDismissRequested: onDismissRequested,
              onOffsetChanged: onDismissOffsetChanged,
              onProgressChanged: onDismissProgressChanged,
              onDismissed: onDismissed,
              child: SizedBox(
                height: _handleExtent,
                child: Semantics(
                  label: context.l10n.actionBack,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 3,
                      decoration: BoxDecoration(
                        color: palette.inkGhost,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Not detayının alt şeridiyle aynı künye dili. Rayın kendi üst
            // kenarı zaten sınırı çiziyor, o yüzden şeridin güverte çizgisi
            // kapalı: iki çizgi 40pt arayla üst üste gelince sınır değil,
            // kusur okunuyor.
            ListenableBuilder(
              listenable: Listenable.merge([
                controller.saving,
                controller.remindMe,
              ]),
              builder: (context, _) {
                final saving = controller.saving.value;
                final label = controller.remindMe.value
                    ? context.l10n.actionSaveAndRemind
                    : context.l10n.actionSave;
                return ColophonBar(
                  height: _actionsExtent,
                  rule: false,
                  actions: [
                    ColophonAction(
                      key: const ValueKey('edit-action-cancel'),
                      label: context.l10n.actionCancel,
                      semanticLabel: context.l10n.actionCancel,
                      onPressed: saving ? null : onCancel,
                    ),
                    ColophonAction(
                      key: const ValueKey('edit-action-save'),
                      label: label,
                      semanticLabel: label,
                      accent: true,
                      busy: saving,
                      onPressed: saving ? null : controller.saveAndClose,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: _bottomInsetOf(context)),
          ],
        ),
      ),
    );
  }
}
