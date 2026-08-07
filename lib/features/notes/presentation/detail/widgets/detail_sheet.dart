import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../shared/widgets/glass_surface.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../l10n/enum_labels.dart';
import '../../../../../core/utils/app_format.dart';

/// Fotoğrafın altında duran bilgi paneli: zaman, not metni ve saklama durumu.
class DetailSheet extends StatelessWidget {
  const DetailSheet({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onShare,
  });

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final hasBody = note.body.isNotEmpty;

    return GlassSurface(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppShape.panel),
      ),
      tint: OnPhoto.canvasDeep.withValues(alpha: 0.96),
      borderColor: OnPhoto.hairlineBright,
      elevation: 24,
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sürükleme tutamacı yoktu ve olmamalı: bu panel sürüklenmiyor.
          // Hiçbir işi olmayan bir denetim, arayüzü kalabalıklaştırmaktan
          // başka bir şey yapmıyordu.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                onPressed: onShare,
                scale: 0.94,
                semanticLabel: context.l10n.shareNoteSemantic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ios_share_outlined,
                        size: 14,
                        color: OnPhoto.inkSoft,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.actionShare,
                        style: OnPhotoText.label.copyWith(
                          color: OnPhoto.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Pressable(
                onPressed: onEdit,
                scale: 0.94,
                semanticLabel: context.l10n.editNoteSemantic,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: OnPhoto.ember,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.actionEdit,
                        style: OnPhotoText.label.copyWith(color: OnPhoto.ember),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasBody) ...[
            const SizedBox(height: 14),
            // Uzun notlar paneli ekranın yarısından fazlasını kaplamasın.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.26,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  note.body,
                  style: OnPhotoText.body.copyWith(fontSize: 17),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const ColoredBox(
            color: OnPhoto.hairline,
            child: SizedBox(height: 0.5, width: double.infinity),
          ),
          const SizedBox(height: 14),
          _RetentionLine(note: note),
        ],
      ),
    );
  }
}

class _RetentionLine extends StatelessWidget {
  const _RetentionLine({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final expiresAt = note.expiresAt;
    final timed = expiresAt != null;

    return Row(
      children: [
        Icon(
          timed ? Icons.timelapse_rounded : Icons.all_inclusive_rounded,
          size: 15,
          color: timed ? OnPhoto.ember : OnPhoto.inkFaint,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            timed
                ? '${note.retention.label(context.l10n)} · '
                      '${context.l10n.remainingLong(expiresAt)}'
                : context.l10n.retentionOffNotice,
            style: OnPhotoText.caption.copyWith(
              color: timed ? OnPhoto.inkSoft : OnPhoto.inkFaint,
            ),
          ),
        ),
      ],
    );
  }
}
