import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/utils/tr_format.dart';
import '../notes/data/notes_database.dart';
import '../notes/data/notes_repository.dart';
import 'widget_keys.dart';

/// Ana ekran widget'ını besleyen köprü.
///
/// Uygulama açıkken depodaki değişiklikleri dinler ve en son kaydın küçük bir
/// özetini paylaşılan alana yazar. Widget'ın kendisi hiçbir hesap yapmaz —
/// Türkçe tarih biçimlendirmesi, kalan süre metni ve küçültülmüş fotoğraf
/// hazır olarak gider. Bu sayede Swift/Kotlin tarafında tarih kütüphanesi
/// taşımak gerekmez.
class HomeWidgetBridge {
  HomeWidgetBridge(this._repository);

  final NotesRepository _repository;
  StreamSubscription<List<Note>>? _subscription;

  /// Widget'ta gösterilecek fotoğrafın en geniş kenarı.
  ///
  /// WidgetKit eklentileri dar bir bellek bütçesiyle çalışır; tam çözünürlüklü
  /// bir kare çözülmeye kalkışıldığında eklenti öldürülür.
  static const _photoWidth = 720;

  /// Son yazılan durumu tutar; aynı veriyi tekrar tekrar yazıp widget'ı
  /// gereksiz yere tazelemeyi önler.
  String? _lastSignature;

  Future<void> start() async {
    if (!_isSupported) return;

    try {
      await HomeWidget.setAppGroupId(kAppGroupId);
    } catch (error) {
      debugPrint('Widget kapsayıcısı hazırlanamadı: $error');
      return;
    }

    _subscription = _repository.watchNotes().listen(
      _publish,
      onError: (Object error) => debugPrint('Widget akışı hatası: $error'),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static bool get _isSupported => Platform.isIOS || Platform.isAndroid;

  Future<void> _publish(List<Note> notes) async {
    final latest = notes.isEmpty ? null : notes.first;

    // Fotoğraf yolu imzaya dahil: not aynı kalsa da kare değişmiş olabilir.
    final signature = latest == null
        ? 'empty:${notes.length}'
        : '${latest.id}|${latest.body}|${latest.imageName}|'
              '${latest.expiresAt}|${notes.length}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<bool>(WidgetKeys.hasNote, latest != null),
        HomeWidget.saveWidgetData<int>(WidgetKeys.count, notes.length),
        HomeWidget.saveWidgetData<int>(WidgetKeys.noteId, latest?.id ?? 0),
        HomeWidget.saveWidgetData<String>(WidgetKeys.body, latest?.body ?? ''),
        HomeWidget.saveWidgetData<String>(
          WidgetKeys.time,
          latest == null ? '' : TrFormat.time(latest.createdAt),
        ),
        HomeWidget.saveWidgetData<String>(
          WidgetKeys.date,
          latest == null ? '' : TrFormat.dayHeader(latest.createdAt),
        ),
        HomeWidget.saveWidgetData<int>(
          WidgetKeys.expiresAt,
          (latest?.expiresAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
        ),
      ]);

      if (latest != null) {
        final thumbnail = await _thumbnail(_repository.imageOf(latest));
        if (thumbnail != null) {
          await HomeWidget.saveFile(
            WidgetKeys.photo,
            thumbnail,
            extension: 'png',
          );
        }
      }

      await HomeWidget.updateWidget(
        iOSName: kIosWidgetName,
        androidName: kAndroidWidgetProvider,
      );
    } catch (error) {
      // Widget güncellenememesi uygulamanın çalışmasını engellememeli:
      // App Group yapılandırılmamış olabilir ya da widget hiç eklenmemiştir.
      debugPrint('Widget güncellenemedi: $error');
    }
  }

  /// Kareyi widget'a sığacak boyuta indirip PNG olarak kodlar.
  Future<Uint8List?> _thumbnail(File source) async {
    if (!source.existsSync()) return null;

    ui.Image? image;
    try {
      final bytes = await source.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _photoWidth,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('Widget görseli hazırlanamadı: $error');
      return null;
    } finally {
      image?.dispose();
    }
  }
}
