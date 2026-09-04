import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../settings/domain/app_settings.dart';
import '../../../../reminders/reminder_service.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import '../../../domain/note_kind.dart';
import '../../../data/photo_aspect.dart';
import '../../../domain/note_age_group.dart';
import 'home_header.dart';
import 'note_card.dart';

/// Kayıtları anlamlı yaş aralıklarına ayrılmış tek bir akışta gösterir.
///
/// İki yoğunluk aynı veriyi farklı ölçekte çizer; aralarındaki geçiş
/// [DensityCrossfade] ile yapılır.
class NotesFeed extends StatelessWidget {
  const NotesFeed({
    super.key,
    required this.notes,
    required this.calendarReference,
    required this.reminderReference,
    required this.repository,
    required this.reminders,
    required this.settings,
    required this.density,
    required this.remindersActive,
    required this.onOpen,
    required this.onDelete,
    required this.onOpenSettings,
    required this.bottomInset,
    required this.searching,
    required this.filtering,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onToggleSearch,
    required this.selecting,
    required this.selectedIds,
    required this.onToggleSelection,
    this.collapsedGroups = const {},
    this.onToggleGroup,
  });

  final List<Note> notes;
  final DateTime calendarReference;
  final DateTime reminderReference;
  final NotesRepository repository;
  final ReminderService reminders;
  final AppSettings settings;
  final FeedDensity density;
  final bool remindersActive;
  final ValueChanged<Note> onOpen;
  final ValueChanged<Note> onDelete;
  final VoidCallback onOpenSettings;

  /// Deklanşörün altta kapladığı alan; son kartın arkasında kalmaması için.
  final double bottomInset;

  final bool searching;

  /// Arama kutusu açık olmak yetmiyor: akış ancak elde gerçek bir sorgu
  /// varken tek bir kümeye dönüşüyor. Kutuya dokunmak listeyi yerinden
  /// oynatmıyor, tarih omurgası duruyor; daralma yazmaya başlayınca oluyor.
  ///
  /// Bunu `searching` ile birleştirmek, boş bir kutu için bütün akışı
  /// söküp yeniden kurmak demekti — dokunuşta hissedilen takılma oradandı.
  final bool filtering;

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;

  /// Toplu silme kipi ve içindeki işaretli kimlikler.
  final bool selecting;
  final Set<int> selectedIds;
  final ValueChanged<Note> onToggleSelection;

  /// Kapatılmış zaman bölümleri.
  ///
  /// Durum akışın kendisinde değil ana ekranda duruyor: liste her veri
  /// yayınında yeniden kuruluyor ve burada tutulan bir küme her yeni kayıtta
  /// sıfırlanırdı. Seçimin (`selectedIds`) izlediği yol da aynı.
  final Set<NoteAgeGroup> collapsedGroups;

  /// Bölümü açıp kapatır. `null` ise ayraçlar hareketsiz — seçim kipinde
  /// böyle geliyor.
  final ValueChanged<NoteAgeGroup>? onToggleGroup;

  @override
  Widget build(BuildContext context) {
    final gridded = density == FeedDensity.grid;
    final sections = groupNotesByAge(
      notes,
      createdAtOf: (note) => note.createdAt,
      now: calendarReference,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: HomeHeader(
            palette: context.palette,
            topPadding: MediaQuery.paddingOf(context).top,
            noteCount: notes.length,
            onOpenSettings: onOpenSettings,
            searching: searching,
            resultCount: notes.length,
            searchController: searchController,
            searchFocus: searchFocus,
            onSearchChanged: onSearchChanged,
            onToggleSearch: onToggleSearch,
            selecting: selecting,
            selectedCount: selectedIds.length,
          ),
        ),
        // Arama sonucu tek bir kümedir: burada zaman başlıkları eşleşmeleri
        // gereksiz yere parçalar. Normal akışta ise aynı tarih omurgası hem
        // büyük kartta hem ızgarada korunur.
        if (filtering)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: _Grid(notes: notes, feed: this),
          )
        else
          for (final section in sections) ...[
            SliverToBoxAdapter(
              child: AgeSeparator(
                key: ValueKey('age-separator-${section.group.name}'),
                label: _labelFor(context, section.group),
                collapsed: collapsedGroups.contains(section.group),
                count: section.notes.length,
                onToggle: onToggleGroup == null
                    ? null
                    : () => onToggleGroup!(section.group),
              ),
            ),
            // Kapalı bölümün kayıtları ağaca hiç girmiyor: gizlemek yerine
            // çizmemek, uzun bir arşivde asıl kazancın kendisi.
            if (!collapsedGroups.contains(section.group))
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: gridded
                    ? _Grid(notes: section.notes, feed: this)
                    : _ColumnSection(section: section, feed: this),
              ),
          ],
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );
  }

  Widget _card(Note note, CardScale scale, {double? aspect}) {
    final reminderAt = remindersActive
        ? reminders.nextReminderAt(note, settings, now: reminderReference)
        : null;
    return NoteCard(
      note: note,
      repository: repository,
      scale: scale,
      aspect: aspect,
      now: reminderReference,
      reminderAt: reminderAt,
      selecting: selecting,
      selected: selectedIds.contains(note.id),
      // Süzülmüş kümede tarih ayıraçları yok: her kart kendi zamanını söyler.
      dated: filtering,
      // Seçim kipinde dokunmanın tek anlamı işaretlemektir: detay sayfası da,
      // basılı tutmanın tekli silme onayı da o kip boyunca kapalı.
      onTap: () => selecting ? onToggleSelection(note) : onOpen(note),
      onLongPress: () => onDelete(note),
    );
  }

  String _labelFor(BuildContext context, NoteAgeGroup group) {
    final l10n = context.l10n;
    final label = switch (group) {
      NoteAgeGroup.today => l10n.dateGroupToday,
      NoteAgeGroup.yesterday => l10n.dateGroupYesterday,
      NoteAgeGroup.pastWeek => l10n.dateGroupPastWeek,
      NoteAgeGroup.pastMonth => l10n.dateGroupPastMonth,
      NoteAgeGroup.pastThreeMonths => l10n.dateGroupPastThreeMonths,
      NoteAgeGroup.pastYear => l10n.dateGroupPastYear,
      NoteAgeGroup.older => l10n.dateGroupOlder,
    };
    return l10n.upper(label);
  }
}

