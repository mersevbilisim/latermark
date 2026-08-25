import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/shutter_confirm.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../../data/photo_aspect.dart';
import '../../data/photo_tone.dart';
import '../../domain/note_reminder.dart';
import '../../domain/share_message.dart';
import '../../../../shared/widgets/colophon_bar.dart';
import '../../../../shared/widgets/icon_orb.dart';
import '../home/widgets/note_photo.dart';
import 'widgets/detail_sheet.dart';
import 'widgets/edit_note_sheet.dart';
import 'widgets/photo_dismiss_surface.dart';
import 'widgets/photo_viewer_page.dart';
import '../reminder/reminder_schedule_page.dart';

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage>
    with SingleTickerProviderStateMixin {
  /// Künyenin dinlenme yüksekliği.
  static const _chromeExtent = 56.0;

  /// Yazma hâlinde künye yok olmaz, incelir. Sıfıra indirmek fotoğrafı status
  /// bar'a yapıştırıyordu.
  static const _chromeExtentEditing = 14.0;

  /// Künye ile baskı arasındaki nefes. Denetimlerin yüksekliğinden ayrı
  /// tutuluyor: künye şeridi kendi ölçüsünde kalırken kare aşağı iner.
  static const _printInset = 72.0;
  static const _printInsetEditing = 18.0;

  /// Okuma ile yazma hâli arasındaki düzen morfu.
  ///
  /// Bilinçli olarak [AppMotion.slow] değil. Bu geçiş tek başına oynamıyor:
  /// düzenleyici odağı isteyince iOS klavyesi de yükseliyor ve `viewInsets`
  /// her karede sayfayı yeniden yerleştiriyor. 620 ms'lik bir morf, klavye
  /// çoktan yerine oturduktan sonra bile kareyi küçültmeye devam ediyor —
  /// iki hareket üst üste binince ilk dokunuş takılıyormuş gibi okunuyor.
  static const _morphDuration = AppMotion.medium;

  final ScrollController _scrollController = ScrollController();
  final EditNoteController _editController = EditNoteController();

  /// Sayfanın açılış zamanı. Bölümler bunun farklı aralıklarında yerine gelir;
  /// fotoğraf inerken metin ve künye arkasından sırayla yetişir.
  late final AnimationController _entrance;
  late final CurvedAnimation _chromeReveal;

  /// Kaydırma konumu. `setState` ile taşınmıyor: künyenin zemini her karede
  /// yeniden değerlendiriliyor, sayfanın tamamı değil.
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  NotesRepository? _repository;
  Stream<Note?>? _note;
  bool _entranceStarted = false;
  bool _editing = false;

  /// Paylaşma isteği verildi, sistem sayfası henüz gelmedi.
  bool _sharing = false;
  double _dismissProgress = 0;
  double _editorDismissOffset = 0;
  double _editorDismissProgress = 0;
  double _editorOverscrollPeak = 0;
  bool _editorOverscrollArmed = false;
  bool _editorOverscrollCommitInFlight = false;
  final Set<String> _warmingPhotos = <String>{};

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
    );
    _chromeReveal = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(.10, .58, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository != _repository) {
      _repository = repository;
      _note = repository.watchNote(widget.noteId);
      final reminders = context.reminders;
      unawaited(() async {
        // `cancel(id:)` native tekrarın bekleyen kaydını da kaldırabilir.
        // Önce tepsiyi temizleyip sonra not akışını yayınlamak, sync'in kaydı
        // eksik görüp tek seferde yeniden kurmasını garanti eder.
        await reminders.dismissNote(widget.noteId);
        await repository.markSeen(widget.noteId);
      }());
    }

    if (!_entranceStarted) {
      _entranceStarted = true;
      // "Hareketi azalt" açıkken sahne kurulmaz, kurulmuş olarak gelir.
      if (MediaQuery.disableAnimationsOf(context)) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editController.dispose();
    _chromeReveal.dispose();
    _entrance.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ actions

  Future<void> _openPhoto(Note note) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showPhotoViewer(
      context,
      photo: _repository!.imageOf(note),
      heroTag: 'note-photo-${note.id}',
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      aspect: PhotoAspect.peek(note.imageName),
    );
  }

  void _beginEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    if (_scrollController.hasClients && _scrollController.offset > 0.5) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: AppMotion.medium,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _finishEditing() {
    if (!_editing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      _editorDismissOffset = 0;
      _editorDismissProgress = 0;
    });
  }

  /// Anahtar açık kaydedildi: kararın ikinci yarısı kendi sayfasında.
  ///
  /// Panel kapandıktan sonra açılıyor, çünkü sayfa geri döndüğünde detayın
  /// okuma hâlinde beklemesi gerekiyor — düzenleme kipine geri düşmek,
  /// kaydedilmiş bir notu yeniden "yarım" göstermek olurdu.
  void _openReminderSchedule(Note note, ReminderChoice initial) {
    Navigator.of(context).push(
      AppRoutes.lift(
        ReminderSchedulePage(
          noteId: note.id,
          initial: initial,
          // Kayıtlı silinme anı hatırlatmadan türemişse söz zaten verilmiş;
          // ekran o anahtarı açık açsın.
          initialDeleteAfter: isReminderExpiry(
            remindAt: note.remindAt,
            expiresAt: note.expiresAt,
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Note note) async {
    final confirmed = await showShutterConfirm(
      context,
      photo: _repository!.imageOf(note),
      title: note.body.isEmpty ? context.l10n.deleteConfirmTitle : note.body,
      caption: context.l10n.deleteConfirmCaption,
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await _repository!.delete(note);
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.toastDeleteFailed, error: true);
      return;
    }
    if (!mounted) return;
    navigator.pop();
  }

  /// İmzada görünen platform adı. Uygulama yalnız bu iki mağazada var.
  String get _sharePlatform =>
      defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'iOS';

  Future<void> _shareNote(Note note) async {
    // Sistem paylaşım sayfası anında gelmiyor: fotoğraf dosyası hazırlanırken
    // ekranda hiçbir şey olmuyordu ve dokunuş yutulmuş gibi duruyordu.
    // `share()` sayfa *kapanınca* tamamlandığı için bekleme, tam olarak
    // sayfanın açılmasını beklediğimiz süre boyunca görünür kalıyor.
    if (_sharing) return;
    // İmza kararı **ilk await'ten önce** okunuyor: paylaşım sayfası açıkken
    // ayar değişse bile gönderilen metin, kullanıcının dokunduğu andaki
    // tercihi taşır.
    final settings = AppScope.preferences(context);
    final signature = settings.shareSignature
        ? context.l10n.shareSignature(_sharePlatform)
        : null;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_repository!.imageOf(note).path)],
          text: shareMessage(body: note.body, signature: signature),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ----------------------------------------------------------------- dismiss

  Future<bool> _preparePhotoDismiss() async {
    if (!_editing) return true;
    FocusManager.instance.primaryFocus?.unfocus();
    return _editController.saveForDismiss();
  }

  Future<bool> _prepareThumbDismiss() async {
    // Klavye açıksa ilk aşağı çekiş kapatma emri değildir. Önce yazma
    // bağlamını sakin biçimde kapatır; ikinci hareket rotayı çekebilir.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return false;
    }
    return _preparePhotoDismiss();
  }

  bool _handleDetailScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _scrollOffset.value = notification.metrics.pixels;
    if (!_editing) return false;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _editorOverscrollPeak = 0;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      if (keyboardOpen) FocusManager.instance.primaryFocus?.unfocus();
      // İçerik aşağıdaysa aynı parmak hareketi önce tepeye dönmeli. Kapatma
      // ancak tepede başlayan bir sonraki bilinçli çekişte silahlanır.
      _editorOverscrollArmed =
          !keyboardOpen && notification.metrics.pixels <= .5;
      return false;
    }

    if (_editorOverscrollArmed &&
        (notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      final pull = (-notification.metrics.pixels).clamp(0.0, 180.0);
      if (pull > _editorOverscrollPeak) _editorOverscrollPeak = pull;
      return false;
    }

    if (notification is ScrollEndNotification) {
      final shouldDismiss =
          _editorOverscrollArmed && _editorOverscrollPeak >= 60;
      _editorOverscrollArmed = false;
      _editorOverscrollPeak = 0;
      if (shouldDismiss) unawaited(_dismissFromEditorOverscroll());
    }
    return false;
  }

  Future<void> _dismissFromEditorOverscroll() async {
    if (_editorOverscrollCommitInFlight) return;
    _editorOverscrollCommitInFlight = true;
    final allowed = await _preparePhotoDismiss();
    if (mounted && allowed) Navigator.of(context).pop();
    _editorOverscrollCommitInFlight = false;
  }

  void _setEditorDismissOffset(double value) {
    if (!mounted || value == _editorDismissOffset) return;
    setState(() => _editorDismissOffset = value);
  }

  void _setEditorDismissProgress(double value) {
    if (!mounted || value == _editorDismissProgress) return;
    setState(() => _editorDismissProgress = value);
  }

  /// Karenin oranını ve tonunu tek seferde okur: ilki sahnenin ölçüsünü,
  /// ikincisi sayfanın ışığını belirler.
  void _warmPhoto(Note note) {
    if (!_warmingPhotos.add(note.imageName)) return;
    final file = _repository!.imageOf(note);
    unawaited(
      Future.wait([
        PhotoAspect.warm({note.imageName: file}),
        PhotoTone.warm(note.imageName, file),
      ]).then((_) {
        _warmingPhotos.remove(note.imageName);
        if (mounted) setState(() {});
      }),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      // Rota bilinçli olarak opak değil: fotoğraf aşağı çekilirken ana akış
      // gerçek zamanlı olarak arkasından görünür.
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: PopScope(
        canPop: !_editing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _editing) _finishEditing();
        },
        child: StreamBuilder<Note?>(
          stream: _note,
          builder: (context, snapshot) {
            final note = snapshot.data;

            if (snapshot.connectionState == ConnectionState.active &&
                note == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).maybePop();
              });
              return const SizedBox.shrink();
            }
            if (note == null) return ColoredBox(color: palette.canvasSunk);

            return _buildPage(context, note);
          },
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, Note note) {
    final media = MediaQuery.of(context);
    final palette = context.palette;
    final l10n = context.l10n;
    final usableHeight = media.size.height - media.padding.top;
    final compactHeight = usableHeight < 500;
    final printWidth = media.size.width - (kDetailMargin * 2);

    // Sahne baskının *gerçek* dikdörtgenidir, içine fotoğraf yerleştirilen bir
    // çerçeve değil. Sabit oranlı bir kutu, kare ve yatay karelerin yanında
    // görünmez bir letterbox bırakıyordu; oranı karenin kendisi belirleyince
    // baskı ne kırpılır ne de boşluk taşır.
    final knownAspect = PhotoAspect.peek(note.imageName);
    final tone = PhotoTone.peek(note.imageName);
    if (knownAspect == null || tone == null) _warmPhoto(note);
    final aspect = knownAspect ?? (3 / 4);

    final restingStage = _fitPrint(
      printWidth,
      (usableHeight * .60).clamp(compactHeight ? 220.0 : 300.0, 640.0),
      aspect,
    );
    // Yazarken sahne, klavyeden *artan* yere göre ölçülüyor.
    //
    // `media.size` klavyeyi bilmez; ondan hesaplanan baskı yazarken de dinlenme
    // hâlindeki boyunda kalıyordu. 393×852'de bu, klavye açıkken ekranın yarısı
    // demek: panel 258'de başlıyor, 516'daki klavye çizgisine 258pt kalıyor,
    // panelin içeriği ise 379pt istiyor. Yazarken baskı referans, konu değil —
    // o yüzden klavye yükseldikçe küçülüyor ve yer nota kalıyor.
    //
    // Klavye payı sayfanın *dışından* okunuyor: `resizeToAvoidBottomInset`
    // gövdeyi zaten küçülttüğü için Scaffold'un altındaki MediaQuery insets'i
    // sıfırlamış oluyor. State'in kendi context'i Scaffold'un üstünde.
    final editingHeight =
        usableHeight - MediaQuery.viewInsetsOf(this.context).bottom;
    final editingStage = _fitPrint(
      printWidth,
      (editingHeight * .24).clamp(118.0, 230.0),
      aspect,
    );
    final stage = _editing ? editingStage : restingStage;
    final chromeExtent = _editing ? _chromeExtentEditing : _chromeExtent;
    final printInset = _editing ? _printInsetEditing : _printInset;

    final activeDismissProgress = math.max(
      _dismissProgress,
      _editorDismissProgress,
    );
    final dragChromeOpacity = (1 - (activeDismissProgress * 2.25))
        .clamp(0.0, 1.0)
        .toDouble();

    // Fotoğraf status bar'ın arkasına çizilmez; fakat tuval status bar'dan
    // sayfanın sonuna kadar kesintisizdir.
    return Transform.translate(
      offset: Offset(0, _editorDismissOffset),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: dragChromeOpacity,
              child: _DetailBackdrop(tone: tone),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: media.padding.top),
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _handleDetailScrollNotification,
                  child: CustomScrollView(
                    key: const ValueKey('note-detail-scroll'),
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: AnimatedContainer(
                          key: const ValueKey('detail-chrome-inset'),
                          duration: _morphDuration,
                          curve: Curves.easeOutQuart,
                          height: printInset,
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Center(
                          child: AnimatedContainer(
                            key: const ValueKey('note-photo-stage'),
                            duration: _morphDuration,
                            curve: Curves.easeOutQuart,
                            width: stage.width,
                            height: stage.height,
                            child: PhotoDismissSurface(
                              cornerRadius: AppShape.print,
                              // Açık temada beyaz bir kare, sıcak kâğıt zemine
                              // kenarsız akıyordu. Bu çizgi görülmez, yokluğu
                              // görülür.
                              borderColor: palette.hairline,
                              semanticLabel: l10n.openPhotoSemantic,
                              onTap: () => _openPhoto(note),
                              onDismissRequested: _preparePhotoDismiss,
                              onProgressChanged: (progress) {
                                if (progress == _dismissProgress || !mounted) {
                                  return;
                                }
                                setState(() => _dismissProgress = progress);
                              },
                              onDismissed: () {
                                if (mounted) Navigator.of(context).pop();
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Opacity(
                                    opacity: 1 - _dismissProgress,
                                    child: ColoredBox(
                                      color: palette.canvasSunk,
                                    ),
                                  ),
                                  HeroMode(
                                    // İnteraktif kapatmada baskı zaten parmağın
                                    // altında çıkar; ikinci bir Hero uçuşu yok.
                                    enabled: _dismissProgress <= .001,
                                    child: Hero(
                                      tag: 'note-photo-${note.id}',
                                      child: NotePhoto(
                                        file: _repository!.imageOf(note),
                                        fit: knownAspect == null
                                            ? BoxFit.contain
                                            : BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_editing)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: IgnorePointer(
                            ignoring: _dismissProgress > .001,
                            child: Opacity(
                              opacity: dragChromeOpacity,
                              child: EditNoteSheet(
                                key: ValueKey('edit-note-${note.id}'),
                                note: note,
                                repository: _repository!,
                                controller: _editController,
                                onSaved: _finishEditing,
                                onScheduleReminder: (initial) =>
                                    _openReminderSchedule(note, initial),
                              ),
                            ),
                          ),
                        )
                      else
                        // Sayfanın kalan yüksekliği panele veriliyor: kısa
                        // notta künye ekranın tabanına oturur, uzun notta
                        // panel büyür ve akış doğal biçimde kaydırılır.
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: IgnorePointer(
                            ignoring: _dismissProgress > .001,
                            child: Opacity(
                              opacity: dragChromeOpacity,
                              child: Padding(
                                // Künye sabit eylem şeridinin altında
                                // kalmaz; sayfanın gerçek tabanı bu.
                                padding: EdgeInsets.only(
                                  bottom: DetailActionBar.extentOf(context),
                                ),
                                child: _LiveDetailSheet(
                                  key: ValueKey('detail-note-${note.id}'),
                                  note: note,
                                  entrance: _entrance,
                                  onEdit: _beginEditing,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: _editing || _dismissProgress > .001,
                    child: AnimatedSlide(
                      offset: _editing ? const Offset(0, 1) : Offset.zero,
                      duration: AppMotion.medium,
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _editing ? 0 : dragChromeOpacity,
                        duration: AppMotion.fast,
                        child: DetailActionBar(
                          reveal: _chromeReveal,
                          onDelete: () => _delete(note),
                          onEdit: _beginEditing,
                          onShare: () => _shareNote(note),
                          sharing: _sharing,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_editing || _dismissProgress > .001,
                    child: AnimatedSlide(
                      offset: _editing ? Offset.zero : const Offset(0, 1),
                      duration: AppMotion.medium,
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _editing ? 1 : 0,
                        duration: AppMotion.fast,
                        child: EditNoteActionRail(
                          controller: _editController,
                          onCancel: _finishEditing,
                          onDismissRequested: _prepareThumbDismiss,
                          onDismissOffsetChanged: _setEditorDismissOffset,
                          onDismissProgressChanged: _setEditorDismissProgress,
                          onDismissed: () {
                            if (mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Künye dış katmanda duruyor, güvenli alanın *içinde* değil: içerik
          // altına girdiğinde beliren zemin status bar şeridini de kapsıyor.
          // Aksi hâlde yukarı kaydırırken ekranın tepesinde, geri düğmesinin
          // hemen üstünde biten kopuk bir kuşak kalıyordu.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: _editing || _dismissProgress > .001,
              child: AnimatedOpacity(
                opacity: _editing ? 0 : dragChromeOpacity,
                duration: AppMotion.fast,
                child: AnimatedContainer(
                  key: const ValueKey('detail-chrome'),
                  duration: _morphDuration,
                  curve: Curves.easeOutQuart,
                  height: media.padding.top + chromeExtent,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: media.padding.top + _chromeExtent,
                    maxHeight: media.padding.top + _chromeExtent,
                    child: _DetailChrome(
                      reveal: _chromeReveal,
                      scrollOffset: _scrollOffset,
                      topPadding: media.padding.top,
                      createdAt: note.createdAt,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Verilen kutuya sığan en büyük [aspect] oranlı dikdörtgen.
  static Size _fitPrint(double maxWidth, double maxHeight, double aspect) {
    var width = maxWidth;
    var height = width / aspect;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }
    return Size(width, height);
  }
}

/// Sistem izni veya zaman değiştiğinde yalnızca künyeyi yeniler.
/// Notun fotoğraf sahnesini baştan kurmak gereksiz olurdu.
class _LiveDetailSheet extends StatelessWidget {
  const _LiveDetailSheet({
    super.key,
    required this.note,
    required this.entrance,
    required this.onEdit,
  });

  final Note note;
  final Animation<double> entrance;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.preferences(context);
    final reminders = context.reminders;
    final active = AppScope.remindersActive(context);

    return ValueListenableBuilder<DateTime>(
      valueListenable: AppScope.reminderClockOf(context),
      builder: (context, now, _) => DetailSheet(
        note: note,
        entrance: entrance,
        onEdit: onEdit,
        reminderAt: active
            ? reminders.nextReminderAt(note, settings, now: now)
            : null,
        now: now,
      ),
    );
  }
}

/// Sayfanın ışığı — ve bu sayfanın imzası.
///
/// Zemin düz bir renk değil, baskının arkasından gelen zayıf bir aydınlanma.
/// Kaynağı da rastgele bir vurgu değil: **karenin kendi baskın rengi**. Yeşil
/// bir kare serin, turuncu bir fiş sıcak bir odada durur. Yüzde on civarında
/// bir fark; kimse "renkli arka plan" demez ama iki notu üst üste açan biri
/// sayfanın o kareye ait olduğunu hisseder.
///
/// Ton ilk karede henüz bilinmez; geldiğinde renk yavaşça yerine oturur, tıpkı
/// banyodan çıkan bir baskı gibi.
class _DetailBackdrop extends StatelessWidget {
  const _DetailBackdrop({required this.tone});

  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lift = _canvasLift(palette);

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tone ?? lift),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final glow = Color.lerp(
          lift,
          value ?? lift,
          palette.isDark ? 0.20 : 0.13,
        )!;
        // Odak baskının biraz *altında*: ışık kareden çıkıp sayfanın boş
        // alanına yayılıyormuş gibi okunsun. Merkez karenin arkasında kalsaydı
        // renk tam olarak fotoğrafın örttüğü yerde durur, hiç görünmezdi.
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.22),
              radius: 1.25,
              colors: [
                glow,
                Color.lerp(glow, palette.canvas, 0.55)!,
                palette.canvas,
              ],
              stops: const [0, 0.58, 1],
            ),
          ),
        );
      },
    );
  }
}

/// Zemin gradyanının tepe tonu.
///
/// Künyenin kendi zemini de buradan örneklenir; düz `canvas` rengiyle çizilen
/// bir şerit, gradyanın en aydınlık yerinde görünür bir dikiş bırakırdı.
Color _canvasLift(AppPalette palette) => Color.lerp(
  palette.canvas,
  palette.isDark ? Colors.white : Colors.black,
  0.035,
)!;

/// Status bar ile baskı arasındaki künye şeridi.
///
/// Tarih tam ekran ekseninde ortada durur; solundaki tek geri düğmesi onu
/// optik olarak itmez. Düğme, ana ekranın sağ üst köşesindeki denetimlerle
/// **aynı** yuvarlak kabı kullanır: kullanıcı iki ekranda iki ayrı düğme dili
/// öğrenmez.
///
/// Silme buradan alındı: aynı eylemi hem tepede hem alt şeritte tutmak,
/// kullanıcıya "bu ikisi farklı şeyler mi?" diye sordurur.
class _DetailChrome extends StatelessWidget {
  const _DetailChrome({
    required this.reveal,
    required this.scrollOffset,
    required this.topPadding,
    required this.createdAt,
    required this.onBack,
  });

  final Animation<double> reveal;
  final ValueListenable<double> scrollOffset;

  /// Güvenli alanın üst payı. Zemin bunu da kaplar, denetimler kaplamaz.
  final double topPadding;

  final DateTime createdAt;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      fit: StackFit.expand,
      children: [
        // İçerik şeridin altına girmeye başlayınca zemin belirir. Tepede
        // dururken künye fotoğrafın üstünde yüzen bir çubuk değil, sayfanın
        // kendi boşluğudur.
        IgnorePointer(
          child: ValueListenableBuilder<double>(
            valueListenable: scrollOffset,
            builder: (context, offset, _) {
              final settled = (offset / 22).clamp(0.0, 1.0);
              if (settled <= 0) return const SizedBox.shrink();
              final base = _canvasLift(palette);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      base.withValues(alpha: settled),
                      base.withValues(alpha: settled),
                      base.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.62, 1],
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 62),
            child: Center(
              child: FadeTransition(
                opacity: reveal,
                child: _FrameStamp(createdAt: createdAt),
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: FadeTransition(
            opacity: reveal,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: kDetailMargin),
                child: IconOrb(
                  key: const ValueKey('detail-action-back'),
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: context.l10n.actionBack,
                  onPressed: onBack,
                  size: kDetailOrbSize,
                  iconSize: 18,
                  tint: palette.ink,
                  fill: palette.glass,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Karenin çekildiği anın künyeye basılmış hâli.
///
/// Düz gri bir altyazı satırı değil. Makinelerin filmin kenarına bastığı veri
/// imprintinden alınmış bir dizgi: saat büyük ve net — bir kareyi hatırlarken
/// önce günün *anını* ararsın — tarih ise altında, harfleri açılmış küçük
/// kapitellerle. İkisini bir kor rengi tik ayırır; nokta değil, çizgi.
class _FrameStamp extends StatelessWidget {
  const _FrameStamp({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    return Column(
      key: const ValueKey('detail-note-date'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.time(createdAt, use24Hour: context.use24Hour),
          maxLines: 1,
          style: palette.label.copyWith(
            color: palette.ink,
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColophonTick(color: palette.ember),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.upper(l10n.calendarDate(createdAt)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: palette.overline.copyWith(
                  color: palette.inkFaint,
                  fontSize: 9.5,
                  height: 1,
                  letterSpacing: 1.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ColophonTick(color: palette.ember),
          ],
        ),
      ],
    );
  }
}

/// Sayfanın alt eylem şeridi: künyenin ikinci yarısı.
///
/// Bu sayfa bir baskı. Tepesinde künyesi var — saat, altında iki kısa kor
/// çizgi arasında geniş harf aralıklı tarih. Dibinde ise bugüne kadar cam bir
/// slab ve onun içinde ikon-üstte-ad-altta hücreler vardı; yani aynı sayfanın
/// üstü künye, altı sekme çubuğu konuşuyordu. Sekme çubuğu eşitler arasında
/// gezinmek için bir kalıp, oysa bunlar gezinme değil, baskıya yapılan üç
/// ayrı iş.
///
/// Şerit artık kutu değil: kap kalkınca ekrandan bir çerçeve eksiliyor ve
/// baskı büyüyor. Kelimeleri ayıran kor çizgiler künyedekinin aynısı, aynı
/// [ColophonTick]. Sayfanın iki ucu aynı noktalama işaretini kullanıyor.
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({
    super.key,
    required this.reveal,
    required this.onDelete,
    required this.onEdit,
    required this.onShare,
    this.sharing = false,
  });

  /// Şerit tek satır yazıya indi; künyeden alçak durabiliyor. Artan yer
  /// baskıya gidiyor.
  static const double _barHeight = 52;

  static const double _gap = 10;

  final Animation<double> reveal;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  /// Paylaşma beklerken adı nefes alır; şeritte dönen bir çark belirmez.
  final bool sharing;

  static double extentOf(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return _barHeight + _gap + (safeBottom < 14 ? 14 : safeBottom);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final base = palette.canvas;

    return SizedBox(
      key: const ValueKey('detail-action-bar'),
      height: extentOf(context) + 18,
      child: DecoratedBox(
        // Şerit opak bir çubuk değil; blok yanlarında içerik görünmeye devam
        // ettiği için tuval rengi aşağıdan yukarı yumuşakça yükselir.
        // Bulanıklık hesaplanmaz.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [base, base, base.withValues(alpha: 0)],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: FadeTransition(
          opacity: reveal,
          // Sayfanın geri kalanı gibi şerit de belirmiyor, yerine oturuyor.
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(reveal),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  kDetailMargin,
                  0,
                  kDetailMargin,
                  MediaQuery.paddingOf(context).bottom < 14
                      ? 14
                      : MediaQuery.paddingOf(context).bottom,
                ),
                child: ColophonBar(
                  height: _barHeight,
                  actions: [
                    ColophonAction(
                      key: const ValueKey('detail-action-delete'),
                      label: l10n.actionDelete,
                      semanticLabel: l10n.actionDelete,
                      pressColor: palette.danger,
                      onPressed: onDelete,
                    ),
                    ColophonAction(
                      key: const ValueKey('detail-action-edit'),
                      label: l10n.actionEdit,
                      semanticLabel: l10n.editNoteSemantic,
                      onPressed: onEdit,
                    ),
                    ColophonAction(
                      key: const ValueKey('detail-action-share'),
                      label: l10n.actionShare,
                      semanticLabel: l10n.shareNoteSemantic,
                      busy: sharing,
                      onPressed: onShare,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
