import 'package:flutter/material.dart';

import '../../../../../core/theme/app_palette.dart';
import '../../../../settings/domain/app_settings.dart';
import '../../../data/notes_database.dart';
import '../../../data/notes_repository.dart';
import 'home_header.dart';
import 'note_card.dart';

/// Kayıtları güne göre kümelenmiş tek bir dikey akışta gösterir.
///
/// İki yoğunluk aynı veriyi farklı ölçekte çizer; aralarındaki geçiş
/// [DensityCrossfade] ile yapılır.
class NotesFeed extends StatelessWidget {
  const NotesFeed({
    super.key,
    required this.notes,
    required this.repository,
    required this.density,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleDensity,
    required this.onOpenSettings,
    required this.bottomInset,
  });

  final List<Note> notes;
  final NotesRepository repository;
  final FeedDensity density;
  final ValueChanged<Note> onOpen;
  final ValueChanged<Note> onDelete;
  final VoidCallback onToggleDensity;
  final VoidCallback onOpenSettings;

  /// Deklanşörün altta kapladığı alan; son kartın arkasında kalmaması için.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final gridded = density == FeedDensity.grid;

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
            gridded: gridded,
            onToggleDensity: onToggleDensity,
            onOpenSettings: onOpenSettings,
          ),
        ),
        // Izgarada gün ayraçları yok.
        //
        // Günde bir iki kayıt olduğunda her ayraç ızgarayı bölüyor ve satırlar
        // tek kartla kalıyordu — sıkışık görünmesi gereken bir düzen seyrek
        // duruyordu. Yoğun görünüm zamanı değil, çokluğu göstermek için var;
        // tarih zaten karta dokununca görünüyor.
        if (gridded)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: _Grid(notes: notes, feed: this),
          )
        else
          for (final section in _groupByDay(notes)) ...[
            SliverToBoxAdapter(child: DaySeparator(day: section.day)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _ColumnSection(section: section, feed: this),
            ),
          ],
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );
  }

  Widget _card(Note note, CardScale scale) => NoteCard(
    note: note,
    repository: repository,
    scale: scale,
    onTap: () => onOpen(note),
    onLongPress: () => onDelete(note),
  );

  /// Sıralı notları gün kümelerine böler. Notlar zaten yeniden eskiye sıralı
  /// geldiği için tek geçiş yeterli.
  static List<_DaySection> _groupByDay(List<Note> notes) {
    final sections = <_DaySection>[];

    for (final note in notes) {
      final day = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );
      if (sections.isEmpty || sections.last.day != day) {
        sections.add(_DaySection(day, [note]));
      } else {
        sections.last.notes.add(note);
      }
    }
    return sections;
  }
}

class _DaySection {
  _DaySection(this.day, this.notes);
  final DateTime day;
  final List<Note> notes;
}

/// Tek sütun: ilk kayıt daha uzun bir çerçeve alır, gerisi standart.
class _ColumnSection extends StatelessWidget {
  const _ColumnSection({required this.section, required this.feed});

  final _DaySection section;
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

/// İki sütun: kareler, daha çok kayıt tek bakışta.
class _Grid extends StatelessWidget {
  const _Grid({required this.notes, required this.feed});

  final List<Note> notes;
  final NotesFeed feed;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) =>
          feed._card(notes[index], CardScale.compact),
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
  const DensityCrossfade({super.key, required this.density, required this.child});

  final FeedDensity density;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
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
