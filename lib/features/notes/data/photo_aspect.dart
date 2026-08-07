import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Karelerin en-boy oranlarını tutan bellek içi tablo.
///
/// Izgara, kutuları fotoğrafın kendi oranına göre diziyor; bunun için kareyi
/// çözmeden önce boyutunu bilmek gerekiyor. [ui.ImageDescriptor.encoded] tam
/// da bunu yapar — dosyanın yalnızca başlığını okur, pikselleri açmaz. Yüzlerce
/// kare için bile maliyeti birkaç milisaniye.
///
/// Değerler oturum boyunca saklanır. Kalıcı olmasına gerek yok: bir sonraki
/// açılışta yeniden okumak, veritabanına sütun eklemekten hem ucuz hem de
/// senkron kalma derdi olmayan bir çözüm.
abstract final class PhotoAspect {
  static final _cache = <String, double>{};

  /// Bilinen oran; henüz okunmadıysa `null`.
  static double? peek(String imageName) => _cache[imageName];

  /// Verilen kareler için oranları çözer. Zaten bilinenler atlanır.
  ///
  /// Okunamayan dosya (silinmiş, bozuk) için 1.0 yazılır; ızgara boşluk
  /// bırakmak yerine kare bir kutu çizer.
  static Future<void> warm(Map<String, File> files) async {
    final missing = files.entries.where((e) => !_cache.containsKey(e.key));
    if (missing.isEmpty) return;

    await Future.wait(missing.map((entry) async {
      _cache[entry.key] = await _read(entry.value);
    }));
  }

  static Future<double> _read(File file) async {
    ui.ImmutableBuffer? buffer;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final aspect = descriptor.width / descriptor.height;
      descriptor.dispose();
      return aspect.isFinite && aspect > 0 ? aspect : 1;
    } catch (error) {
      debugPrint('Kare oranı okunamadı (${file.path}): $error');
      return 1;
    } finally {
      buffer?.dispose();
    }
  }

  @visibleForTesting
  static void clear() => _cache.clear();
}
