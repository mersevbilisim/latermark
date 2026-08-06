import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/tr_format.dart';
import '../../../../../shared/widgets/glass_surface.dart';
import '../../../../../shared/widgets/parallax_photo.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../widgets/expiry_badge.dart';
import 'note_photo.dart';

/// Kartın hangi ölçekte çizileceği.
enum CardScale {
  /// Akışın en yeni kaydı: tam genişlik, uzun çerçeve.
  hero(4 / 5, 26, 17, 2),

  /// Tek sütun görünümünün geri kalanı.
  full(4 / 3, 26, 16, 2),

  /// Izgara görünümü: iki sütun, kare çerçeve.
  compact(1, 20, 13, 2);

  const CardScale(this.aspect, this.radius, this.bodySize, this.bodyLines);

  final double aspect;
  final double radius;
  final double bodySize;
  final int bodyLines;

  bool get isCompact => this == CardScale.compact;
}

/// Akıştaki tek kayıt.
///
/// Yazı, fotoğrafın üzerine düşen bir *cam şerit* içinde durur: gradyan
/// karartma yerine gerçek bulanıklık kullanmak, altındaki kareyi yok etmeden
/// metni okunur kılar.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.repository,
    required this.onTap,
    required this.onLongPress,
    this.scale = CardScale.full,
  });

  final Note note;
  final NotesRepository repository;
  final VoidCallback onTap;

  /// Basılı tutmak silme onayını açar — listeden çıkmadan.
  final VoidCallback onLongPress;

  final CardScale scale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasBody = note.body.isNotEmpty;
    final radius = BorderRadius.circular(scale.radius);

    return Pressable(
      onPressed: onTap,
      onLongPressed: onLongPress,
      scale: 0.98,
      semanticLabel: hasBody ? note.body : 'Notsuz kayıt',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: palette.isDark
                  ? OnPhoto.canvasDeep.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.10),
              blurRadius: scale.isCompact ? 14 : 24,
              offset: Offset(0, scale.isCompact ? 6 : 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: scale.aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'note-photo-${note.id}',
                  child: ParallaxPhoto(
                    child: NotePhoto(
                      file: repository.imageOf(note),
                      decodeWidth: MediaQuery.sizeOf(context).width /
                          (scale.isCompact ? 2 : 1),
                    ),
                  ),
                ),

                if (note.expiresAt != null)
                  Positioned(
                    top: scale.isCompact ? 9 : 12,
                    right: scale.isCompact ? 9 : 12,
                    child: ExpiryBadge(
                      createdAt: note.createdAt,
                      expiresAt: note.expiresAt!,
                    ),
                  ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CaptionStrip(note: note, scale: scale),
                ),

                // Kartın kenarını fotoğraftan bağımsız olarak tanımlayan
                // saç teli çerçeve.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: OnPhoto.hairline, width: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionStrip extends StatelessWidget {
  const _CaptionStrip({required this.note, required this.scale});

  final Note note;
  final CardScale scale;

  @override
  Widget build(BuildContext context) {
    final hasBody = note.body.isNotEmpty;
    final horizontal = scale.isCompact ? 11.0 : 16.0;
    final vertical = (hasBody ? 13.0 : 10.0) - (scale.isCompact ? 3 : 0);

    return GlassSurface(
      borderRadius: BorderRadius.zero,
      blur: 20,
      tint: OnPhoto.canvasDeep.withValues(alpha: 0.34),
      border: false,
      padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, vertical),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasBody) ...[
            Text(
              note.body,
              style: OnPhotoText.bodyStrong.copyWith(fontSize: scale.bodySize),
              maxLines: scale.bodyLines,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: scale.isCompact ? 4 : 6),
          ],
          Text(
            TrFormat.time(note.createdAt),
            style: OnPhotoText.caption.copyWith(
              color: OnPhoto.inkSoft,
              fontSize: scale.isCompact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