/// Tek sütun: ilk kayıt daha uzun bir çerçeve alır, gerisi standart.
class _ColumnSection extends StatelessWidget {
  const _ColumnSection({required this.section, required this.feed});

  final NoteAgeSection<Note> section;
  final NotesFeed feed;

  @override
  Widget build(BuildContext context) {
    final newest = feed.notes.first.id;

    return SliverList.separated(
      itemCount: section.notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final note = section.notes[index];
        return feed._card(
          note,
          note.id == newest ? CardScale.hero : CardScale.full,
        );
      },
    );
  }
}

/// Telefon kamerası dikey karesi; oran okunana kadarki tahmin.
const _assumedAspect = 3 / 4;

/// Karenin oranı. Yalnız fotoğrafı olan kayıtlar için — karesiz kayıt
/// oranıyla değil, yazısıyla boylanıyor.
double _aspectOf(Note note) =>
    PhotoAspect.peek(note.imageName) ?? _assumedAspect;

/// Sütunların arası ve kutuların arası.
const _gridGutter = 12.0;
const _gridStep = 18.0;

/// İki sütun, eşit yükseklikte olmayan kutular.
///
/// Kutular hizalı bir ızgara yerine kendi boylarında dizilir. Yükseklik iki
/// şeyden gelir: karenin gerçek oranı ve notun uzunluğu. Böylece düzen katalog
/// değil, pano gibi okunur — ve hiçbir kare kutuya sığsın diye kırpılmaz.
///
/// Oranlar [PhotoAspect] ile dosya başlıklarından okunur; çözülene kadar
/// telefon karesinin olağan oranı varsayılır, böylece ilk kare de yakın durur.
///
/// Sütunlar iki ayrı tembel listeden geliyor, tek bir "masonry" sliver'ından
/// değil. Akış yaş bölümlerine ayrıldığı için ekranda aynı anda birden çok
/// ızgara bulunuyor ve o sliver, kendisi tamamen yukarıda kaldığında elinde
/// tek çocuk bırakıyor; sütunlardan birinin başlangıcını artık bilemediği için
/// her karede tüm kaydırmayı kendi konumu kadar geri çekiyordu. Parmak aşağı
/// gidiyor, liste başa dönüyor, eski kayıtlara hiç ulaşılamıyordu.
/// [SliverList] bu duruma düşmüyor.
class _Grid extends StatefulWidget {
  const _Grid({required this.notes, required this.feed});

  final List<Note> notes;
  final NotesFeed feed;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  @override
  void initState() {
    super.initState();
    _warm();
  }

  @override
  void didUpdateWidget(_Grid old) {
    super.didUpdateWidget(old);
    if (!_samePhotos(old.notes, widget.notes)) _warm();
  }

  bool _samePhotos(List<Note> before, List<Note> after) {
    if (before.length != after.length) return false;
    for (var index = 0; index < before.length; index++) {
      if (before[index].id != after[index].id ||
          before[index].imageName != after[index].imageName) {
        return false;
      }
    }
    return true;
  }

