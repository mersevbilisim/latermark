import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/tr_format.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/retention.dart';
import '../capture/capture_page.dart';
import 'widgets/capture_preview.dart';
import 'widgets/note_composer.dart';

/// Çekilen kareye not düşme ekranı.
class ComposePage extends StatefulWidget {
  const ComposePage({super.key, required this.capture});

  /// Kameranın geçici klasöre bıraktığı kare. Kaydedilirse kalıcı klasöre
  /// kopyalanır; her durumda geçici dosya bu ekrandan çıkarken silinir.
  final XFile capture;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  /// Yazı alanının rahatça durabilmesi için ayrılan en küçük yükseklik.
  /// Fotoğrafın boyu bu değerden artan yere göre hesaplanır.
  static const _composerReserve = 336.0;

  final _text = TextEditingController();

  /// Kaydın zamanı, çekimin yapıldığı andır — kaydete basıldığı an değil.
  final DateTime _capturedAt = DateTime.now();

  Retention _retention = Retention.off;
  bool _saving = false;
  bool _tempCleared = false;

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
    setState(() => _saving = true);

    final repository = AppScope.of(context);
    final navigator = Navigator.of(context);

    try {
      await repository.create(
        capture: widget.capture,
        body: _text.text,
        retention: _retention,
        createdAt: _capturedAt,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Kaydedilemedi. Tekrar dene.', error: true);
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
    await _clearTemp();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(AppRoutes.shutter(const CapturePage()));
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
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 22, 22, bottomSafe + 18),
                child: NoteComposer(
                  controller: _text,
                  autofocus: true,
                  retention: _retention,
                  onRetentionChanged: (value) =>
                      setState(() => _retention = value),
                  header: ComposerStamp(at: TrFormat.stamp(_capturedAt)),
                  action: PrimaryButton(
                    label: 'Kaydet',
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
