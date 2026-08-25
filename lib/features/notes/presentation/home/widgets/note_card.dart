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
    this.reminderAt,
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

  /// İşletim sistemi hakkı da hesaba katılmış gerçekten bekleyen oluşum.
  final DateTime? reminderAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final hasBody = note.body.isNotEmpty;
    final reference = now ?? DateTime.now();
    final semanticLabel = [
      hasBody ? note.body : l10n.noteWithoutBody,
      if (reminderAt != null)
        '${l10n.reminderLabel}: '
            '${l10n.reminderValue(at: reminderAt!, everyDays: note.remindEveryDays, use24Hour: context.use24Hour)}',
    ].join('. ');

    return Pressable(
      onPressed: onTap,
      onLongPressed: onLongPress,
      scale: 0.985,
      semanticLabel: semanticLabel,
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

          _Meta(
            note: note,
            scale: scale,
            reference: reference,
            reminderAt: reminderAt,
          ),
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
  const _Meta({
    required this.note,
    required this.scale,
    required this.reference,
    this.reminderAt,
  });

  final Note note;
  final CardScale scale;
  final DateTime reference;
  final DateTime? reminderAt;

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

    final Widget primary;
    if (expiresAt == null) {
      primary = Text(
        context.l10n.time(note.createdAt, use24Hour: context.use24Hour),
        style: style,
      );
    } else {
      final left = lifeFraction(note.createdAt, expiresAt, reference);
      // Son beşte birinde kalan süre öne çıkar; öncesinde zamanla eşit sessizlikte.
      final urgent = left <= 0.2;

      final stamp = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: context.l10n.time(
                note.createdAt,
                use24Hour: context.use24Hour,
              ),
            ),
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
      primary = scale.isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                stamp,
                const SizedBox(height: 7),
                LifeRule(left: left),
              ],
            )
          : Row(
              children: [
                Flexible(child: stamp),
                const SizedBox(width: 10),
                Expanded(child: LifeRule(left: left)),
              ],
            );
    }

    final at = reminderAt;
    if (at == null) return primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        primary,
        SizedBox(height: scale.isCompact ? 6 : 7),
        _ReminderNotch(
          key: ValueKey('reminder-notch-${note.id}'),
          at: at,
          repeats: note.remindEveryDays > 0,
          reference: reference,
          compact: scale.isCompact,
        ),
      ],
    );
  }
}

/// Yaklaşan hatırlatmanın kontakt baskı künyesindeki küçük hedef çentiği.
///
/// Bildirim zili, kapsül veya fotoğraf üstü rozet kullanmaz. Kısa nötr iz
/// geleceği, dik vurgu çentiği ise notun tekrar görüneceği anı anlatır. Ömür
/// çizgisinden akraba bir dil taşır ama sabit ve kısa olduğu için silinme
/// ilerlemesiyle karışmaz.
class _ReminderNotch extends StatelessWidget {
  const _ReminderNotch({
    super.key,
    required this.at,
    required this.repeats,
    required this.reference,
    required this.compact,
  });

  final DateTime at;

  /// Tekrarlayan hatırlatmada çentiğin önüne küçük bir dönüş izi gelir:
  /// gösterilen an bir son değil, sıradaki uğrak.
  final bool repeats;

  final DateTime reference;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (repeats) ...[
            Icon(
              Icons.repeat_rounded,
              size: compact ? 10.5 : 11.5,
              color: palette.inkSoft,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            context.l10n.remainingShort(at, now: reference),
            style: TextStyle(
              fontFamily: AppType.fontFamily,
              fontSize: compact ? 10.5 : 11,
              height: 1,
              fontWeight: FontWeight.w600,
              color: palette.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: compact ? 27 : 32,
            height: 9,
            child: CustomPaint(
              painter: _ReminderNotchPainter(
                track: palette.hairlineBright,
                mark: palette.ember,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderNotchPainter extends CustomPainter {
  const _ReminderNotchPainter({required this.track, required this.mark});

  final Color track;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final x = size.width - 2;

    canvas.drawLine(
      Offset(0, y),
      Offset(x, y),
      Paint()
        ..color = track
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x, 1),
      Offset(x, size.height - 1),
      Paint()
        ..color = mark
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x, y), 1.35, Paint()..color = mark);
  }

  @override
  bool shouldRepaint(_ReminderNotchPainter old) =>
      old.track != track || old.mark != mark;
}
