import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_palette.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../widgets/reminder_control.dart';
import 'photo_dismiss_surface.dart';
import '../../../../../l10n/l10n_context.dart';
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
  });

  final Note note;
  final NotesRepository repository;
  final EditNoteController controller;
  final VoidCallback onSaved;

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

  ValueListenable<bool> get saving => _saving;
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

  void _attach(_EditNoteSheetState editor) => _editor = editor;

  void _detach(_EditNoteSheetState editor) {
    if (identical(_editor, editor)) _editor = null;
  }

  void dispose() => _saving.dispose();
}

class _EditNoteSheetState extends State<EditNoteSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note.body,
  );
  late final FocusNode _focus = FocusNode();
  late int _remindAfterDays = widget.note.remindAfterDays;
  late bool _remindRepeats = widget.note.remindRepeats;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
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

  /// Boş alana dokunmak yazmaya devam etmek demek: odak alana geçer ve imleç
  /// yazının **sonuna** gider. Metnin başına atlamak, yarım kalmış bir notu
  /// sürdürmek isteyen için yanlış yer olurdu.
  void _focusBody() {
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    _focus.requestFocus();
  }

  bool get _hasChanges =>
      _text.text != widget.note.body ||
      _remindAfterDays != widget.note.remindAfterDays ||
      _remindRepeats != widget.note.remindRepeats;

  Future<bool> _persist({required bool closeEditor}) async {
    if (widget.controller.isSaving) return false;

    if (!_hasChanges) {
      if (closeEditor) widget.onSaved();
      return true;
    }

    widget.controller._setSaving(true);

    try {
      await widget.repository.update(
        widget.note,
        body: _text.text,
        remindAfterDays: _remindAfterDays,
        remindRepeats: _remindRepeats,
      );
    } catch (_) {
      if (!mounted) return false;
      widget.controller._setSaving(false);
      showToast(context, context.l10n.toastEditFailed, error: true);
      return false;
    }

    if (!mounted) return true;
    widget.controller._setSaving(false);
    if (closeEditor) {
      widget.onSaved();
    }
    return true;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: TextField(
              key: const ValueKey('edit-note-body-field'),
              controller: _text,
              focusNode: _focus,
              // Yazı alanı ilk bakışta yazı alanı gibi dursun. İki satırlık
              // bir kutu, altındaki koca boşlukla birlikte "asıl alan aşağıda"
              // izlenimi veriyordu.
              minLines: 4,
              maxLines: null,
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
          // Metnin altındaki sessiz alan artık **metin alanının kendisine**
          // ait: dokunulduğunda imleç yazının sonuna gider. Eskiden burası
          // hiçbir şeye bağlı değildi ve dokunulunca hiçbir şey olmuyordu —
          // oysa görünüşü tam olarak "yazı buraya" diyordu.
          //
          // Alan `expands: true` ile alanın kendisine verilmedi: klavye
          // açıkken sliver'ın kalan yüksekliği sabit künye ve rayla
          // dolduğundan alan sıfıra iniyordu. Esnek boşluk hem yazma alanının
          // en küçük boyunu korur hem de uzun metinde sıfıra inip sayfanın
          // doğal biçimde kaymasına izin verir.
          Expanded(
            child: GestureDetector(
              key: const ValueKey('edit-note-body-overflow'),
              behavior: HitTestBehavior.opaque,
              onTap: _focusBody,
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              context.l10n.upper(context.l10n.stamp(widget.note.createdAt)),
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
            child: ReminderControl(
              days: _remindAfterDays,
              repeats: _remindRepeats,
              prominent: true,
              onChanged: (value) => setState(() => _remindAfterDays = value),
              onRepeatsChanged: (value) =>
                  setState(() => _remindRepeats = value),
            ),
          ),
          // Sabit alt eylem rayı içeriğin üstünde yüzmez. Bu pay, kısa notta
          // hatırlatmayı rayın hemen üstünde tutar; uzun notta ise içerikle
          // birlikte doğal biçimde kayar.
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
            SizedBox(
              height: _actionsExtent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ValueListenableBuilder<bool>(
                  valueListenable: controller.saving,
                  builder: (context, saving, _) => Row(
                    children: [
                      Expanded(
                        child: _TextAction(
                          key: const ValueKey('edit-action-cancel'),
                          label: context.l10n.actionCancel,
                          color: palette.inkSoft,
                          alignment: AlignmentDirectional.centerStart,
                          onPressed: saving ? null : onCancel,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TextAction(
                          key: const ValueKey('edit-action-save'),
                          label: context.l10n.actionSave,
                          color: palette.ember,
                          alignment: AlignmentDirectional.centerEnd,
                          busy: saving,
                          onPressed: saving
                              ? null
                              : () => controller.saveAndClose(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: _bottomInsetOf(context)),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    super.key,
    required this.label,
    required this.color,
    required this.alignment,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final Color color;
  final AlignmentGeometry alignment;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      scale: 0.96,
      child: SizedBox.expand(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: busy
                  ? SizedBox.square(
                      key: const ValueKey('edit-note-saving'),
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: color,
                      ),
                    )
                  : Text(
                      label,
                      key: ValueKey(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.palette.label.copyWith(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
