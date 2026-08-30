import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../capture/capture_page.dart';
import '../import/gallery_import.dart';
import '../import/shared_import.dart';
import '../reminder/reminder_schedule_page.dart';
import 'widgets/capture_preview.dart';
import 'widgets/note_composer.dart';
import '../../../../shared/widgets/colophon_bar.dart';
import '../widgets/location_control.dart';
import '../widgets/reminder_control.dart';
import '../../data/location_service.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../core/utils/app_format.dart';
import '../../domain/note_reminder.dart';
import '../../domain/retention.dart';

/// Çekilen kareye not düşme ekranı.
enum ComposeSource { camera, gallery, shared }

/// Kaydetmenin hâli.
///
/// `sealed` tek karelik bir eşik: kalıcı kopya yazıldıktan sonra rota
/// kapanana kadar geçen an. Ayrı bir görüntüsü yok, yalnızca kaydetme
/// eyleminin yeniden tetiklenmesini engelliyor.
/// Kaydetmenin evreleri.
///
/// [locating] ayrı bir evre çünkü kullanıcının gördüğü şey farklı: kayıt değil,
/// bir sabitleme bekleniyor. Aynı sessiz bekleyişi "kaydediliyor" diye
/// göstermek, dört saniye boyunca uygulamanın takıldığını düşündürüyordu.
enum ComposeSavePhase { idle, locating, saving, sealed }

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.capture,
    this.source = ComposeSource.camera,
    this.initialText = '',
    this.capturedAt,
    this.sharedImportId,
    this.onFlowClosed,
  });

  /// Düzenlenecek kare. Kamera ve paylaşım kaynakları Latermark'ın yönettiği
  /// geçici kopyalardır; galeri kaynağının sahipliği sistemde kalır.
  final XFile capture;
  final ComposeSource source;
  final String initialText;
  final DateTime? capturedAt;
  final String? sharedImportId;

  /// CapturePage'den başlayan dış yönlendirme zincirinin son halkası.
  final VoidCallback? onFlowClosed;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  /// Yazı alanının rahatça durabilmesi için ayrılan en küçük yükseklik.
  /// Fotoğrafın boyu bu değerden artan yere göre hesaplanır.
  static const _composerReserve = 336.0;

  late final TextEditingController _text;

  /// Kaydın zamanı, çekimin yapıldığı andır — kaydete basıldığı an değil.
  late final DateTime _capturedAt;

  /// Hatırlatma isteniyor mu. Gün ve saat burada sorulmuyor: kaydetmenin
  /// ardından açılan planlama ekranının işi.
  bool _remindMe = false;

  /// Konum anahtarı. Varsayılanı ayarlardaki son tercih besler; yalnızca
  /// kamerayla çekilen karede anlamlı.
  bool _locationEnabled = false;
  bool _locationDefaultRead = false;

  /// Çözülmüş koordinat. Sabitleme henüz gelmemişse kaydetme kısa bir süre
  /// bekler — bkz. [_locationSettleLimit].
  NoteLocation? _location;
  final LocationController _locationController = LocationController();

  /// Kaydete basıldığında bekleyen bir sabitleme için ayrılan en uzun süre.
  ///
  /// Eskiden hiç beklenmiyordu: konum ekle deyip hemen kaydeden biri, henüz
  /// sabitlenmediği için notunu konumsuz alıyor ve haklı olarak "ben konum
  /// istemiştim" diyordu. Süresiz beklemek de yanlış olurdu; bu pay, tipik bir
  /// sabitlemeye yetecek ama kimseyi ekranda tutmayacak kadar.
  static const _locationSettleLimit = Duration(seconds: 4);

  ComposeSavePhase _savePhase = ComposeSavePhase.idle;

  bool _tempCleared = false;
  bool _flowHandedOff = false;
  bool _flowClosed = false;

  bool get _saving => _savePhase != ComposeSavePhase.idle;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _capturedAt = widget.capturedAt ?? DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationDefaultRead || !_wantsLocation) return;
    _locationDefaultRead = true;
    _locationEnabled = AppScope.preferences(context).locationEnabled;
  }

  /// Konum satırı yalnızca kamerada. Galeriden ya da paylaşımdan gelen bir
  /// kare başka zaman, başka yerde çekilmiş olabilir; ona cihazın *şu anki*
  /// konumunu yazmak kaydı sessizce yalancı yapardı.
  bool get _wantsLocation => widget.source == ComposeSource.camera;

  @override
  void dispose() {
    _text.dispose();
    if (!_flowHandedOff) _closeFlow();
    super.dispose();
  }

  void _closeFlow() {
    if (_flowClosed) return;
    _flowClosed = true;
    widget.onFlowClosed?.call();
  }

  /// Kameranın geçici dosyasını siler. Kaydetme sırasında kare zaten kalıcı
  /// klasöre kopyalandığı için her iki yolda da güvenle çağrılabilir.
  Future<void> _clearTemp() async {
    if (_tempCleared) return;
    _tempCleared = true;

    // Sistem galeri seçicisinin verdiği yol uygulamanın yönettiği bir
    // önbellek kopyasıdır; yine de sahipliği platforma bırakırız. Böylece
    // hiçbir platform farkında kullanıcının orijinal varlığına dokunmayız.
    if (widget.source == ComposeSource.gallery) return;
    if (widget.source == ComposeSource.shared) {
      final id = widget.sharedImportId;
      if (id != null) await SharedImportBridge.complete(id);
      return;
    }

    final file = File(widget.capture.path);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } on FileSystemException {
      // Geçici klasörü işletim sistemi zaten temizleyecek.
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    // Kayıt anının kararlarını ilk await'ten önce dondur. Konum çözümlemesi
    // ya da başka bir kontrol sonradan sonuçlansa bile yarı eski/yarı yeni bir
    // not yazılmaz.
    final body = _text.text;
    final remindMe = _remindMe;
    final wantsLocation = _wantsLocation && _locationEnabled;
    setState(() => _savePhase = ComposeSavePhase.saving);

    final repository = AppScope.of(context);
    final reviewPrompts = context.reviewPrompts;
    final navigator = Navigator.of(context);
    final int noteId;

    try {
      // Saklama süresi artık her çekimde sorulmuyor; Ayarlar'daki varsayılanla
      // açılıyor ve gerekirse kaydın kendi ekranından değiştiriliyor.
      final settings = await AppScope.settingsOf(context).read();

      // Bekleyen sabitleme varsa kısa bir pay tanınır, gelmezse konumsuz devam
      // edilir. Pay boyunca şeridin kelimesi ne beklendiğini söylüyor: dört
      // saniye sessiz duran bir düğme, tökezlemiş bir uygulamadan ayırt
      // edilemiyordu.
      NoteLocation? location;
      if (wantsLocation) {
        location = _location;
        if (location == null) {
          setState(() => _savePhase = ComposeSavePhase.locating);
          location = await _locationController.settle(
            limit: _locationSettleLimit,
          );
          if (!mounted) return;
          setState(() => _savePhase = ComposeSavePhase.saving);
        }
      }
      if (!mounted) return;

      noteId = await repository.create(
        capture: widget.capture,
        body: body,
        retention: RetentionChoice(
          settings.defaultRetention,
          customMinutes: settings.defaultCustomMinutes,
        ),
        // Hatırlatma anı bu ekranda hiç sorulmadı; kayıt önce yazılıyor,
        // planlama ekranı onu bir sonraki karede kendisi yazıyor.
        reminder: const ReminderChoice.off(),
        createdAt: _capturedAt,
        location: location,
        importId: widget.sharedImportId,
      );
      if (reviewPrompts != null) {
        unawaited(reviewPrompts.recordSuccessfulSave());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _savePhase = ComposeSavePhase.idle);
      showToast(context, context.l10n.toastSaveFailed, error: true);
      return;
    }

    await _clearTemp();
    if (!mounted) return;
    // Route geri çekilirken diyaframın son mekanik durağı görünür kalsın.
    // Bir kare beklemek yapay bir gecikme değildir; setState'in çizilmesini
    // garanti eder, ardından mevcut sayfa geçişi hemen başlar.
    setState(() => _savePhase = ComposeSavePhase.sealed);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (!remindMe) {
      navigator.pop();
      return;
    }

    // Kare diskte; sıra "ne zaman dönsün" sorusunda. Yazma ekranı yığında
    // kalmıyor: geri hareketi kullanıcıyı kaydettiği forma değil, akışa geri
    // götürmeli. Zinciri kapatma görevi de yeni sayfaya devrediliyor.
    _flowHandedOff = true;
    navigator.pushReplacement(
      AppRoutes.lift(
        ReminderSchedulePage(noteId: noteId, onFlowClosed: widget.onFlowClosed),
      ),
    );
  }

  Future<void> _discard() async {
    if (_saving) return;
    await _clearTemp();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _retake() async {
    if (_saving) return;
    if (widget.source != ComposeSource.camera) {
      await _reselectFromGallery();
      return;
    }

    await _clearTemp();
    if (!mounted) return;
    _flowHandedOff = true;
    Navigator.of(context).pushReplacement(
      AppRoutes.shutter(CapturePage(onFlowClosed: widget.onFlowClosed)),
    );
  }

  Future<void> _reselectFromGallery() async {
    if (_saving) return;
    try {
      // Kullanıcı seçiciyi kapatırsa mevcut fotoğraf yerinde kalır.
      final replacement = await GalleryImport.pick();
      if (replacement == null || !mounted) return;

      await _clearTemp();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppRoutes.lift(
          ComposePage(capture: replacement, source: ComposeSource.gallery),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showToast(context, context.l10n.toastPhotoPickFailed, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomSafe = keyboard > 0 ? keyboard : media.padding.bottom;

    // Fotoğraf, yazı alanından artan yeri alır. Klavye yükseldikçe bu pay
    // kendiliğinden küçülür; ayrı bir animasyona gerek kalmaz çünkü klavye
    // ekleme miktarı kare kare güncellenir.
    final photoHeight = (media.size.height - _composerReserve - bottomSafe)
        .clamp(150.0, media.size.height * 0.46)
        .toDouble();

    return Scaffold(
      backgroundColor: context.palette.canvas,
      // Klavye boşluğunu elle yönetiyoruz; otomatik küçültme fotoğrafı da
      // sıkıştırıp düzeni bozardı.
      resizeToAvoidBottomInset: false,
      body: PopScope(
        // Kaydetme sürerken geri gitmek kareyi yarı yolda bırakırdı: geçici
        // dosya silinirken kalıcı kopya henüz tamamlanmamış olabilir. Düğme
        // zaten kilitli; sistem geri hareketi de aynı kilide uymalı.
        canPop: !_saving,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _clearTemp();
        },
        child: IgnorePointer(
          // Kalıcı kopya yazılırken fotoğrafı silme/değiştirme ya da üstüne
          // başka bir rota açma yarışlarını tek bir etkileşim sınırı kapatır.
          // Alt rayın animasyonu bu katmanın altında çalışmaya devam eder.
          ignoring: _saving,
          child: Column(
            children: [
              CapturePreview(
                file: File(widget.capture.path),
                height: photoHeight,
                onDiscard: _discard,
                onRetake: _retake,
                replacementIcon: widget.source != ComposeSource.camera
                    ? Icons.photo_library_outlined
                    : Icons.refresh_rounded,
                replacementLabel: widget.source != ComposeSource.camera
                    ? context.l10n.composeAnotherPhoto
                    : context.l10n.composeRetake,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 22, 22, bottomSafe + 18),
                  child: NoteComposer(
                    controller: _text,
                    autofocus: true,
                    extra: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReminderControl(
                          value: _remindMe,
                          onChanged: (value) =>
                              setState(() => _remindMe = value),
                        ),
                        if (_wantsLocation) ...[
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              32,
                              18,
                              0,
                              18,
                            ),
                            child: ColoredBox(
                              color: context.palette.hairline,
                              child: const SizedBox(height: 0.6),
                            ),
                          ),
                          LocationControl(
                            enabled: _locationEnabled,
                            onChanged: (value) {
                              setState(() => _locationEnabled = value);
                              unawaited(
                                AppScope.settingsOf(
                                  context,
                                ).setLocationEnabled(value),
                              );
                            },
                            onResolved: (value) {
                              if (mounted) setState(() => _location = value);
                            },
                            controller: _locationController,
                          ),
                        ],
                      ],
                    ),
                    header: ComposerStamp(
                      at: context.l10n.stamp(
                        _capturedAt,
                        use24Hour: context.use24Hour,
                      ),
                      trailing: switch (widget.source) {
                        ComposeSource.gallery => _SourceMark(
                          icon: Icons.photo_library_outlined,
                          label: context.l10n.sourceGallery,
                        ),
                        ComposeSource.shared => _SourceMark(
                          icon: Icons.ios_share_rounded,
                          label: context.l10n.sourceShared,
                        ),
                        ComposeSource.camera => null,
                      },
                    ),
                    // Alt eylem, not detayıyla aynı künye dilinde: kutu yok,
                    // güverte çizgisi ve altında geniş harf aralıklı ad.
                    // Buradaki kapsül 88pt yer kaplıyordu; o payın çoğu artık
                    // yazı alanının.
                    action: ColophonBar(
                      key: const ValueKey('compose-action-bar'),
                      actions: [
                        ColophonAction(
                          key: const ValueKey('compose-action-save'),
                          // Düğme ne yapacağını söylüyor: anahtar açıksa
                          // kaydetmek tek başına bitmiyor, bir ekran daha var.
                          label: _remindMe
                              ? context.l10n.actionSaveAndRemind
                              : context.l10n.actionSave,
                          semanticLabel: _remindMe
                              ? context.l10n.actionSaveAndRemind
                              : context.l10n.actionSave,
                          accent: true,
                          busy: _savePhase != ComposeSavePhase.idle,
                          busyLabel: _savePhase == ComposeSavePhase.locating
                              ? context.l10n.composeWaitingForLocation
                              : context.l10n.composeSaving,
                          onPressed: _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceMark extends StatelessWidget {
  const _SourceMark({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: palette.ember),
        const SizedBox(width: 6),
        Text(label, style: palette.overline.copyWith(color: palette.inkSoft)),
      ],
    );
  }
}
