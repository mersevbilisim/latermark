import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../../../shared/widgets/glass_surface.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../../domain/retention.dart';
import '../../compose/widgets/note_composer.dart';
import '../../widgets/retention_selector.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../app/app_scope.dart';
import '../../../../paywall/presentation/paywall_host.dart';

/// Kayıtlı bir notun yazısını ve saklama süresini değiştirme paneli.
///
/// Yazı alanı yeni kayıt ekranıyla aynı gövdeyi kullanır ([NoteComposer]);
/// kullanıcı iki yerde aynı şeyi görür.
Future<void> showEditNoteSheet(
  BuildContext context, {
  required Note note,
  required NotesRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: OnPhoto.canvasDeep.withValues(alpha: 0.62),
    isScrollControlled: true,
    builder: (context) => _EditNoteSheet(note: note, repository: repository),
  );
}

class _EditNoteSheet extends StatefulWidget {
  const _EditNoteSheet({required this.note, required this.repository});

  final Note note;
  final NotesRepository repository;

  @override
  State<_EditNoteSheet> createState() => _EditNoteSheetState();
}

class _EditNoteSheetState extends State<_EditNoteSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note.body,
  );
  late RetentionChoice _retention = RetentionChoice(
    widget.note.retention,
    customMinutes: widget.note.customMinutes,
  );
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    try {
      await widget.repository.update(
        widget.note,
        body: _text.text,
        retention: _retention,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, context.l10n.toastEditFailed, error: true);
      return;
    }

    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
      child: GlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(AppShape.panel)),
        tint: palette.canvasLift.withValues(alpha: 0.98),
        borderColor: palette.hairlineBright,
        elevation: 24,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bu panel gerçekten sürükleniyor (modal sheet), tutamaç bir işe
            // yarıyor — detay panelindekinin aksine.
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: palette.inkGhost,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            NoteComposer(
              controller: _text,
              autofocus: true,
              expand: false,
              extra: RetentionSelector(
                value: _retention,
                isPro: AppScope.preferences(context).proUnlocked,
                onLockedTap: () => showPaywall(
                  context,
                  reason: PaywallReason.customRetention,
                ),
                onChanged: (value) => setState(() => _retention = value),
              ),
              header: Text(context.l10n.editSheetHeader, style: palette.overline),
              action: PrimaryButton(
                label: context.l10n.actionSave,
                busy: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
