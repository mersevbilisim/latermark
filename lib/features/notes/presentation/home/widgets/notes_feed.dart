import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/utils/app_format.dart';
import '../../../../../l10n/l10n_context.dart';
import '../../../../settings/domain/app_settings.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
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
    required this.repository,
    required this.density,
    required this.remindersActive,
    required this.onOpen,
    required this.onDelete,
    required this.onOpenSettings,
    required this.bottomInset,
    required this.searching,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onToggleSearch,
  });

  final List<Note> notes;
  final DateTime calendarReference;
  final NotesRepository repository;
  final FeedDensity density;
  final bool remindersActive;
  final ValueChanged<Note> onOpen;
  final ValueChanged<Note> onDelete;
  final VoidCallback onOpenSettings;

  /// Deklanşörün altta kapladığı alan; son kartın arkasında kalmaması için.
  final double bottomInset;

  final bool searching;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;

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
          ),
        ),
        // Arama sonucu tek bir kümedir: burada zaman başlıkları eşleşmeleri
        // gereksiz yere parçalar. Normal akışta ise aynı tarih omurgası hem
        // büyük kartta hem ızgarada korunur.
        if (searching)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: _Grid(notes: notes, feed: this),
          )
        else
          for (final section in sections) ...[
            SliverToBoxAdapter(
              child: AgeSeparator(label: _labelFor(context, section.group)),
            ),
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

  Widget _card(Note note, CardScale scale, {double? aspect}) => NoteCard(
    note: note,
    repository: repository,
    scale: scale,
    aspect: aspect,
    now: calendarReference,
    remindersActive: remindersActive,
    onTap: () => onOpen(note),
    onLongPress: () => onDelete(note),
  );

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

/// İki sütun, eşit yükseklikte olmayan kutular.
///
/// Kutular hizalı bir ızgara yerine kendi boylarında dizilir. Yükseklik iki
/// şeyden gelir: karenin gerçek oranı ve notun uzunluğu. Böylece düzen katalog
/// değil, pano gibi okunur — ve hiçbir kare kutuya sığsın diye kırpılmaz.
///
/// Oranlar [PhotoAspect] ile dosya başlıklarından okunur; çözülene kadar
/// telefon karesinin olağan oranı varsayılır, böylece ilk kare de yakın durur.
class _Grid extends StatefulWidget {
  const _Grid({required this.notes, required this.feed});

  final List<Note> notes;
  final NotesFeed feed;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  /// Telefon kamerası dikey karesi; oran okunana kadarki tahmin.
  static const _assumed = 3 / 4;

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
    final files = {
      for (final note in widget.notes)
        note.imageName: widget.feed.repository.imageOf(note),
    };
    await PhotoAspect.warm(files);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 18,
      crossAxisSpacing: 12,
      childCount: widget.notes.length,
      itemBuilder: (context, index) {
        final note = widget.notes[index];
        return widget.feed._card(
          note,
          CardScale.compact,
          aspect: PhotoAspect.peek(note.imageName) ?? _assumed,
        );
      },
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
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
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
