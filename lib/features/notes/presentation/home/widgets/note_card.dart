import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/life_rule.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import 'note_photo.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../core/utils/app_format.dart';

/// Kartın hangi ölçekte çizileceği.
enum CardScale {
  /// Akışın en yeni kaydı: uzun baskı, en büyük punto.
  hero(4 / 5, 26, 2),

  /// Tek sütun görünümünün geri kalanı.
  full(4 / 3, 19, 2),

  /// Izgara görünümü: iki sütun, oranı fotoğrafın kendisi belirler.
  compact(1, 14, 3);

  const CardScale(this.aspect, this.noteSize, this.noteLines);

  /// Baskının varsayılan en-boy oranı. Izgarada karenin gerçek oranı kullanılır.
  final double aspect;

  /// Notun punto boyu. Kartın *en büyük* yazısı budur — caption değil, manşet.
  final double noteSize;

  final int noteLines;

  bool get isCompact => this == CardScale.compact;
}

/// Akıştaki tek kayıt: bir baskı ve altında notu.
///
/// İki kural taşır.
///
/// **Kareye dokunulmaz.** Fotoğrafın üstünde perde, rozet, gradyan ya da yazı
/// yok. Not onun *altında*, uygulamanın kendi zemininde durur; okunurluk için
/// fotoğrafı karartma tavizine hiç girilmez.
///
/// **Kartın yüzeyi yok.** Bir zamanlar not opak bir bandın içindeydi; bu, her
/// kaydı aynı yükseklikte bir modüle çeviriyor ve akışı katalog gibi
/// gösteriyordu. Yüzey kalkınca ritmi fotoğrafların kendi oranları kuruyor.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.repository,
    required this.onTap,
    required this.onLongPress,
    this.scale = CardScale.full,
    this.aspect,
    this.now,
  });

  final Note note;
  final NotesRepository repository;
  final VoidCallback onTap;

  /// Basılı tutmak silme onayını açar — listeden çıkmadan.
  final VoidCallback onLongPress;

  final CardScale scale;

  /// Baskının en-boy oranı. Verilmezse [CardScale.aspect] kullanılır.
  /// Izgara bunu fotoğrafın gerçek oranıyla doldurur.
  final double? aspect;

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasBody = note.body.isNotEmpty;

    return Pressable(
      onPressed: onTap,
      onLongPressed: onLongPress,
      scale: 0.985,
      semanticLabel: hasBody ? note.body : context.l10n.noteWithoutBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Köşe ölçekle değişmiyor: baskı her boyutta baskıdır.
          ClipRSuperellipse(
            borderRadius: AppShape.all(AppShape.print),
            child: AspectRatio(
              aspectRatio: aspect ?? scale.aspect,
              child: Hero(
                tag: 'note-photo-${note.id}',
                child: NotePhoto(
                  file: repository.imageOf(note),
                  decodeWidth: _printWidth(context),
                ),
              ),
            ),
          ),

          SizedBox(height: hasBody ? (scale.isCompact ? 9 : 13) : 7),

          if (hasBody) ...[
            Text(
              note.body,
              style: TextStyle(
                fontFamily: AppType.fontFamily,
                fontSize: scale.noteSize,
                height: 1.18,
                fontWeight: FontWeight.w600,
                // Punto büyüdükçe harfler sıkılaşır; optik boyut davranışının
                // elle yapılmış hâli.
                letterSpacing: switch (scale) {
                  CardScale.hero => -0.8,
                  CardScale.full => -0.4,
                  CardScale.compact => -0.25,
                },
                color: palette.ink,
              ),
              maxLines: scale.noteLines,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: scale.isCompact ? 5 : 7),
          ],

          _Meta(note: note, scale: scale, now: now),
        ],
      ),
    );
  }

  double _printWidth(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).width;
    // Izgara: 16 kenar + 12 ara + 16 kenar, iki sütun. Sütun: 16 × 2 kenar.
    return scale.isCompact ? (screen - 44) / 2 : screen - 32;
  }
}

/// Künye satırı: zaman, ve süreli kayıtlarda satırın sonuna kadar uzanan
/// ömür çizgisi.
///
/// Ömür bir rozetle değil bu çizgiyle anlatılıyor. Rozet fotoğrafın üstünde
/// duran bir nesneydi ve kareyi kirletiyordu; çizgi künyenin devamı — bir şey
/// okumana gerek kalmadan ne kadar kaldığını görüyorsun.
class _Meta extends StatelessWidget {
  const _Meta({required this.note, required this.scale, this.now});

  final Note note;
  final CardScale scale;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final expiresAt = note.expiresAt;

    // Rakamlar tabular: saatler alt alta gelince basamaklar hizada durur.
    final style = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: scale.isCompact ? 11 : 12,
      height: 1.1,
      fontWeight: FontWeight.w500,
      color: palette.inkFaint,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (expiresAt == null) {
      return Text(context.l10n.time(note.createdAt), style: style);
    }

    final reference = now ?? DateTime.now();
    final left = lifeFraction(note.createdAt, expiresAt, reference);
    // Son beşte birinde kalan süre öne çıkar; öncesinde zamanla eşit sessizlikte.
    final urgent = left <= 0.2;

    final stamp = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.time(note.createdAt)),
          const TextSpan(text: '   ·   '),
          TextSpan(
            text: context.l10n.remainingShort(expiresAt, now: reference),
            style: urgent
                ? TextStyle(color: palette.ember, fontWeight: FontWeight.w600)
                : null,
          ),
        ],
      ),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // Izgarada kutu dar: künye ile iz yan yana sığmıyor ve satır taşıyor.
    // Orada iz alt satıra iner, tam genişlikte uzanır.
    if (scale.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          stamp,
          const SizedBox(height: 7),
          LifeRule(left: left),
        ],
      );
    }

    return Row(
      children: [
        Flexible(child: stamp),
        const SizedBox(width: 10),
        Expanded(child: LifeRule(left: left)),
      ],
    );
  }
}
