import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../core/utils/map_link.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../../shared/widgets/app_toast.dart';
import '../../../../../shared/widgets/aperture.dart';
import '../../../../../shared/widgets/life_rule.dart';
import '../../../data/notes_database.dart';

/// Sayfanın tek yatay marjı.
///
/// Baskı ve metin aynı hatta oturur. Eskiden kare 16, yazı 22 puanda
/// başlıyordu; altı puanlık bu kayma gözle seçilmese de kompozisyonun
/// tasarlanmış değil, denk gelmiş görünmesine yetiyordu. Aynı değer ana
/// akıştaki kartın marjı olduğu için baskı, listeden detaya yatay olarak hiç
/// zıplamadan uçar.
const double kDetailMargin = 16.0;

/// Sayfanın dört köşesindeki denetimlerin ölçüsü — ana ekranın üst
/// köşesindeki denetimlerle aynı.
const double kDetailOrbSize = 38.0;

/// Karenin altındaki editoryal alan: önce not, sonra künye.
///
/// Sıralama bilinçli. Kullanıcı bu sayfayı "bunu neden çekmiştim" sorusuyla
/// açıyor; cevabı fotoğrafın hemen altında olmalı. Tarih, kalan ömür ve
/// hatırlatma ise bağlam — kaydın *altına* düşen künye satırıdır. Uygulamadaki
/// bütün zaman bilgisi tek bir yerde ve tek bir dilde toplanır: eskiden tarih
/// tepede, kalan süre metnin üstünde, ömür çizgisi karenin altındaydı — üç ayrı
/// bölgede üç ayrı gösterge.
class DetailSheet extends StatelessWidget {
  const DetailSheet({
    super.key,
    required this.note,
    required this.entrance,
    required this.onEdit,
    this.reminderAt,
    this.now,
  });

  final Note note;

  /// Sayfanın 0 → 1 açılış zamanı. Bölümler bunun farklı aralıklarına oturur;
  /// böylece içerik topluca "pat" diye belirmek yerine sırayla yerine gelir.
  final Animation<double> entrance;

  /// Metne dokunmak yazmaya geçirir. Ayrı bir "Düzenle" düğmesi yok: okunan
  /// satırın kendisi düzenlemenin hedefi.
  final VoidCallback onEdit;

  /// Gerçekten bekleyen hatırlatma anı; yoksa `null`.
  final DateTime? reminderAt;

  /// Testlerde zamanı sabitlemek için.
  final DateTime? now;

  /// Bu uzunluğa kadar not bir cümle değil, bir **etiket**tir: "B2, sarı
  /// bölge", "Test5". Sola yaslandığında geniş bir boşluğun kenarında öksüz
  /// duruyor; ortalandığında karenin altına asılmış bir künye levhası gibi
  /// okunuyor. Dört kelimeden sonra metin bir paragrafa dönüşmeye başlar ve
  /// ortalamak okumayı zorlaştırır — orada sola yaslı kalır.
  static const _centeredWordLimit = 3;

  static bool _isShort(String body) {
    if (body.isEmpty) return true;
    return body.split(RegExp(r'\s+')).length <= _centeredWordLimit;
  }

