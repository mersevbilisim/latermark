import 'dart:math' as math;

import 'dart:ui' show Brightness, Color;

/// Kullanıcının seçtiği tondan uygulamanın kullanabileceği rengi üretir.
///
/// Ham bir RGB seçici bilinçli olarak yok. Vurgu rengi üç ayrı yerde birden
/// okunmak zorunda: koyu zeminde, aydınlık zeminde ve fotoğrafın üstünde.
/// Kullanıcı doğrudan RGB seçseydi bu üçünden en az biri her seferinde
/// kaybolurdu — açık sarı aydınlık temada, lacivert koyu temada.
///
/// Bu yüzden kullanıcı yalnızca **tonu** (hue) seçiyor; parlaklık ve renklilik
/// uygulamaya ait. Küratörlü altı renk zaten bu disiplini elle taşıyordu —
/// OKLCH'de ölçüldüklerinde koyu tema için L≈0.73–0.81, aydınlık için
/// L≈0.52–0.62 aralığına kümeleniyorlar. Buradaki hedefler o ölçümün
/// ortalaması; yani özel bir ton, küratörlü renklerin yanında yabancı
/// durmuyor.
///
/// Renk uzayı OKLCH: HSL'in aksine ton değiştiğinde algılanan parlaklık sabit
/// kalıyor. HSL'de %50 açıklıktaki sarı ile %50 açıklıktaki mavi bambaşka
/// parlaklıkta görünür ve tek bir eşik bütün tonlar için doğru olamaz.
abstract final class AccentTone {
  /// Koyu zemin ve fotoğraf üstü için hedef parlaklık.
  static const _darkLightness = 0.760;

  /// Aydınlık zemin için hedef parlaklık.
  ///
  /// Küratörlü renklerin ortalaması 0.545 ama o değer, sarı-yeşil bandındaki
  /// tonlarda kâğıt zemine karşı WCAG AA eşiğinin (4.5) altına düşüyor —
  /// ölçüldü, en kötü ton 4.24. 0.52 bütün çemberi 4.7'nin üstünde tutuyor;
  /// bu da küratörlü altının en zorlanan üyesinin (altın, 4.74) kendi tabanı.
  /// Yani özel bir ton, elle seçilmiş renklerden daha kötü olamıyor.
  static const _lightLightness = 0.520;

  /// Hedef renklilik. sRGB'ye sığmayan tonlarda [_fit] içeri çekiyor.
  static const _chroma = 0.150;

  /// Yeni bir özel renk ilk açıldığında başlanan ton.
  static const defaultHue = 36;

  /// Kullanıcının seçebileceği ton sayısı — tam çember.
  static const hueCount = 360;

  static int normalizeHue(int hue) => ((hue % hueCount) + hueCount) % hueCount;

  /// Aydınlık/koyu temanın gövde rengi.
  static Color colorFor(int hue, Brightness brightness) => _fit(
    brightness == Brightness.dark ? _darkLightness : _lightLightness,
    _chroma,
    normalizeHue(hue).toDouble(),
  );

  /// Fotoğraf ve vizör üstü: zemin temadan bağımsız karanlık olduğu için her
  /// zaman koyu temanın parlak tonu kullanılır.
  static Color onPhoto(int hue) => colorFor(hue, Brightness.dark);

  /// İstenen renkliliği sRGB sınırına kadar geri çeker.
  ///
  /// Her ton her renkliliği taşıyamıyor: aynı parlaklıkta sarı, mavinin
  /// ulaşabileceğinden çok daha doygun olabilir. Sınırı aşan değer basitçe
  /// kırpılırsa hem ton hem parlaklık kayıyor; ikili arama renkliliği
  /// düşürerek ikisini de koruyor.
  static Color _fit(double lightness, double chroma, double hue) {
    var low = 0.0;
    var high = chroma;
    for (var i = 0; i < 20; i++) {
      final mid = (low + high) / 2;
      if (_inGamut(_linearRgb(lightness, mid, hue))) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final rgb = _linearRgb(lightness, low, hue);
    return Color.fromARGB(
      0xFF,
      _channel(rgb[0]),
      _channel(rgb[1]),
      _channel(rgb[2]),
    );
  }

  static bool _inGamut(List<double> rgb) =>
      rgb.every((value) => value >= -0.0005 && value <= 1.0005);

  /// OKLab → doğrusal sRGB. Değerler kasıtlı olarak kırpılmıyor; sınır
  /// denetimini [_inGamut] yapıyor.
  static List<double> _linearRgb(double lightness, double chroma, double hue) {
    final radians = hue * math.pi / 180;
    final a = chroma * math.cos(radians);
    final b = chroma * math.sin(radians);

    final l = _cube(lightness + 0.3963377774 * a + 0.2158037573 * b);
    final m = _cube(lightness - 0.1055613458 * a - 0.0638541728 * b);
    final s = _cube(lightness - 0.0894841775 * a - 1.2914855480 * b);

    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ];
  }

  static double _cube(double value) => value * value * value;

  static int _channel(double linear) {
    final clamped = linear.clamp(0.0, 1.0);
    final encoded = clamped <= 0.0031308
        ? 12.92 * clamped
        : 1.055 * math.pow(clamped, 1 / 2.4) - 0.055;
    return (encoded * 255).round().clamp(0, 255);
  }
}
