import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/app_shape.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/life_rule.dart';
import '../../../../../shared/widgets/pressable.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../../domain/note_kind.dart';
import '../../../domain/note_reminder.dart';
import 'note_photo.dart';
import '../../../../../l10n/enum_labels.dart';
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
    this.selecting = false,
    this.selected = false,
    this.dated = false,
  });

  final Note note;
  final NotesRepository repository;
  final VoidCallback onTap;

  /// Basılı tutmak silme onayını açar — listeden çıkmadan. Seçim kipinde
  /// kapalıdır: orada dokunmanın tek anlamı işaretlemektir.
  final VoidCallback? onLongPress;

  /// Toplu silme kipi açık mı.
  final bool selecting;

  /// Bu kayıt seçilenler arasında mı.
  final bool selected;

  final CardScale scale;

  /// Baskının en-boy oranı. Verilmezse [CardScale.aspect] kullanılır.
  /// Izgara bunu fotoğrafın gerçek oranıyla doldurur.
  final double? aspect;

  /// Kart bir gün ayıracının altında değil, tek başına duruyor: künye saati
  /// değil kendi tarihini taşır. Arama sonucu böyle diziliyor.
  final bool dated;

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  /// İşletim sistemi hakkı da hesaba katılmış gerçekten bekleyen oluşum.
  final DateTime? reminderAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final hasBody = note.body.isNotEmpty;
    // Karesiz kayıtta yazı baskının **kendisi**; altına ikinci kez yazmak
    // aynı cümleyi iki kere okutmak olurdu.
    final showsCaption = hasBody && note.hasPhoto;
    final reference = now ?? DateTime.now();
    final semanticLabel = [
      hasBody ? note.body : l10n.noteWithoutBody,
      if (reminderAt != null)
        '${l10n.reminderLabel}: '
            '${ReminderCadence.fromCode(note.remindEveryDays).sentence(l10n, at: reminderAt!, use24Hour: context.use24Hour)}',
    ].join('. ');

    return Pressable(
      onPressed: onTap,
      onLongPressed: selecting ? null : onLongPress,
      scale: 0.985,
      semanticLabel: semanticLabel,
      selected: selecting ? selected : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Karesi olan kayıt oranıyla, karesiz kayıt **yazısıyla**
          // boylanıyor. Sabit bir oran verilseydi üç kelimelik bir not koca
          // bir boş kâğıt olurdu; kâğıdın boyu yazının kendisi kadar.
          _Print(
            aspect: note.hasPhoto ? (aspect ?? scale.aspect) : null,
            child: Stack(
              fit: note.hasPhoto ? StackFit.expand : StackFit.loose,
              children: [
                // Seçilen baskı yuvasından **çekilir**: çerçeve yerinde
                // kalır, kare içeri çekilip etrafında ince bir kor hattı
                // bırakır. Kontakt baskıdan bir kareyi ayırmak gibi; işaret
                // fotoğrafın üstüne basılmaz, kenarında durur.
                if (selecting && selected)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: AppShape.border(
                          AppShape.print + 4,
                          side: BorderSide(color: palette.ember, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                AnimatedPadding(
                  duration: AppMotion.fast,
                  curve: AppMotion.ease,
                  padding: EdgeInsets.all(selecting && selected ? 6 : 0),
                  // Köşe ölçekle değişmiyor: baskı her boyutta baskıdır.
                  child: ClipRSuperellipse(
                    borderRadius: AppShape.all(AppShape.print),
                    child: Hero(
                      tag: 'note-photo-${note.id}',
                      child: note.hasPhoto
                          ? NotePhoto(
                              // Izgarada küçük kopya; tek sütun ve detay tam
                              // kareyi okumaya devam ediyor. Kopya yoksa
                              // ikisi de aynı dosyayı gösteriyor.
                              file: scale.isCompact
                                  ? repository.gridImageOf(note)
                                  : repository.imageOf(note),
                              decodeWidth: _printWidth(context),
                            )
                          : _TextPrint(note: note, scale: scale),
                    ),
                  ),
                ),
                if (selecting && selected)
                  const Positioned(right: 10, bottom: 10, child: _SelectMark()),
              ],
            ),
          ),

          SizedBox(
            height: showsCaption
                ? (scale.isCompact ? 9 : 13)
                : (note.hasPhoto ? 7 : (scale.isCompact ? 10 : 14)),
          ),

          if (showsCaption) ...[
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
            dated: dated,
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

/// Seçilmiş karenin köşesindeki onay çentiği.
///
/// Yalnız **seçilenlerde** çizilir. Kipteki her kareye boş bir halka koymak,
/// kartın kendi kuralını ("kareye dokunulmaz") elli fotoğraf boyunca çiğnemek
/// olurdu; seçilmemiş baskı olduğu gibi kalır, karar verilen kare işaretlenir.
class _SelectMark extends StatelessWidget {
  const _SelectMark();

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppMotion.fast,
        curve: AppMotion.spring,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.ember,
            // Kor lekesi koyu bir fotoğrafın üstünde eriyip gitmesin.
            border: Border.all(
              color: OnPhoto.ink.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      ),
    );
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
    required this.dated,
    this.reminderAt,
  });

  final Note note;
  final CardScale scale;
  final DateTime reference;
  final bool dated;
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

    final marked = dated
        ? context.l10n.noteStamp(
            note.createdAt,
            now: reference,
            use24Hour: context.use24Hour,
          )
        : context.l10n.time(note.createdAt, use24Hour: context.use24Hour);

    final Widget primary;
    if (expiresAt == null) {
      primary = Text(marked, style: style);
    } else {
      final left = lifeFraction(note.createdAt, expiresAt, reference);
      // Son beşte birinde kalan süre öne çıkar; öncesinde zamanla eşit sessizlikte.
      final urgent = left <= 0.2;

      final stamp = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: marked),
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
          // Silinme anı hatırlatmadan türemişse kullanıcı "hatırlat, sonra
          // sil" demiş demektir. Kart kalan ömrü zaten gösteriyor ama sebebini
          // söylemiyordu: bu kayıt kendi saklama süresi yüzünden değil,
          // verilen söz yüzünden gidiyor.
          deletesAfter: isReminderExpiry(
            remindAt: note.remindAt,
            expiresAt: note.expiresAt,
          ),
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
    required this.deletesAfter,
    required this.reference,
    required this.compact,
  });

  final DateTime at;

  /// Tekrarlayan hatırlatmada çentiğin önüne küçük bir dönüş izi gelir:
  /// gösterilen an bir son değil, sıradaki uğrak.
  final bool repeats;

  /// Hatırlattıktan sonra kendini silen kayıt.
  ///
  /// [repeats] ile **aynı yuvayı** paylaşıyor ve bu güvenli: söz yalnız tek
  /// atışta duruyor, tekrarlı bir hatırlatmada verilemiyor. Yani ikisi hiçbir
  /// zaman birlikte çıkmıyor ve karta üçüncü bir işaret eklenmiş olmuyor.
  final bool deletesAfter;

  final DateTime reference;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (repeats || deletesAfter) ...[
            Icon(
              repeats ? Icons.repeat_rounded : Icons.auto_delete_outlined,
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

/// Karesiz kaydın ızgaradaki hâli.
///
/// **Kutu yok.** Fotoğraf baskılarının arasına ikinci bir kart tipi koymak,
/// ızgarayı iki ayrı dile böler; üstelik yazıyı kutuya almak onu bir arayüz
/// öğesi gibi gösteriyor, oysa yazı burada içeriğin kendisi. Kaydın hiyerarşisi
/// yüzeyle değil **dizgiyle** kuruluyor.
///
/// Tek işaret üstteki künye çizgisi: uygulamanın gün ayıracında ve künye
/// çubuğunda zaten kullandığı saç teli, başında kısa bir kor parçasıyla. O
/// parça bu kaydın çekilmediğini, yazıldığını söyleyen tek şey — bir rozete
/// ya da simgeye gerek kalmıyor.
///
/// Yazı kartın altında ikinci kez tekrar edilmiyor; künye satırı (saat ve ömür
/// izi) olduğu gibi altta duruyor ve bloğu kapatıyor.
class _TextPrint extends StatelessWidget {
  const _TextPrint({required this.note, required this.scale});

  final Note note;
  final CardScale scale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasBody = note.body.isNotEmpty;
    final compact = scale.isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 1,
          // `stretch` şart: çocuksuz bir `ColoredBox` sıfır yükseklikte
          // kalıyor ve çizgi hiç çizilmiyor.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: compact ? 16 : 22,
                child: ColoredBox(color: palette.ember),
              ),
              Expanded(child: ColoredBox(color: palette.hairline)),
            ],
          ),
        ),
        SizedBox(height: compact ? 13 : 18),
        Text(
          hasBody ? note.body : context.l10n.noteWithoutBody,
          style: TextStyle(
            fontFamily: AppType.fontFamily,
            // Yazı burada künye değil manşet: bloğun ağırlığını tek başına
            // taşıdığı için kartın altındaki puntodan belirgin büyük.
            fontSize: scale.noteSize * 1.15,
            height: 1.24,
            fontWeight: FontWeight.w600,
            letterSpacing: switch (scale) {
              CardScale.hero => -0.9,
              CardScale.full => -0.5,
              CardScale.compact => -0.3,
            },
            color: hasBody ? palette.ink : palette.inkFaint,
          ),
          maxLines: scale.isCompact ? 6 : 9,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Kâğıdın en az yüksekliği.
///
/// Üç kelimelik not bile bir kart olmalı, ince bir şerit değil. Akışın sütun
/// paylaştırması da aynı sayıyı kullanıyor.
double textPrintMinHeight(CardScale scale) => scale.isCompact ? 34 : 44;

/// Karesiz kaydın kaplayacağı kaba yükseklik.
///
/// Yalnız sütun paylaştırması için; yanılırsa sütunlardan biri birkaç piksel
/// uzun biter, hiçbir kartın çizimi değişmez — kartlar kendi gerçek
/// boylarında diziliyor.
double textPrintHeight(String body, double width, {required CardScale scale}) {
  // Kutu olmadığı için pay yalnız çizgi ve altındaki boşluk.
  final padding = 1.0 + (scale.isCompact ? 13.0 : 18.0);
  final fontSize = scale.noteSize * 1.15;
  final perLine = ((width - padding) / (fontSize * 0.52)).floor().clamp(8, 400);
  final lines = (body.length / perLine).ceil().clamp(
    1,
    scale.isCompact ? 6 : 9,
  );
  final height = padding + lines * fontSize * 1.24;
  final floor = textPrintMinHeight(scale);
  return height < floor ? floor : height;
}

/// Baskının dış kutusu.
///
/// [aspect] verilirse oranıyla, verilmezse çocuğunun kendi boyuyla.
class _Print extends StatelessWidget {
  const _Print({required this.aspect, required this.child});

  final double? aspect;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      aspect == null ? child : AspectRatio(aspectRatio: aspect!, child: child);
}
