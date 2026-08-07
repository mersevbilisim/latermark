import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../capture/capture_page.dart';
import '../import/gallery_import.dart';
import '../import/shared_import.dart';
import 'widgets/capture_preview.dart';
import 'widgets/note_composer.dart';
import 'widgets/reminder_field.dart';
import '../../../../l10n/l10n_context.dart';
import '../../../../core/utils/app_format.dart';
import '../../../paywall/presentation/paywall_host.dart';
import '../../domain/retention.dart';

/// Çekilen kareye not düşme ekranı.
enum ComposeSource { camera, gallery, shared }

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.capture,
    this.source = ComposeSource.camera,
    this.initialText = '',
    this.capturedAt,
    this.sharedImportId,
  });

  /// Düzenlenecek kare. Kamera ve paylaşım kaynakları Latermark'ın yönettiği
  /// geçici kopyalardır; galeri kaynağının sahipliği sistemde kalır.
  final XFile capture;
  final ComposeSource source;
  final String initialText;
  final DateTime? capturedAt;
  final String? sharedImportId;

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

  /// Hatırlatma gün sayısı. Sıfır = kapalı, ve varsayılan bu.
  int _remindAfterDays = 0;

  /// Bildirim izni yokken `true`; alanın altında uyarı gösterilir.
  bool _reminderBlocked = false;

  /// İzin bir kez istenir; kullanıcı reddettiyse her rakam değişiminde
  /// sistem istemini tekrar tetiklemenin anlamı yok.
  bool _permissionAsked = false;

  bool _saving = false;
  bool _tempCleared = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _capturedAt = widget.capturedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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

  /// Kullanıcı ilk kez süre verdiğinde izin *o anda* istenir.
  ///
  /// Açılışta sormak yerine burada sormak, isteği kullanıcının niyetini
  /// gösterdiği ana bağlıyor — sistem istemi de böylece anlamlı geliyor.
  void _onReminderChanged(int value) {
    setState(() => _remindAfterDays = value);
    if (value > 0) unawaited(_ensureReminderPermission());
  }

  Future<void> _ensureReminderPermission() async {
    final reminders = context.reminders;
    final settings = AppScope.settingsOf(context);

    var allowed = await reminders.hasPermission();
    if (!allowed && !_permissionAsked) {
      _permissionAsked = true;
      allowed = await reminders.requestPermission();
    }
    // Hatırlatmaların ana şalteri kapalıysa, kullanıcı burada süre vererek
    // zaten istediğini söylemiş oluyor.
    if (allowed) await settings.setReminderEnabled(true);

    if (!mounted) return;
    setState(() => _reminderBlocked = !allowed);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final repository = AppScope.of(context);
    final navigator = Navigator.of(context);

    try {
      // Saklama süresi artık her çekimde sorulmuyor; Ayarlar'daki varsayılanla
      // açılıyor ve gerekirse kaydın kendi ekranından değiştiriliyor.
      final settings = await AppScope.settingsOf(context).read();

      await repository.create(
        capture: widget.capture,
        body: _text.text,
        retention: RetentionChoice(
          settings.defaultRetention,
          customMinutes: settings.defaultCustomMinutes,
        ),
        remindAfterDays: _remindAfterDays,
        createdAt: _capturedAt,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, context.l10n.toastSaveFailed, error: true);
      return;
    }

    await _clearTemp();
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _discard() async {
    await _clearTemp();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _retake() async {
    if (widget.source != ComposeSource.camera) {
      await _reselectFromGallery();
      return;
    }

    await _clearTemp();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(AppRoutes.shutter(const CapturePage()));
  }

  Future<void> _reselectFromGallery() async {
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
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _clearTemp();
        },
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
                  extra: ReminderField(
                    days: _remindAfterDays,
                    blocked: _reminderBlocked,
                    locked: !AppScope.preferences(context).proUnlocked,
                    onChanged: _onReminderChanged,
                    onLockedTap: () =>
                        showPaywall(context, reason: PaywallReason.reminder),
                    onOpenSystemSettings: () =>
                        context.reminders.openSystemSettings(),
                  ),
                  header: ComposerStamp(
                    at: context.l10n.stamp(_capturedAt),
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
                  action: PrimaryButton(
                    label: context.l10n.actionSave,
                    busy: _saving,
                    onPressed: _save,
                  ),
                ),
              ),
            ),
          ],
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
