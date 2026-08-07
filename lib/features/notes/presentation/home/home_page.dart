import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/shutter_confirm.dart';
import '../../../home_widget/home_widget_link.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../../domain/retention.dart';
import '../compose/compose_page.dart';
import '../capture/capture_page.dart';
import '../detail/note_detail_page.dart';
import '../import/gallery_import.dart';
import '../import/shared_import.dart';
import 'widgets/notes_feed.dart';
import 'widgets/shutter_dock.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../paywall/domain/pro_limits.dart';
import '../../../paywall/presentation/paywall_host.dart';

/// Açılış ekranı: bir deklanşör, altında kayıtlar. Başka hiçbir şey yok.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  NotesRepository? _repository;
  Stream<List<Note>>? _notes;
  StreamSubscription<void>? _sharedImportSubscription;
  late final HomeWidgetLink _widgetLink;
  StreamSubscription<int>? _widgetLinkSubscription;
  bool _pickingFromGallery = false;
  bool _drainingSharedImports = false;
  int? _activeWidgetNoteId;
  int? _queuedWidgetNoteId;

  /// Arama durumu burada yaşıyor: üstlük bir sliver delegesi ve kaydırmanın
  /// her karesinde yeniden kuruluyor, denetim durumunu orada tutamayız.
  bool _searching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Yürürlükteki aramanın sonucu — metin değil, eşleşen kimlikler.
  SearchHits _hits = SearchHits.none;
  Timer? _searchDebounce;

  /// Sorgu artık veritabanına gidiyor, yani cevap bir sonraki karede değil bir
  /// süre sonra geliyor. Bu sayaç hangi cevabın güncel olduğunu söylüyor:
  /// hızlı yazan bir kullanıcıda istekler sırayla bitmeyebilir ve geciken eski
  /// bir cevap yeni sonucun üstüne yazarsa liste yanlış kalırdı.
  int _searchTicket = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetLink = HomeWidgetLink();
    _widgetLinkSubscription = _widgetLink.noteIds.listen(_queueWidgetNote);
    unawaited(_widgetLink.start());
    _sharedImportSubscription = SharedImportBridge.onImportAvailable.listen((
      _,
    ) {
      _drainSharedImports();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainSharedImports();
    });
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recoverInterruptedGalleryPick();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _sharedImportSubscription?.cancel();
    _widgetLinkSubscription?.cancel();
    unawaited(_widgetLink.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drainSharedImports();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository != _repository) {
      _repository = repository;
      _notes = repository.watchNotes();
    }
  }

  /// Yeni kayıt kapısı.
  ///
  /// Kontrol **çekimden önce** yapılıyor. Fotoğrafı çektirip notu yazdırdıktan
  /// sonra "limit doldu" demek, kullanıcının emeğini çöpe atmak olurdu.
  Future<bool> _allowNewNote() async {
    final settings = AppScope.preferences(context);
    final notes = await AppScope.of(context).watchNotes().first;
    if (!mounted) return false;

    if (!ProLimits.blocksNewNote(notes.length, isPro: settings.proUnlocked)) {
      return true;
    }

    await showPaywall(context, reason: PaywallReason.noteLimit);
    return false;
  }

  Future<void> _openCamera() async {
    if (!await _allowNewNote() || !mounted) return;
    await Navigator.of(context).push(AppRoutes.shutter(const CapturePage()));
  }

  Future<void> _pickFromGallery() async {
    if (_pickingFromGallery) return;
    if (!await _allowNewNote() || !mounted) return;
    setState(() => _pickingFromGallery = true);

    // Platform seçicisini aynı çağrı yığınında açarsak Flutter yeni durumu
    // çizemeden uygulamanın üstüne native ekran gelir. Bir kare beklemek,
    // dokunmanın karşılığını anında gösterir; hızlı cihazlarda bile düğme
    // tepkisizmiş gibi kalmaz.
    await WidgetsBinding.instance.endOfFrame;

    try {
      final image = await GalleryImport.pick();
      if (image == null || !mounted) return;
      _openImportedImage(image);
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.toastPhotoPickFailed, error: true);
    } finally {
      if (mounted) setState(() => _pickingFromGallery = false);
    }
  }

  Future<void> _recoverInterruptedGalleryPick() async {
    try {
      final image = await GalleryImport.recover();
      if (image == null || !mounted) return;
      _openImportedImage(image);
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.toastPendingPickFailed, error: true);
    }
  }

  void _openImportedImage(XFile image) {
    Navigator.of(context).push(
      AppRoutes.lift(
        ComposePage(capture: image, source: ComposeSource.gallery),
      ),
    );
  }

  Future<void> _drainSharedImports() async {
    if (_drainingSharedImports || !mounted || _repository == null) return;
    _drainingSharedImports = true;

    try {
      while (mounted) {
        final shared = await SharedImportBridge.takePending();
        if (shared == null || !mounted) break;

        if (shared.saveImmediately) {
          try {
            await _repository!.create(
              capture: shared.image,
              body: shared.initialText,
              retention: const RetentionChoice.off(),
              createdAt: shared.createdAt,
            );
            await SharedImportBridge.complete(shared.id);
            if (mounted) showToast(context, context.l10n.toastSharedPhotoAdded);
          } catch (_) {
            if (mounted) {
              showToast(
                context,
                context.l10n.toastSharedPhotoFailed,
                error: true,
              );
            }
            break;
          }
          continue;
        }

        await Navigator.of(context).push(
          AppRoutes.lift(
            ComposePage(
              capture: shared.image,
              source: ComposeSource.shared,
              initialText: shared.initialText,
              capturedAt: shared.createdAt,
              sharedImportId: shared.id,
            ),
          ),
        );
        // Sistem geri hareketinde PopScope temizliği eşzamansız başlayabilir.
        // Route döndüğünde kuyruğu bir kez daha idempotent biçimde kapatmak,
        // aynı paylaşımın kısa bir yarışta yeniden açılmasını önler.
        await SharedImportBridge.complete(shared.id);
      }
    } finally {
      _drainingSharedImports = false;
      final queued = _queuedWidgetNoteId;
      if (queued != null) _queueWidgetNote(queued);
    }
  }

  void _queueWidgetNote(int noteId) {
    if (!mounted) return;
    if (_activeWidgetNoteId == noteId) return;
    if (_activeWidgetNoteId != null || _drainingSharedImports) {
      _queuedWidgetNoteId = noteId;
      return;
    }

    _queuedWidgetNoteId = null;
    // İlk frame gelmeden ikinci bir native olay ulaşırsa da iki detay sayfası
    // planlanmasın; "active" hem planlanmış hem açık rotayı temsil eder.
    _activeWidgetNoteId = noteId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openWidgetNote(noteId);
    });
  }

  Future<void> _openWidgetNote(int noteId) async {
    if (!mounted || _activeWidgetNoteId != noteId) return;
    await Navigator.of(
      context,
    ).push(AppRoutes.lift(NoteDetailPage(noteId: noteId)));
    _activeWidgetNoteId = null;

    final queued = _queuedWidgetNoteId;
    if (queued != null && mounted) _queueWidgetNote(queued);
  }

  void _openNote(Note note) {
    Navigator.of(context).push(AppRoutes.lift(NoteDetailPage(noteId: note.id)));
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchDebounce?.cancel();
        _searchTicket++;
        _hits = SearchHits.none;
        _searchController.clear();
        _searchFocus.unfocus();
      }
    });
  }

  /// Her tuş vuruşu bir sorgu değil.
  ///
  /// Gecikme olmadan "fatura" yazmak altı ayrı tam tarama başlatırdı ve ilk
  /// beşinin sonucu daha ekrana ulaşmadan geçersizleşirdi. 120 ms, yazmayı
  /// bekletecek kadar uzun değil ama ardışık tuşları tek sorguda toplamaya
  /// yetiyor.
  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    // Sorgu tümden silindiğinde bekletmenin anlamı yok: liste anında dolu
    // hâline dönmeli.
    if (trimmed.isEmpty) {
      _searchTicket++;
      if (_hits.filtering) setState(() => _hits = SearchHits.none);
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 120),
      () => _runSearch(trimmed),
    );
  }

  Future<void> _runSearch(String query) async {
    final ticket = ++_searchTicket;
    final hits = await _repository!.search(query);
    // Arada yeni bir tuşa basılmışsa bu cevap artık eski.
    if (!mounted || ticket != _searchTicket) return;
    setState(() => _hits = hits);
  }

  void _openSettings() {
    Navigator.of(context).push(AppRoutes.lift(const SettingsPage()));
  }



  /// Karta basılı tutunca doğrudan silme onayı açılır — detaya girmeden.
  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showShutterConfirm(
      context,
      photo: _repository!.imageOf(note),
      title: note.body.isEmpty ? context.l10n.deleteConfirmTitle : note.body,
      caption: context.l10n.deleteConfirmCaption,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository!.delete(note);
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.toastDeleteFailed, error: true);
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

          final all = snapshot.data!;
          // Süzme akışta değil burada: sorgu değiştikçe akışı yeniden kurmak
          // listeyi baştan yükletirdi ve her tuşta titreme yaratırdı.
          //
          // Eşleşmenin kendisi veritabanında bulunuyor; burada kalan iş bir
          // küme sorgusu. Liste akıştan yeni bir değer aldığında (yeni kayıt,
          // süresi dolan not) süzme yeniden hesaplanmıyor, aynı kimlik kümesi
          // uygulanıyor — arada eklenen bir kayıt aramaya girmiyorsa da doğru
          // olan bu: kullanıcı yazdığı sorgunun sonucunu görüyor.
          final notes = _searching && _hits.filtering
              ? all.where((note) => _hits.contains(note.id)).toList()
              : all;

          return _Canvas(
            child: Stack(
              children: [
                if (all.isNotEmpty)
                  DensityCrossfade(
                    density: density,
                    child: NotesFeed(
                      notes: notes,
                      repository: _repository!,
                      density: density,
                      onOpen: _openNote,
                      onDelete: _confirmDelete,
                      onOpenSettings: _openSettings,
                      // Deklanşörün perdesi güvenli alanı da kaplıyor; akış
                      // yalnızca `dockHeight` ayırırsa son kaydın notu
                      // perdenin altında sönük kalıyor.
                      bottomInset:
                          ShutterDock.dockHeight +
                          MediaQuery.paddingOf(context).bottom,
                      searching: _searching,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onSearchChanged: _onQueryChanged,
                      onToggleSearch: _toggleSearch,
                    ),
                  ),
                ShutterDock(
                  docked: notes.isNotEmpty,
                  importing: _pickingFromGallery,
                  noteCount: notes.length,
                  isPro: AppScope.preferences(context).proUnlocked,
                  onCapture: _openCamera,
                  onImport: _pickFromGallery,
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
