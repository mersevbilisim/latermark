import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/shutter_confirm.dart';
import '../../../../shared/widgets/icon_orb.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../home/widgets/note_photo.dart';
import 'widgets/detail_sheet.dart';
import 'widgets/edit_note_sheet.dart';

/// Tek bir kaydın tam görünümü.
///
/// Not, kimliğiyle izlenir — düzenlendiğinde ekran kendiliğinden tazelenir,
/// süresi dolup silindiğinde ise sessizce kapanır.
class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  NotesRepository? _repository;
  Stream<Note?>? _note;

  /// Fotoğrafa dokununca arayüz çekilir; kare tek başına kalır.
  bool _chrome = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository != _repository) {
      _repository = repository;
      _note = repository.watchNote(widget.noteId);
      // Kayda bakıldı: hatırlatma sayacı buradan yeniden başlar.
      unawaited(repository.markSeen(widget.noteId));
    }
  }

  Future<void> _delete(Note note) async {
    final confirmed = await showShutterConfirm(
      context,
      photo: _repository!.imageOf(note),
      title: note.body.isEmpty ? 'Bu kare silinsin mi?' : note.body,
      caption: 'Fotoğraf ve not birlikte kalkacak.',
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await _repository!.delete(note);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Silinemedi. Tekrar dene.', error: true);
      return;
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnPhoto.canvasDeep,
      body: StreamBuilder<Note?>(
        stream: _note,
        builder: (context, snapshot) {
          final note = snapshot.data;

          // Kayıt otomatik silme ile ortadan kalktıysa ekranda tutmanın anlamı
          // yok; ilk kareden sonra kapan.
          if (snapshot.hasData && note == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
            return const SizedBox.shrink();
          }
          if (note == null) return const SizedBox.shrink();

          return Stack(
            fit: StackFit.expand,
            children: [
              // Kare ekranı tam doldurmadığında kalan boşluğu düz siyah yerine
              // fotoğrafın kendisinin bulanık, karartılmış hâli kapatır.
              _BlurredBackdrop(file: _repository!.imageOf(note)),

              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _chrome = !_chrome),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Hero(
                    tag: 'note-photo-${note.id}',
                    child: NotePhoto(
                      file: _repository!.imageOf(note),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              _Chrome(
                visible: _chrome,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 8,
                      left: 20,
                      right: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconOrb(
                          icon: Icons.arrow_back_rounded,
                          semanticLabel: 'Geri',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        IconOrb(
                          icon: Icons.delete_outline_rounded,
                          semanticLabel: 'Sil',
                          tint: OnPhoto.danger,
                          onPressed: () => _delete(note),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              _Chrome(
                visible: _chrome,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DetailSheet(
                    note: note,
                    onEdit: () => showEditNoteSheet(
                      context,
                      note: note,
                      repository: _repository!,
                    ),
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

class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Küçük çözünürlükte çözülür: hem bulanıklık ucuzlar hem de sonuç
          // aynı görünür.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: NotePhoto(file: file, decodeWidth: 96),
          ),
          const ColoredBox(color: Color(0xB3050506)),
        ],
      ),
    );
  }
}

/// Görünürken dokunmaları alan, gizliyken tamamen çekilen arayüz katmanı.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.medium,
        curve: AppMotion.ease,
        child: child,
      ),
    );
  }
}
