import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Karenin kendi ışığı.
///
/// Detay sayfasının zemini düz bir gri değil: baskının arkasından, o karenin
/// baskın renginde çok zayıf bir aydınlanma gelir. Kırmızı bir fiş sıcak,
/// deniz kenarı serin bir odada durur. Fark %8 civarındadır — kimse "renkli
/// arka plan" demez, ama iki notu üst üste açan biri sayfanın *o fotoğrafa
/// ait* olduğunu hisseder.
///
/// Bunun için kare 12×12 piksele indirgenerek okunur; pahalı bir işlem değil,
/// tam çözünürlüklü kare hiç açılmaz. Değerler [PhotoAspect] gibi oturum
/// boyunca bellekte saklanır.
abstract final class PhotoTone {
  static final _cache = <String, Color>{};

  /// Bilinen ton; henüz okunmadıysa `null`.
  static Color? peek(String imageName) => _cache[imageName];

  /// Kareyi okur ve tonunu belleğe yazar. Zaten biliniyorsa hiçbir şey yapmaz.
  static Future<void> warm(String imageName, File file) async {
    if (_cache.containsKey(imageName)) return;
    _cache[imageName] = await _read(file);
  }

  static Future<Color> _read(File file) async {
    ui.Image? image;
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      // `instantiateImageCodecWithSize` buffer'ın sahipliğini devralır ve onu
      // kendisi kapatır. Burada ikinci bir `dispose` çağırmak assert'e düşer —
      // `PhotoAspect`'teki `ImageDescriptor.encoded` ise sahipliği almadığı
      // için orada elle kapatmak doğru.
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (_, _) =>
            const ui.TargetImageSize(width: 12, height: 12),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return _neutral;

      // Renkli pikseller ağır basar. Düz ortalama alınsa her kare aynı
      // kirli beje çıkardı; gökyüzünün mavisi kumun grisinde erirdi.
      final bytes = data.buffer.asUint8List();
      var red = 0.0, green = 0.0, blue = 0.0, total = 0.0;
      for (var i = 0; i + 3 < bytes.length; i += 4) {
        if (bytes[i + 3] < 8) continue;
        final r = bytes[i].toDouble();
        final g = bytes[i + 1].toDouble();
        final b = bytes[i + 2].toDouble();
        final high = math.max(r, math.max(g, b));
        final low = math.min(r, math.min(g, b));
        final saturation = high <= 0 ? 0.0 : (high - low) / high;
        final weight = 0.16 + saturation;
        red += r * weight;
        green += g * weight;
        blue += b * weight;
        total += weight;
      }
      if (total <= 0) return _neutral;

      final average = Color.from(
        alpha: 1,
        red: (red / total) / 255,
        green: (green / total) / 255,
        blue: (blue / total) / 255,
      );

      // Ton normalize edilir: hangi kare gelirse gelsin zemine aynı ölçüde
      // karışsın. Aksi hâlde koyu bir kare hiç görünmez, parlak bir kare
      // sayfayı ele geçirirdi. Taşınan tek bilgi renk *özü*.
      final hsl = HSLColor.fromColor(average);
      return hsl
          .withSaturation(hsl.saturation.clamp(0.22, 0.78))
          .withLightness(0.55)
          .toColor();
    } catch (error) {
      debugPrint('Kare tonu okunamadı (${file.path}): $error');
      return _neutral;
    } finally {
      image?.dispose();
    }
  }

  static const _neutral = Color(0xFF8A8A8A);

  @visibleForTesting
  static void clear() => _cache.clear();
}
