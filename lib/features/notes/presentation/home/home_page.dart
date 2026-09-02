import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_link.dart';
import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/shutter_confirm.dart';
import '../../../home_widget/home_widget_link.dart';
import '../../../reminders/reminder_service.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../data/notes_database.dart';
import '../../data/notes_repository.dart';
import '../../domain/note_kind.dart';
import '../../domain/note_reminder.dart';
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
  StreamSubscription<HomeWidgetAction>? _widgetLinkSubscription;
  StreamSubscription<AppLink>? _appLinkSubscription;
  ReminderService? _reminders;
  StreamSubscription<int>? _reminderLinkSubscription;
  bool _pickingFromGallery = false;
  bool _drainingSharedImports = false;
  int? _activeLinkedNoteId;
  int? _queuedLinkedNoteId;
  bool _openingWidgetCamera = false;
  bool _widgetCameraQueued = false;

  /// Arama durumu burada yaşıyor: üstlük bir sliver delegesi ve kaydırmanın
  /// her karesinde yeniden kuruluyor, denetim durumunu orada tutamayız.
  bool _searching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Yürürlükteki aramanın sonucu — metin değil, eşleşen kimlikler.
  SearchHits _hits = SearchHits.none;
  Timer? _searchDebounce;

  /// Toplu silme kipi.
  ///
  /// İşaretli kayıtlar kimlikleriyle tutuluyor, `Note` nesneleriyle değil:
  /// akış seçim açıkken yeni bir değer yayabilir (kayıt süresi dolar, bildirim
  /// düğmesinden bir not silinir) ve elde tutulan kopya o anda eskir. Kimlik
  /// listede aranır, bulunmayan sessizce düşer.
  bool _selecting = false;
  final _selected = <int>{};

  /// Silme sürerken şerit kilitli kalır; ikinci dokunuş aynı kayıtları bir
  /// daha silmeye kalkmaz.
  bool _deletingSelection = false;

  /// Yaş bölümlerinin dayandığı yerel gün. Akış açıkken gece yarısı geçilse
  /// bile "Bugün / Dün" başlıkları bir sonraki veri değişimini beklememeli.
  late DateTime _calendarReference;
  Timer? _calendarRollover;

  /// Sorgu artık veritabanına gidiyor, yani cevap bir sonraki karede değil bir
  /// süre sonra geliyor. Bu sayaç hangi cevabın güncel olduğunu söylüyor:
  /// hızlı yazan bir kullanıcıda istekler sırayla bitmeyebilir ve geciken eski
  /// bir cevap yeni sonucun üstüne yazarsa liste yanlış kalırdı.
  int _searchTicket = 0;

  @override
  void initState() {
    super.initState();
    _calendarReference = DateTime.now();
    _scheduleCalendarRollover();
    WidgetsBinding.instance.addObserver(this);
    _widgetLink = HomeWidgetLink();
    _widgetLinkSubscription = _widgetLink.actions.listen(_queueWidgetAction);
    unawaited(_widgetLink.start());
    _sharedImportSubscription = SharedImportBridge.onImportAvailable.listen((
      _,
    ) {
      _drainSharedImports();
    });
    _appLinkSubscription = AppLinkBridge.links.listen(_queueAppLink);
    unawaited(_drainPendingAppLink());
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
    _calendarRollover?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _sharedImportSubscription?.cancel();
    _widgetLinkSubscription?.cancel();
    _appLinkSubscription?.cancel();
    _reminderLinkSubscription?.cancel();
    unawaited(_widgetLink.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _drainSharedImports();
    unawaited(_drainPendingAppLink());
    _drainExternalRoutes();
    setState(() => _calendarReference = DateTime.now());
    _scheduleCalendarRollover();
  }

  void _scheduleCalendarRollover() {
    _calendarRollover?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _calendarRollover = Timer(
      nextDay.difference(now) + const Duration(milliseconds: 50),
      () {
        if (!mounted) return;
        setState(() => _calendarReference = DateTime.now());
        _scheduleCalendarRollover();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context);
    if (repository != _repository) {
      _repository = repository;
      _notes = repository.watchNotes();
    }

    final reminders = context.reminders;
    if (reminders != _reminders) {
      unawaited(_reminderLinkSubscription?.cancel());
      _reminders = reminders;
      _reminderLinkSubscription = reminders.listenNoteTaps(_queueLinkedNote);
      unawaited(_initializeReminderLinks(reminders));
    }
  }

  Future<void> _initializeReminderLinks(ReminderService reminders) async {
    try {
      await reminders.initialize();
    } catch (error) {
      debugPrint('Bildirim bağlantısı başlatılamadı: $error');
    }
  }

  /// Yeni kayıt kapısı.
  ///
  /// Kontrol **çekimden önce** yapılıyor. Fotoğrafı çektirip notu yazdırdıktan
  /// sonra "limit doldu" demek, kullanıcının emeğini çöpe atmak olurdu.
  Future<bool> _allowNewNote({bool? isProOverride}) async {
    // Cold-start widget açılışında InheritedWidget henüz Drift'in ilk
    // karesini almamış olabilir. Limiti kalıcı ayardan okumak, Pro kullanıcıyı
    // varsayılan `false` yüzünden yanlış paywall'a göndermeyi önler.
    final settingsRepository = AppScope.settingsOf(context);
    final notesRepository = AppScope.of(context);
    final settings = await settingsRepository.read();
    final notes = await notesRepository.watchNotes().first;
    if (!mounted) return false;

    if (!ProLimits.blocksNewNote(
      notes.length,
      isPro: isProOverride ?? settings.proUnlocked,
    )) {
      return true;
    }

    await showPaywall(context, reason: PaywallReason.noteLimit);
    return false;
  }

  Future<void> _openCamera({
    bool? isProOverride,
    VoidCallback? onFlowClosed,
  }) async {
    if (!await _allowNewNote(isProOverride: isProOverride) || !mounted) {
      onFlowClosed?.call();
      return;
    }
    await Navigator.of(
      context,
    ).push(AppRoutes.shutter(CapturePage(onFlowClosed: onFlowClosed)));
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

  /// Karesiz kayıt: composer kare olmadan açılır, gerisi aynı ekran.
  void _composeText() {
    Navigator.of(
      context,
    ).push(AppRoutes.lift(const ComposePage(source: ComposeSource.text)));
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
    final reviewPrompts = context.reviewPrompts;
    final settingsRepository = AppScope.settingsOf(context);
    final reminders = context.reminders;
    _drainingSharedImports = true;

    try {
      while (mounted) {
        final shared = await SharedImportBridge.takePending();
        if (shared == null || !mounted) break;

        // Karesiz teslim yalnız Siri/Kestirmeler'den geliyor ve kendi
        // kuralları var: mutlak hatırlatma anı, açılacak Compose ekranı yok.
        final image = shared.image;
        if (image == null) {
          if (!await _saveQueuedNote(shared)) break;
          continue;
        }

        if (shared.saveImmediately) {
          try {
            final processed = await _repository!.hasProcessedImport(shared.id);
            if (!processed && !await _allowNewNote()) break;
            var settings = await settingsRepository.read();
            if (shared.remindAfterDays > 0 && !settings.proUnlocked) {
              if (!mounted) break;
              await showPaywall(context, reason: PaywallReason.reminder);
              settings = await settingsRepository.read();
              // Extension son bilinen hakkı görür; mağaza bu arada hakkı
              // düşürdüyse seçimi sessizce yok saymak yerine payload bekler.
              if (!settings.proUnlocked) break;
            }
            if (shared.remindAfterDays > 0) {
              await settingsRepository.setReminderEnabled(true);
              var allowed = await reminders.hasPermission();
              if (!allowed) allowed = await reminders.requestPermission();
              // İzin reddedilse de DB'deki seçim korunur. Global tercih açık
              // kaldığı için kullanıcı Ayarlar'dan izin verdiği anda sonraki
              // sync bildirimi kurar.
            }
            await _repository!.create(
              capture: image,
              body: shared.initialText,
              retention: RetentionChoice(
                settings.defaultRetention,
                customMinutes: settings.defaultCustomMinutes,
              ),
              createdAt: shared.createdAt,
              // Extension "kaç gün sonra" gönderiyor; kayıt mutlak an tutuyor.
              // Çevrim burada, sınırda yapılıyor: içeride tek bir dil kalsın.
              reminder: shared.remindAfterDays > 0
                  ? ReminderChoice(
                      at: shiftLocalCalendarDays(
                        DateTime.now(),
                        shared.remindAfterDays,
                      ),
                    )
                  : const ReminderChoice.off(),
              importId: shared.id,
            );
            if (reviewPrompts != null) {
              unawaited(reviewPrompts.recordSuccessfulSave());
            }
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

        if (!await _allowNewNote() || !mounted) break;

        await Navigator.of(context).push(
          AppRoutes.lift(
            ComposePage(
              capture: image,
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
      _drainExternalRoutes();
    }
  }

  /// Siri veya bir kısayolun bıraktığı karesiz teslimi kaydeder.
  ///
  /// Hatırlatmanın **alarmı** zaten kurulu: uzantı, kullanıcı konuşurken
  /// bildirimi kendisi planladı — yoksa uygulama hiç açılmazsa hatırlatma hiç
  /// çalmazdı. Burada yapılan iş kaydı gerçekten oluşturup alarmı geçici
  /// istekten `ReminderService`'in programına devretmek.
  ///
  /// Dönen değer kuyruğa devam edilip edilmeyeceği: `false`, sıradaki
  /// teslimin de aynı engele takılacağı anlamına gelir (paywall, izin, hata).
  Future<bool> _saveQueuedNote(SharedImport shared) async {
    final reviewPrompts = context.reviewPrompts;
    final settingsRepository = AppScope.settingsOf(context);
    final reminders = context.reminders;

    try {
      final processed = await _repository!.hasProcessedImport(shared.id);
      if (!processed && !await _allowNewNote()) return false;

      var settings = await settingsRepository.read();
      var remindAt = shared.remindAt;

      if (remindAt != null && !settings.proUnlocked) {
        if (!mounted) return false;
        // Uzantı son bilinen hakkı görüyor; mağaza bu arada hakkı düşürdüyse
        // seçimi sessizce yok saymak yerine payload bekler.
        await showPaywall(context, reason: PaywallReason.reminder);
        settings = await settingsRepository.read();
        if (!settings.proUnlocked) return false;
      }

      if (remindAt != null) {
        await settingsRepository.setReminderEnabled(true);
        var allowed = await reminders.hasPermission();
        if (!allowed) allowed = await reminders.requestPermission();
        // İzin reddedilse de DB'deki seçim korunur; kullanıcı Ayarlar'dan
        // izin verdiği anda sonraki sync bildirimi kurar.
      }

      final retention = RetentionChoice(
        settings.defaultRetention,
        customMinutes: settings.defaultCustomMinutes,
      );

      // Ayna bayat olabilir: kullanıcı konuştuktan sonra saklama süresini
      // kısaltmış olabilir. O hâlde `createText` kaydı **hiç** oluşturmaz.
      // Notu tümden kaybetmektense hatırlatmayı düşürmek daha az zarar veriyor
      // — ama sessizce değil, kullanıcı ne olduğunu görüyor.
      final expiry = retention.expiryFrom(shared.createdAt);
      final droppedReminder =
          remindAt != null && expiry != null && !remindAt.isBefore(expiry);
      if (droppedReminder) remindAt = null;

      await _repository!.createText(
        body: shared.initialText,
        retention: retention,
        createdAt: shared.createdAt,
        reminder: remindAt == null
            ? const ReminderChoice.off()
            : ReminderChoice(at: remindAt),
        importId: shared.id,
      );

      if (reviewPrompts != null) {
        unawaited(reviewPrompts.recordSuccessfulSave());
      }
      await SharedImportBridge.complete(shared.id);
      // Kayıt oluştuktan **sonra**: arada bir hata olsaydı kullanıcı hem
      // kaydı hem alarmı kaybederdi.
      await SharedImportBridge.cancelQueuedReminder(shared.id);
      if (mounted) {
        showToast(
          context,
          droppedReminder
              ? context.l10n.toastQueuedNoteReminderDropped
              : context.l10n.toastQueuedNoteAdded,
          error: droppedReminder,
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        showToast(context, context.l10n.toastQueuedNoteFailed, error: true);
      }
      return false;
    }
  }

  /// Soğuk açılışta Spotlight sonucu Flutter motorundan **önce** gelir.
  /// Native taraf onu bekletiyor; ilk kare çizilirken ve her öne gelişte
  /// kuyruktan alınıyor.
  Future<void> _drainPendingAppLink() async {
    final link = await AppLinkBridge.takePending();
    if (link != null) _queueAppLink(link);
  }

  void _queueAppLink(AppLink link) {
    switch (link) {
      case OpenNoteLink(:final noteId):
        _queueLinkedNote(noteId);
    }
  }

  void _queueWidgetAction(HomeWidgetAction action) {
    switch (action) {
      case OpenWidgetNote(:final noteId):
        _queueLinkedNote(noteId);
        return;
      case OpenWidgetCapture():
        _queueWidgetCamera();
        return;
    }
  }

  /// Widget, bildirim ve hızlı çekim dokunuşlarını aynı tekli route kuyruğunda
  /// birleştirir. Kilit açılırken gelen URL uygulama `resumed` olmadan route
  /// üretmez; kamera donanımı ancak gerçekten öndeyken başlatılır.
  void _queueLinkedNote(int noteId) {
    if (!mounted) return;
    if (_activeLinkedNoteId == noteId) return;
    _queuedLinkedNoteId = noteId;
    _drainExternalRoutes();
  }

  void _queueWidgetCamera() {
    if (!mounted || _openingWidgetCamera || _widgetCameraQueued) return;
    _widgetCameraQueued = true;
    _drainExternalRoutes();
  }

  void _drainExternalRoutes() {
    if (!mounted ||
        _drainingSharedImports ||
        _openingWidgetCamera ||
        _activeLinkedNoteId != null ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    // Kamera dokunuşu zaman hassastır; sırada hem bildirim hem de deklanşör
    // varsa önce kullanıcının az önce istediği çekim açılır.
    if (_widgetCameraQueued) {
      _widgetCameraQueued = false;
      _openingWidgetCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openWidgetCamera());
      });
      return;
    }

    final noteId = _queuedLinkedNoteId;
    if (noteId == null) return;
    _queuedLinkedNoteId = null;
    // İlk frame gelmeden ikinci bir native olay ulaşırsa da iki detay sayfası
    // planlanmasın; "active" hem planlanmış hem açık rotayı temsil eder.
    _activeLinkedNoteId = noteId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openLinkedNote(noteId);
    });
  }

  Future<void> _openWidgetCamera() async {
    if (!mounted || !_openingWidgetCamera) return;

    try {
      // Native timeline eski kalabilir ve özel URL elle de çağrılabilir.
      // Widget hakkını uygulama tarafında yeniden doğrulamak downgrade sonrası
      // kestirmenin kamerayı açmasını engeller.
      final purchases = context.purchases;
      final settingsRepository = AppScope.settingsOf(context);
      final verified = await purchases.checkEntitlement();
      final settings = await settingsRepository.read();
      if (!mounted) return;
      // Kesin mağaza sonucu varsa cache'in önüne geçer. Ağ/StoreKit o anda
      // cevap veremiyorsa son doğrulanmış yerel hak çevrimdışı çalışmayı sürdürür.
      final isPro = verified ?? settings.proUnlocked;
      if (!isPro) {
        await showPaywall(context, reason: PaywallReason.widget);
        return;
      }

      // CapturePage, ComposePage'e `pushReplacement` ile geçtiği için yalnız
      // route future'ını beklemek akışı erken bitirirdi. Callback, fotoğraf
      // kaydedilene/atılana kadar dış route kuyruğunu gerçekten kilitli tutar.
      final flowClosed = Completer<void>();
      await _openCamera(
        isProOverride: isPro,
        onFlowClosed: () {
          if (!flowClosed.isCompleted) flowClosed.complete();
        },
      );
      await flowClosed.future;
    } finally {
      _openingWidgetCamera = false;
      if (mounted) _drainExternalRoutes();
    }
  }

  Future<void> _openLinkedNote(int noteId) async {
    if (!mounted || _activeLinkedNoteId != noteId) return;
    await Navigator.of(
      context,
    ).push(AppRoutes.photoDetail(NoteDetailPage(noteId: noteId)));
    _activeLinkedNoteId = null;
    _drainExternalRoutes();
  }

  void _openNote(Note note) {
    Navigator.of(
      context,
    ).push(AppRoutes.photoDetail(NoteDetailPage(noteId: note.id)));
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

  /// Toplu silme kipine girer ya da çıkar.
  ///
  /// Arama ile seçim aynı anda açık olamaz: ikisi de başlığın aynı satırını
  /// kullanıyor ve iki kip birden açıkken üstlük ne yaptığını söyleyemez.
  /// Seçim başlarken arama kapanır.
  ///
  /// Kipi açan denetim aynı zamanda kapatan denetim: alt şeritte, galerinin
  /// karşısındaki yuvada.
  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _selected.clear();
      if (_selecting && _searching) {
        _searching = false;
        _searchDebounce?.cancel();
        _searchTicket++;
        _hits = SearchHits.none;
        _searchController.clear();
        _searchFocus.unfocus();
      }
    });
  }

  /// Akış boşaldığı için görünürden düşen kipi durumdan da siler.
  void _dropStaleSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_selecting) return;
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    });
  }

  void _toggleSelection(Note note) {
    setState(() {
      if (!_selected.remove(note.id)) _selected.add(note.id);
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
      photo: note.hasPhoto ? _repository!.imageOf(note) : null,
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

  /// İşaretli kayıtları topluca siler.
  ///
  /// Onay tekli silmeyle **aynı** ritüel: örtücü kapanana kadar parmak basılı
  /// tutulur. Yıkıcılığı sayıyla artan bir eylem için ayrı, daha kolay bir
  /// kapı açmak tuhaf olurdu. Örtücünün altına seçilenlerin ilki konur;
  /// başlık kaç karenin gittiğini söyler.
  Future<void> _deleteSelection(List<Note> targets) async {
    if (targets.isEmpty || _deletingSelection) return;

    final confirmed = await showShutterConfirm(
      context,
      // Örtücünün altına seçilenlerin **karesi olan** ilki konur; hepsi
      // karesizse diyafram koyu alanın üstünde kapanır.
      photo: targets
          .where((note) => note.hasPhoto)
          .map((note) => _repository!.imageOf(note))
          .firstOrNull,
      title: context.l10n.deleteManyConfirmTitle(targets.length),
      caption: context.l10n.deleteManyConfirmCaption,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingSelection = true);
    var deleted = false;
    try {
      await _repository!.deleteAll(targets);
      deleted = true;
    } catch (_) {
      if (mounted) {
        showToast(context, context.l10n.toastDeleteFailed, error: true);
      }
    }
    if (!mounted) return;

    setState(() {
      _deletingSelection = false;
      // Silme başarısızsa seçim durur: kullanıcı yeniden deneyebilsin.
      if (deleted) {
        _selecting = false;
        _selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preferences = AppScope.preferences(context);
    final density = preferences.density;

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
          final filtering = _searching && _hits.filtering;
          final notes = filtering
              ? all.where((note) => _hits.contains(note.id)).toList()
              : all;

          // Kip listeden türetiliyor: son kayıt silindiğinde akış boş kalır,
          // seçim şeridi de o karede kendiliğinden kalkar. İşaretliler de
          // listenin kendisinden süzülüyor; arada süresi dolan bir kayıt
          // sayacı şişirmez.
          final selecting = _selecting && all.isNotEmpty;
          // Son kayıt seçim açıkken başka bir yerden kalkabilir (süresi dolar,
          // bildirim düğmesinden silinir). Kip yalnız görsel olarak kapanırsa
          // bir sonraki fotoğrafta kendiliğinden geri gelirdi; bayrak da
          // düşürülüyor.
          if (_selecting && !selecting) _dropStaleSelection();
          final selection = selecting
              ? [
                  for (final note in notes)
                    if (_selected.contains(note.id)) note,
                ]
              : const <Note>[];

          return _Canvas(
            child: Stack(
              children: [
                if (all.isNotEmpty)
                  DensityCrossfade(
                    density: density,
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: AppScope.reminderClockOf(context),
                      builder: (context, reminderReference, _) {
                        final reminders = context.reminders;
                        return NotesFeed(
                          notes: notes,
                          calendarReference: _calendarReference,
                          reminderReference: reminderReference,
                          repository: _repository!,
                          reminders: reminders,
                          settings: preferences,
                          density: density,
                          remindersActive: AppScope.remindersActive(context),
                          onOpen: _openNote,
                          onDelete: _confirmDelete,
                          onOpenSettings: _openSettings,
                          // Deklanşörün perdesi güvenli alanı da kaplıyor;
                          // akış yalnızca `dockHeight` ayırırsa son kaydın
                          // notu perdenin altında sönük kalıyor.
                          bottomInset:
                              ShutterDock.dockHeight +
                              MediaQuery.paddingOf(context).bottom,
                          searching: _searching,
                          filtering: filtering,
                          searchController: _searchController,
                          searchFocus: _searchFocus,
                          onSearchChanged: _onQueryChanged,
                          onToggleSearch: _toggleSearch,
                          selecting: selecting,
                          selectedIds: _selected,
                          onToggleSelection: _toggleSelection,
                        );
                      },
                    ),
                  ),
                // Şerit **arşive** bakar, ekrandaki süzülmüş listeye değil.
                // Aramada eşleşme çıkmadığında `notes` boşalıyor ve şerit
                // "ilk kareni çek" davetine dönüyordu: dev deklanşör başlığın
                // üstüne biniyor, hâlâ dolu bir arşivi olan kullanıcıya boş
                // ekran gösteriliyordu. Ücretsiz katman sayacı da aynı yerden
                // yanlış besleniyordu — sınır tüm arşivle ilgili, o anda
                // eşleşen kaç kare olduğuyla değil.
                ShutterDock(
                  docked: all.isNotEmpty,
                  importing: _pickingFromGallery,
                  noteCount: all.length,
                  isPro: preferences.proUnlocked,
                  onCapture: _openCamera,
                  onImport: _pickFromGallery,
                  onComposeText: _composeText,
                  onOpenSettings: all.isEmpty ? _openSettings : null,
                  selecting: selecting,
                  selectedCount: selection.length,
                  // Akış boşken silinecek bir şey yok: yuva hiç çizilmiyor.
                  onToggleSelecting: all.isEmpty ? null : _toggleSelecting,
                  onDeleteSelection: _deletingSelection
                      ? null
                      : () => _deleteSelection(selection),
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