  @override
  Widget build(BuildContext context) {
    final body = note.body.trim();
    final hasBody = body.isNotEmpty;
    final centered = _isShort(body);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kDetailMargin, 26, kDetailMargin, 20),
      child: AnimatedBuilder(
        animation: entrance,
        builder: (context, _) {
          final t = entrance.value;
          // İki kelimelik bir notta metnin altında kalan boşluk artık kaza
          // değil: künye sayfanın tabanına oturur, aradaki sessizlik de
          // kompozisyonun parçası olur. Metin uzayıp alanı doldurduğunda
          // aralık kendiliğinden kapanır ve künye yazının peşine takılır.
          return Column(
            key: const ValueKey('detail-sheet-surface'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Reveal(
                t: _stage(t, .16, .74),
                lift: 14,
                child: _NoteCopy(
                  body: body,
                  onEdit: onEdit,
                  centered: centered,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: hasBody ? 32 : 24),
                child: _Reveal(
                  t: _stage(t, .30, .88),
                  lift: 10,
                  child: _Colophon(
                    note: note,
                    reminderAt: reminderAt,
                    now: now,
                    rule: _stage(t, .34, 1, Curves.easeOutQuart),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// [begin]–[end] aralığına oturan tek bir sahne değeri.
///
/// `CurvedAnimation` nesneleri kurmak yerine düz aritmetik: her kare için
/// yaratılıp atılan dinleyicisi olmaz.
double _stage(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

class _Reveal extends StatelessWidget {
  const _Reveal({required this.t, required this.lift, required this.child});

  final double t;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Yerine oturduktan sonra fazladan bir katman bırakmaz.
    if (t >= 1) return child;
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, lift * (1 - t)),
        child: child,
      ),
    );
  }
}

/// Notun kendisi — ya da henüz yazılmamışsa yazmaya çağıran soru.
class _NoteCopy extends StatelessWidget {
  const _NoteCopy({
    required this.body,
    required this.onEdit,
    required this.centered,
  });

  final String body;
  final VoidCallback onEdit;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final hasBody = body.isNotEmpty;
    final style = hasBody
        ? _opticalStyle(palette, body)
        : palette.title.copyWith(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
            color: palette.inkGhost,
          );

    return Semantics(
      button: true,
      label: hasBody ? body : l10n.noteWithoutBody,
      hint: l10n.editNoteSemantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: ExcludeSemantics(
          child: Text(
            hasBody ? body : l10n.composeHint,
            key: const ValueKey('detail-note-copy'),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: style,
          ),
        ),
      ),
    );
  }

  /// Her not aynı şablona zorlanmaz. İki kelimelik bir kayıt manşet, uzun bir
  /// metin ise rahat okunan gövde yazısıdır: punto büyürken satır aralığı ve
  /// harf aralığı sıkışır, küçülürken açılır — optik boyutun elle yapılmış
  /// hâli.
  TextStyle _opticalStyle(AppPalette palette, String body) {
    final length = body.runes.length;
    return switch (length) {
      <= 26 => palette.display.copyWith(
        fontSize: 34,
        height: 1.07,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.05,
      ),
      <= 68 => palette.display.copyWith(
        fontSize: 28,
        height: 1.14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.75,
      ),
      <= 170 => palette.title.copyWith(
        fontSize: 22,
        height: 1.28,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.42,
      ),
      _ => palette.body.copyWith(
        fontSize: 18,
        height: 1.48,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.16,
      ),
    };
  }
}

/// Kaydın künyesi — ve aynı zamanda küçük bir zaman ekseni.
///
/// İz "şimdi"yi çizer: altında kaydın *geleceği* durur — nerede çekildi, ne
/// zaman değiştirildi, ne zaman yüzeye çıkacak, ne zaman silinecek.
///
/// Satırlar tek tek değil liste hâlinde diziliyor ve aralar tek yerde
/// veriliyor. Her satır kendi koşullu boşluğunu taşıdığında ilk satır ile
/// çizgi arasındaki payı kimse vermiyordu: koordinat çizgiye yapışıyordu.
class _Colophon extends StatelessWidget {
  const _Colophon({
    required this.note,
    required this.rule,
    this.reminderAt,
    this.now,
  });

  final Note note;

  /// İzin çizilme ilerlemesi: 0 iken hiç yok, 1 iken gerçek kalan ömür.
  final double rule;

  final DateTime? reminderAt;
  final DateTime? now;

  /// Hatırlatma satırının metni. Sesli okuma etiketi ile görünen satır aynı
  /// cümleyi kurmalı; ikisi de buradan geçiyor.
  String _reminderValue(L10n l10n, {required bool use24Hour}) =>
      l10n.reminderValue(
        at: reminderAt!,
        everyDays: note.remindEveryDays,
        use24Hour: use24Hour,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reference = now ?? DateTime.now();
    final expiresAt = note.expiresAt;
    final updatedAt = note.updatedAt;
    final latitude = note.latitude;
    final longitude = note.longitude;
    final hasPlace = latitude != null && longitude != null;

    // Kaydın bir yeri, bir sonu, bir randevusu ve bir düzeltmesi yoksa burada
    // söylenecek bir şey de yok. Boş bir çizgi çizmek için gerekçe
    // uydurulmuyor.
    if (!hasPlace &&
        expiresAt == null &&
        reminderAt == null &&
        updatedAt == null) {
      return const SizedBox.shrink();
    }

    final lines = _lines(context, reference);

    return Semantics(
      container: true,
      label: [
        if (hasPlace)
          '${l10n.locationLabel}: '
              '${MapLink.format(latitude, longitude, north: l10n.compassNorth, south: l10n.compassSouth, east: l10n.compassEast, west: l10n.compassWest)}',
        if (updatedAt != null)
          '${l10n.lastUpdatedLabel}: '
              '${l10n.stamp(updatedAt, use24Hour: context.use24Hour)}',
        if (expiresAt != null) l10n.remainingLong(expiresAt, now: reference),
        if (reminderAt != null)
          '${l10n.reminderLabel}: '
              '${_reminderValue(l10n, use24Hour: context.use24Hour)}',
      ].join('. '),
      child: ExcludeSemantics(
        // Künye notun hizasından bağımsız: her zaman ortalı. Kaydın imza
        // satırı sayfanın eksenine oturunca, uzun bir metnin altında bile
        // "burada bitti" duygusu veriyor.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: _TerminalRule(
                key: const ValueKey('detail-life-edge'),
                left: expiresAt == null
                    ? null
                    : lifeFraction(note.createdAt, expiresAt, reference),
                progress: rule,
              ),
            ),
            for (var index = 0; index < lines.length; index++) ...[
              // Çizginin altındaki ilk satır daha çok nefes ister: orası bir
              // bölüm başlangıcı, satır arası değil.
              SizedBox(height: index == 0 ? 16 : 11),
              lines[index],
            ],
          ],
        ),
      ),
    );
  }

  /// Künyede görünecek satırlar, kronolojik sırada.
  List<Widget> _lines(BuildContext context, DateTime reference) {
    final palette = context.palette;
    final l10n = context.l10n;
    final expiresAt = note.expiresAt;
    final updatedAt = note.updatedAt;
    final latitude = note.latitude;
    final longitude = note.longitude;
    final urgent =
        expiresAt != null &&
        expiresAt.difference(reference) <= const Duration(hours: 24);
    final left = expiresAt == null
        ? 0.0
        : lifeFraction(note.createdAt, expiresAt, reference);

    return [
      if (latitude != null && longitude != null)
        _PlaceLine(latitude: latitude, longitude: longitude),

      if (updatedAt != null)
        _MetaLine(
          key: const ValueKey('detail-edited-line'),
          label: l10n.lastUpdatedLabel,
          value: l10n.stamp(updatedAt, use24Hour: context.use24Hour),
          accent: false,
        ),

      if (reminderAt != null)
        _MetaLine(
          key: const ValueKey('detail-reminder-line'),
          label: l10n.reminderLabel,
          value: _reminderValue(l10n, use24Hour: context.use24Hour),
          accent: true,
        ),

      if (expiresAt != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kalan ömür, uygulamanın kendi diyaframıyla anlatılıyor. Not
            // yaşlandıkça iris kapanır; silme onayında da kapanan aynı iristir.
            // Kullanıcı burada gördüğü hareketin sonunu orada görür — iki ekran
            // tek bir cümle kurar.
            SizedBox.square(
              dimension: 17,
              child: Aperture(
                key: const ValueKey('detail-life-iris'),
                openness: left,
                twist: -0.42 * (1 - left),
                bladeCount: 7,
                edgeTint: urgent ? palette.ember : palette.inkFaint,
                bladeBase: palette.canvas,
              ),
            ),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                l10n.upper(l10n.remainingLong(expiresAt, now: reference)),
                key: const ValueKey('detail-retention-line'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: palette.overline.copyWith(
                  // Kırmızı değil, uygulamanın kendi kor rengi — ve yalnızca
                  // son yirmi dört saatte. Erken uyarı, uyarı olmaktan çıkar.
                  color: urgent ? palette.ember : palette.inkFaint,
                  height: 1.5,
                  letterSpacing: 1.25,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
    ];
  }
}

/// Sayfayı kapatan çizgi.
///
/// Süreli kayıtta kalan ömrü taşır; süresizse yalnızca nötr bir baskı kenarı
/// olarak kalır. İkisi de aynı yerde durduğu için "bu notun bir sonu var mı"
/// sorusu tek bakışta cevaplanır.
class _TerminalRule extends StatelessWidget {
  const _TerminalRule({super.key, required this.left, required this.progress});

  final double? left;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = left;

    if (remaining == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: palette.hairlineBright),
          ),
        ),
      );
    }

    return LifeRule(left: remaining * progress.clamp(0.0, 1.0), height: 2);
  }
}

