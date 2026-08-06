import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/tr_format.dart';
import '../../../../../shared/widgets/glass_surface.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';

/// Fotoğrafın altında duran bilgi paneli: zaman, not metni ve saklama durumu.
class DetailSheet extends StatelessWidget {
  const DetailSheet({super.key, required this.note, required this.onEdit});

  final Note note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasBody = note.body.isNotEmpty;

    return GlassSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      blur: 34,
      tint: OnPhoto.canvasDeep.withValues(alpha: 0.52),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  TrFormat.upper(TrFormat.stamp(note.createdAt)),
                  style: OnPhotoText.overline,
                ),
              ),
              Pressable(
                onPressed: onEdit,
                scale: 0.94,
                semanticLabel: 'Notu düzenle',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: OnPhoto.hairlineBright),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: OnPhoto.inkSoft,
                      ),
                      const SizedBox(width: 6),
                      Text('Düzenle', style: OnPhotoText.caption),
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
                ? '${note.retention.label} · ${TrFormat.remainingLong(expiresAt)}'
                : 'Otomatik silme kapalı — bu not kalıcı.',
            style: OnPhotoText.caption.copyWith(
              color: timed ? OnPhoto.inkSoft : OnPhoto.inkFaint,
            ),
          ),
        ),
      ],
    );
  }
}