  Future<void> _warm() async {
    // Karesiz kayıtların okunacak başlığı yok; hepsi aynı boş anahtara
    // yazılıp önbelleği kirletirdi.
    final files = {
      for (final note in widget.notes)
        if (note.hasPhoto) note.imageName: widget.feed.repository.imageOf(note),
    };
    await PhotoAspect.warm(files);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Kart baskıyı bu genişlikte çözüyor; paylaştırma da aynı sayıyı kullanır.
    // Alt sınır kasıtlı: yüzey bir an sıfır genişlikte ölçülürse (ekran
    // döndürme, çok dar bir pencere) tahmin sonsuza gider ve paylaştırma
    // patlar. Bir piksel, o kareyi sessizce geçirmeye yeter.
    final width = math.max(1.0, (MediaQuery.sizeOf(context).width - 44) / 2);
    final columns = _deal(width);

    return SliverCrossAxisGroup(
      slivers: [
        for (var index = 0; index < columns.length; index++)
          _GridColumn(
            notes: columns[index],
            feed: widget.feed,
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : _gridGutter / 2,
              right: index == 0 ? _gridGutter / 2 : 0,
            ),
          ),
      ],
    );
  }

  /// Kareleri sütunlara paylaştırır: sıradaki kare, o an daha kısa duran
  /// sütuna iner. Izgaranın kuralı bu; tek fark yüksekliğin ölçülmesi değil,
  /// kestirilmesi.
  List<List<Note>> _deal(double width) {
    final columns = [<Note>[], <Note>[]];
    final heights = [0.0, 0.0];

    for (final note in widget.notes) {
      final target = heights[0] <= heights[1] ? 0 : 1;
      columns[target].add(note);
      heights[target] += _estimate(note, width) + _gridStep;
    }

    return columns;
  }

  /// Bir kutunun kabaca kaç piksel tutacağı.
  ///
  /// Yalnızca sütun seçimi için. Yanılırsa sütunlardan biri diğerinden birkaç
  /// piksel uzun biter; hiçbir kutunun çizimi değişmez, çünkü kutular kendi
  /// gerçek boylarında diziliyor. Baskı baskın terim; künyenin yüksekliği
  /// kartın kendi yapısından toplanıyor.
  double _estimate(Note note, double width) {
    // Karesiz kayıtta kâğıt yazısı kadar; oran diye bir şey yok.
    var height = note.hasPhoto
        ? width / _aspectOf(note)
        : textPrintHeight(note.body, width, scale: CardScale.compact);

    // Karesiz kayıtta yazı baskının içinde; künyenin altında ikinci bir satır
    // yok, dolayısıyla eklenecek yükseklik de yok.
    if (note.isTextOnly || note.body.isEmpty) {
      height += 7;
    } else {
      // Kart notu en çok üç satır gösteriyor; satır sayısı için ortalama harf
      // genişliğinden kaba bir sayım yetiyor.
      final lines = (note.body.length * 7 / width).ceil().clamp(1, 3);
      height += 9 + lines * 16.5 + 5;
    }

    height += 12; // saat satırı
    if (note.expiresAt != null) height += 9; // ömür izi
    if (note.remindAt != null) height += 17; // hatırlatma çentiği

    return height;
  }
}

/// Izgaranın tek sütunu.
class _GridColumn extends StatelessWidget {
  const _GridColumn({
    required this.notes,
    required this.feed,
    required this.padding,
  });

  final List<Note> notes;
  final NotesFeed feed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: notes.length,
        separatorBuilder: (_, _) => const SizedBox(height: _gridStep),
        itemBuilder: (context, index) {
          final note = notes[index];
          return feed._card(
            note,
            CardScale.compact,
            aspect: note.hasPhoto ? _aspectOf(note) : null,
          );
        },
      ),
    );
  }
}

/// İki yoğunluk arasındaki geçiş.
///
/// Kartların yerlerini birebir taşımak (Photos'taki yakınlaştırma gibi) tembel
/// bir listede mümkün değil; onun yerine giden düzen hafifçe *büyüyerek*
/// dağılır, gelen düzen *küçükten* yerine oturur. Göz bunu bir yeniden
/// dizilim olarak okur, bir kesme olarak değil.
class DensityCrossfade extends StatelessWidget {
  const DensityCrossfade({
    super.key,
    required this.density,
    required this.child,
  });

  final FeedDensity density;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInCubic,
      // Geçiş boyunca iki düzen bir an birlikte duruyor ve aynı kare iki kez
      // çiziliyor. Hero etiketleri kayıt kimliğine bağlı olduğu için o
      // pencerede bir karta dokunmak "aynı etiketten iki tane" hatasına
      // dönüşüyordu; çekilen düzen taşımanın dışında bırakılıyor, uçuş her
      // zaman kalan düzenden başlıyor.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final leaving in previous)
            HeroMode(enabled: false, child: leaving),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final entering = animation.status != AnimationStatus.reverse;
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: entering ? 0.94 : 1.06,
              end: 1,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(density), child: child),
    );
  }
}
