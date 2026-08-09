import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/pro_badge.dart';
import '../../../notes/data/notes_database.dart';
import '../../../notes/data/notes_repository.dart';
import '../../../paywall/domain/pro_limits.dart';
import '../../../paywall/presentation/paywall_host.dart';

/// Ayarların tepesindeki Pro kapısı.
///
/// İki başarısız hâlin arasından geçti, ikisi de öğretici:
///
/// Önce sıradan bir ayar satırıydı — aynı zemin, aynı tipografi, sonunda bir
/// chevron. Kullanıcı onu "tema" ya da "dil" gibi bir tercih sanıp geçiyordu.
///
/// Sonra kutulanmış, gradyanlı, gölgeli bir kart oldu. Görünüyordu ama
/// uygulamaya ait değildi: bu ekranın tamamı **kutu kullanmama** kararı
/// üzerine kurulu ([SettingsSection]), köşe ölçeği fotoğrafın "kart bileşeni"
/// gibi durmaması için özellikle küçük tutulmuş ([AppShape]). Her yerde
/// görülen o kart, uygulamayı ucuzlatıyordu.
///
/// Buradaki hâl hiçbir kutu çizmiyor. Dikkati çeken şey dekorasyon değil,
/// **kullanıcının kendi kareleri**: ücretsiz katmanın on gözü bir kontakt
/// baskısı gibi diziliyor, dolu gözlerde gerçek fotoğraflar duruyor. Ayarlar
/// sayfasında başka hiçbir görsel yok, dolayısıyla bu şerit kaçırılamıyor —
/// ve aynı anda "10 kare" sınırını bir ilerleme çubuğundan çok daha somut
/// anlatıyor: kullanıcı boş kalan gözleri sayabiliyor.
class ProCallout extends StatelessWidget {
  const ProCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope.preferences(context).proUnlocked
        ? const _Owned()
        : const _Offer();
  }
}

/// Ücretsiz katmandaki hâli: kontakt baskısı ve teklif.
class _Offer extends StatelessWidget {
  const _Offer();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final repository = AppScope.of(context);

    return StreamBuilder<List<Note>>(
      stream: repository.watchRecent(limit: ProLimits.freeNotes),
      builder: (context, snapshot) {
        // En yeniden eskiye geliyor; şerit soldan sağa dolmalı.
        final frames = (snapshot.data ?? const <Note>[]).reversed.toList();

        return Pressable(
          onPressed: () => showPaywall(context),
          scale: 0.995,
          semanticLabel: l10n.paywallCta,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rule(
                label: '${l10n.appTitle} ${l10n.proBadge}',
                tint: palette.ember.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 18),
              Text(l10n.paywallHeadline, style: palette.title),
              const SizedBox(height: 16),
              _ContactSheet(
                frames: frames,
                cells: ProLimits.freeNotes,
                repository: repository,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.paywallSubtitle,
                style: palette.body.copyWith(
                  color: palette.inkSoft,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.paywallCta,
                      style: palette.bodyStrong.copyWith(
                        color: palette.ember,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: palette.ember,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ödemiş kullanıcının gördüğü hâl.
///
/// Ne şerit ne teklif: sayılacak bir sınır kalmadı. Parasını vermiş birine
/// aynı satışı göstermeye devam etmek, satın almayı unutulmuş bir şey gibi
/// gösterir. Geriye yalnızca durumu onaylamak kalıyor.
class _Owned extends StatelessWidget {
  const _Owned();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<int>(
      stream: AppScope.of(context).watchNoteCount(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Künye artık vurgu rengiyle. Nötr griyken bu şerit ayarlar
            // listesindeki herhangi bir bölüm başlığından ayırt edilmiyordu:
            // ödemiş kullanıcı sayfayı açtığında ödediğine dair hiçbir iz
            // görmüyordu.
            _Rule(
              label: '${context.l10n.appTitle} ${context.l10n.proBadge}',
              tint: palette.emberGlow,
            ),
            const SizedBox(height: 18),
            // Kilitli hâlde ücretsiz katmanın kapısı neredeyse kapalı bir
            // diyaframdır; burada aynı diyafram açılıyor. Rozet takmak yerine
            // zaten kurulu olan sembolü tersine çevirmek, "senin" demenin bu
            // uygulamaya ait yolu.
            ProOwnedMark(label: context.l10n.paywallOwned, centered: false),
            const SizedBox(height: 8),
            Text(
              context.l10n.paywallOwnedCount(snapshot.data ?? 0),
              style: palette.body.copyWith(color: palette.inkSoft),
            ),
          ],
        );
      },
    );
  }
}

/// Ücretsiz katmanın on gözü.
///
/// Dolu gözlerde kullanıcının gerçek kareleri, boşlarda film gözü. Köşeler
/// [AppShape.print] ölçeğinde, yani neredeyse dik: bu bir baskı, kart değil.
class _ContactSheet extends StatelessWidget {
  const _ContactSheet({
    required this.frames,
    required this.cells,
    required this.repository,
  });

  final List<Note> frames;
  final int cells;
  final NotesRepository repository;

  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth - _gap * (cells - 1)) / cells;
        final pixels = (side * MediaQuery.devicePixelRatioOf(context)).round();

        return Row(
          children: [
            for (var index = 0; index < cells; index++) ...[
              if (index > 0) const SizedBox(width: _gap),
              _Cell(
                side: side,
                // Küçültülmüş çözüm isteniyor: bu gözler ~30 punto, tam
                // çözünürlükte çözmek onlarca megabaytı boşuna belleğe alırdı.
                decodeWidth: pixels,
                file: index < frames.length
                    ? repository.imageOf(frames[index])
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.side, required this.decodeWidth, this.file});

  final double side;
  final int decodeWidth;
  final File? file;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final image = file;

    return SizedBox(
      width: side,
      height: side,
      child: ClipRSuperellipse(
        borderRadius: AppShape.all(3),
        child: image == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.canvasSunk,
                  border: Border.all(color: palette.hairline, width: 0.5),
                ),
              )
            : Image.file(
                image,
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
                filterQuality: FilterQuality.medium,
                // Dosya bir şekilde okunamıyorsa göz boş kalsın; kırık ikon
                // burada gerçek bir soruna işaret etmediği hâlde öyle okunur.
                errorBuilder: (context, _, _) =>
                    ColoredBox(color: palette.canvasSunk),
              ),
      ),
    );
  }
}

/// Bölüm başlığı: küçük kapiteller ve peşinden giden ince çizgi.
///
/// [SettingsSection]'ınkiyle aynı ritim — bu blok sayfaya ait olmalı, üstüne
/// yapıştırılmış bir reklam gibi durmamalı. Teklif kor tonunu taşır; sahiplik
/// hâli ise aynı yapıyı nötr mürekkeple kullanır.
class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.upper(label),
              style: palette.overline.copyWith(color: palette.ember),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ColoredBox(
              color: tint,
              child: const SizedBox(height: 0.5, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}