/// Künyedeki tek olgu: düzenleme damgası ya da hatırlatma randevusu.
///
/// Tek satıra dizilmiş "Son Güncellenme · 9 Ağustos 2026 · 01:24" iki ayrı
/// şeyi — neyin olduğunu ve ne zaman olduğunu — aynı puntoda, aynı renkte,
/// aynı ayraçla veriyordu; göz nereye bakacağını bilemiyordu. Burada olgu
/// üstte küçük kapitellerle, zamanı altında rakam dizgisiyle duruyor. Yapı,
/// sayfanın tepesindeki çekim imprintiyle aynı: etiket üstte, değer altta.
///
/// Renk de bir şey söylüyor: geçmiş bir olay sessiz, gelecek bir randevu kor
/// rengiyle etiketleniyor.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.upper(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: palette.overline.copyWith(
            color: accent ? palette.ember : palette.inkGhost,
            fontSize: 9.5,
            height: 1,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: palette.label.copyWith(
            color: palette.inkFaint,
            fontSize: 12.5,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Karenin çekildiği yer.
///
/// Referans düzendeki gibi tek satır: iğne ve yanında yer. Ayrı bir "KONUM"
/// etiketi yok — iğnenin kendisi etiket. Künyedeki diğer satırlar iki katlı
/// çünkü "ne olduğu" ile "ne zaman olduğu" iki ayrı bilgi; burada tek bilgi
/// var, tek satır yeter.
///
/// Yazan şey bir yer *adı* değil koordinat, çünkü adı üretmek koordinatı
/// Apple ya da Google sunucusuna göndermek demek. Dokunulunca haritayı
/// kullanıcının kendi uygulaması açıyor: ağa çıkan uygulama değil, onun
/// bilinçli hareketi.
class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.locationLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.selectionClick();
          final opened = await MapLink.open(latitude, longitude);
          if (!opened && context.mounted) {
            showToast(context, l10n.toastMapFailed, error: true);
          }
        },
        child: Row(
          key: const ValueKey('detail-place-line'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rengi yalnızca iğne taşıyor: satırın dokunulabilir olduğunu
            // söylemeye yetiyor, metni bağırtmadan.
            Icon(Icons.place_outlined, size: 14, color: palette.ember),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                MapLink.format(
                  latitude,
                  longitude,
                  north: l10n.compassNorth,
                  south: l10n.compassSouth,
                  east: l10n.compassEast,
                  west: l10n.compassWest,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: palette.label.copyWith(
                  color: palette.inkSoft,
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
