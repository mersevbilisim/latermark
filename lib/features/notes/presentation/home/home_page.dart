import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/shutter_confirm.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../capture/capture_page.dart';
import '../detail/note_detail_page.dart';
import 'widgets/notes_feed.dart';
import 'widgets/shutter_dock.dart';

/// Açılış ekranı: bir deklanşör, altında kayıtlar. Başka hiçbir şey yok.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  NotesRepository? _repository;
  Stream<List<Note>>? _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository != _repository) {
      _repository = repository;
      _notes = repository.watchNotes();
    }
  }

  void _openCamera() {
    Navigator.of(context).push(AppRoutes.shutter(const CapturePage()));
  }

  void _openNote(Note note) {
    Navigator.of(context).push(AppRoutes.lift(NoteDetailPage(noteId: note.id)));
  }

  void _openSettings() {
    Navigator.of(context).push(AppRoutes.lift(const SettingsPage()));
  }

  void _toggleDensity(FeedDensity current) {
    AppScope.settingsOf(context).setDensity(current.other);
  }

  /// Karta basılı tutunca doğrudan silme onayı açılır — detaya girmeden.
  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showShutterConfirm(
      context,
      photo: _repository!.imageOf(note),
      title: note.body.isEmpty ? 'Bu kare silinsin mi?' : note.body,
      caption: 'Fotoğraf ve not birlikte kalkacak.',
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository!.delete(note);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Silinemedi. Tekrar dene.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = AppScope.preferences(context).density;

    return Scaffold(
      body: StreamBuilder<List<Note>>(
        stream: _notes,
        builder: (context, snapshot) {
          // İlk kare gelene kadar boş tuval: deklanşörün "ortadan aşağı"
          // hareketi yalnızca gerçek bir durum değişiminde görünmeli.
          if (!snapshot.hasData) return const _Canvas();

          final notes = snapshot.data!;
          return _Canvas(
            child: Stack(
              children: [
                if (notes.isNotEmpty)
                  DensityCrossfade(
                    density: density,
                    child: NotesFeed(
                      notes: notes,
                      repository: _repository!,
                      density: density,
                      onOpen: _openNote,
                      onDelete: _confirmDelete,
                      onToggleDensity: () => _toggleDensity(density),
                      onOpenSettings: _openSettings,
                      bottomInset: ShutterDock.dockHeight,
                    ),
                  ),
                ShutterDock(
                  docked: notes.isNotEmpty,
                  onCapture: _openCamera,
                  onOpenSettings: notes.isEmpty ? _openSettings : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Düz bir zemin yerine, üstten aşağı hafifçe açılan bir tuval. Fark neredeyse
/// görünmez ama ekranın "ölü" durmasını engeller.
class _Canvas extends StatelessWidget {
  const _Canvas({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 1.1,
          colors: [
            Color.lerp(
              palette.canvas,
              palette.isDark ? Colors.white : Colors.black,
              0.035,
            )!,
            palette.canvas,
          ],
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}
