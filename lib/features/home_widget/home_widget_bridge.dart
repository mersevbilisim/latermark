import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_accent.dart';
import '../../core/utils/app_format.dart';
import '../../l10n/app_localizations.dart';
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

  /// Widget metinleri de kullanıcının diliyle yazılır.
  ///
  /// Köprü widget ağacının dışında çalıştığı için [L10n]'i kendi bulamıyor;
  /// [AppScope] dil değiştikçe buraya veriyor ve widget'ı tazeliyor.
  L10n? _l10n;

  /// Pro hakkı. [AppScope] değiştikçe veriyor.
  bool _pro = false;
  int _entitlementRevision = 0;
  AppAccent _accent = AppAccent.orange;
  List<Note>? _lastNotes;

  /// Drift, dil ve satın alma akışları aynı anda değişebilir. Native depoya
  /// yapılan birden çok yayının anahtarlarını birbirine karıştırmaması için
  /// bütün kareleri tek sıra üzerinden geçiriyoruz.
  Future<void> _publishQueue = Future<void>.value();

  set pro(bool value) {
    if (_pro == value) return;
    _pro = value;
    _entitlementRevision++;
    _invalidate();
  }

  set accent(AppAccent value) {
    if (_accent == value) return;
    _accent = value;
    _invalidate();
  }

  set l10n(L10n value) {
    if (_l10n?.localeName == value.localeName) return;
    _l10n = value;
    // Dil değişti: imza da değiştiği için bir sonraki yayında widget tazelenir.
    // Elde son liste yoksa beklemek yeterli; akış zaten sürekli yayın yapıyor.
    _invalidate();
  }

  void _invalidate() {
    _lastSignature = null;
    final notes = _lastNotes;
    if (notes != null) _schedulePublish(notes);
  }

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
      _schedulePublish,
      onError: (Object error) => debugPrint('Widget akışı hatası: $error'),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _publishQueue;
  }

  static bool get _isSupported => Platform.isIOS || Platform.isAndroid;

  void _schedulePublish(List<Note> notes) {
    final snapshot = List<Note>.unmodifiable(notes);
    _lastNotes = snapshot;
    _publishQueue = _publishQueue.then((_) => _publish(snapshot));
    unawaited(_publishQueue);
  }

  Future<void> _publish(List<Note> notes) async {
    // Hak geri alındığında yalnızca native görünümün kilit dalına güvenmeyiz.
    // Paylaşılan kapsayıcıdaki Pro içeriğini de aynı yayında sıfırlarız; böylece
    // eski bir timeline, farklı bir widget ailesi veya ilerideki bir renderer
    // not metnini/fotoğrafı yanlışlıkla yeniden gösteremez.
    final isPro = _pro;
    final entitlementRevision = _entitlementRevision;
    final latest = isPro && notes.isNotEmpty ? notes.first : null;
    final publishedCount = isPro ? notes.length : 0;

    // Fotoğraf yolu imzaya dahil: not aynı kalsa da kare değişmiş olabilir.
    final signature = latest == null
        ? 'empty:$publishedCount:${_l10n?.localeName}:$isPro:${_accent.name}'
        : '${latest.id}|${latest.body}|${latest.imageName}|'
              '${latest.createdAt}|${latest.expiresAt}|$publishedCount|'
              '${_l10n?.localeName}|'
              '$isPro|${_accent.name}';
    if (signature == _lastSignature) return;

    try {
      // Geri alma işleminin ilk yazısı hak anahtarıdır. Native timeline tam bu
      // sırada kendiliğinden yenilense bile eski içerik kilit dalını aşamaz.
      // Yeniden Pro olurken ise içerik ve fotoğraf eksiksiz hazırlandıktan
      // sonra hakkı açarak ters yöndeki aynı yarışı da kapatıyoruz.
      if (!isPro) {
        await HomeWidget.saveWidgetData<bool>(WidgetKeys.pro, false);
        // Alan temizliğinin herhangi bir adımı başarısız olsa bile mevcut
        // native timeline beklemeden kilit görünümüne geçsin.
        await _refreshWidget();
      }

      await Future.wait([
        HomeWidget.saveWidgetData<bool>(WidgetKeys.hasNote, latest != null),
        HomeWidget.saveWidgetData<int>(WidgetKeys.count, publishedCount),
        HomeWidget.saveWidgetData<String>(
          WidgetKeys.accent,
          _accent.onPhoto.toARGB32().toRadixString(16).padLeft(8, '0'),
        ),
        HomeWidget.saveWidgetData<int>(WidgetKeys.noteId, latest?.id ?? 0),
        HomeWidget.saveWidgetData<String>(WidgetKeys.body, latest?.body ?? ''),
        HomeWidget.saveWidgetData<String>(
          WidgetKeys.time,
          latest == null || _l10n == null ? '' : _l10n!.time(latest.createdAt),
        ),
        HomeWidget.saveWidgetData<String>(
          WidgetKeys.date,
          latest == null || _l10n == null
              ? ''
              : _l10n!.dayHeader(latest.createdAt),
        ),
        HomeWidget.saveWidgetData<int>(
          WidgetKeys.expiresAt,
          (latest?.expiresAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
        ),
        HomeWidget.saveWidgetData<int>(
          WidgetKeys.createdAt,
          (latest?.createdAt.millisecondsSinceEpoch ?? 0) ~/ 1000,
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
        } else {
          // Yeni karenin küçük görseli üretilemediyse önceki nota ait dosya
          // görünür kalmamalı. Native taraf bu boşlukta kendi diyaframlı
          // fallback kompozisyonunu çizer.
          await HomeWidget.saveWidgetData<String>(WidgetKeys.photo, null);
        }
      } else {
        // home_widget, saveFile ile yönettiği yol `null` yapılırken varsayılan
        // olarak fiziksel dosyayı da siler; anahtar ve PNG birlikte temizlenir.
        await HomeWidget.saveWidgetData<String>(WidgetKeys.photo, null);
      }

      if (isPro) {
        // Bu yayın hazırlanırken hak değiştiyse eski kare entitlement'ı tekrar
        // açamaz. Son durum Free ise kilidi burada öne al; kuyruğa eklenen yeni
        // yayın kalan alanları hemen ardından temizleyecek.
        if (_entitlementRevision != entitlementRevision || !_pro) {
          if (!_pro) await _revokeAndRefresh();
          return;
        }

        await HomeWidget.saveWidgetData<bool>(WidgetKeys.pro, true);

        // Platform-channel yazısı beklenirken de hak değişebilir. Eski Pro
        // yayınının son yazı olarak `true` bırakmasına izin verme.
        if (_entitlementRevision != entitlementRevision || !_pro) {
          if (!_pro) await _revokeAndRefresh();
          return;
        }
      }

      await _refreshWidget();
      // Yalnızca eksiksiz yazılmış bir kareyi yinelenmiş say. Bir dosya ya
      // da platform güncellemesi başarısız olursa aynı durum sonraki akışta
      // kendiliğinden yeniden denenebilsin.
      _lastSignature = signature;
    } catch (error) {
      // Widget güncellenememesi uygulamanın çalışmasını engellememeli:
      // App Group yapılandırılmamış olabilir ya da widget hiç eklenmemiştir.
      debugPrint('Widget güncellenemedi: $error');
    }
  }

  Future<void> _revokeAndRefresh() async {
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.pro, false);
    await _refreshWidget();
  }

  Future<void> _refreshWidget() async {
    await HomeWidget.updateWidget(
      iOSName: kIosWidgetName,
      androidName: kAndroidWidgetProvider,
    );
    if (Platform.isIOS) {
      // WidgetKit her `kind` için ayrı timeline tutar. Yeni hızlı çekim
      // widget'ı özellikle Pro hakkı geri alındığında aynı karede kilitlensin.
      await HomeWidget.updateWidget(iOSName: kIosCaptureWidgetName);
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
