import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bir karenin çekildiği yer.
@immutable
class NoteLocation {
  const NoteLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Kanaldan gelen ham sözlüğü çözer. Eksik ya da geçersiz değer `null` döner
  /// — yarım bir koordinat, koordinat değildir.
  static NoteLocation? fromMap(Object? value) {
    if (value is! Map) return null;
    final latitude = (value['latitude'] as num?)?.toDouble();
    final longitude = (value['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return NoteLocation(latitude: latitude, longitude: longitude);
  }

  @override
  bool operator ==(Object other) =>
      other is NoteLocation &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'NoteLocation($latitude, $longitude)';
}

/// Cihazın konumunu okuyan ince kanal.
///
/// **Eklenti kullanılmıyor**, her platform kendi yerel çözümüyle: iOS'ta
/// `CoreLocation`, Android'de `LocationManager`. İkisi de işletim sisteminin
/// parçası — ne Play Services bağımlılığı ekleniyor ne de projenin Swift
/// Package Manager kurulumuna dokunuluyor. Aynı gerekçe [OcrService] için de
/// geçerliydi.
///
/// Okunan koordinat **hiçbir yere gönderilmiyor**. Yer adına çevrilmesi ters
/// geocoding, yani ağ demek olurdu; uygulama bunu kullanıcı adına yapmıyor.
/// Koordinat veritabanında durur, haritayı kullanıcı dokunduğunda kendi
/// uygulaması açar.
class LocationService {
  LocationService({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('latermark/location');

  final MethodChannel _channel;

  bool get supported => Platform.isIOS || Platform.isAndroid;

  /// İzin **verilmiş mi**. Sistem istemini açmaz, yalnızca sorar.
  Future<bool> hasPermission() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (error) {
      debugPrint('Konum izni okunamadı: $error');
      return false;
    }
  }

  /// Sistem iznini ister. Kullanıcı daha önce reddettiyse işletim sistemi
  /// istemi tekrar açmaz ve `false` döner — bu durumda tek yol Ayarlar.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (error) {
      debugPrint('Konum izni istenemedi: $error');
      return false;
    }
  }

  /// Tek seferlik konum. İzin yoksa, servis kapalıysa ya da cihaz süre içinde
  /// sabitleyemezse `null` döner.
  ///
  /// Çağıran taraf bunu **beklememeli**: kaydetmeyi geciktirmek yerine
  /// konumsuz kaydetmek doğru davranış. `null` bir hata değil, "bu kayıtta
  /// konum yok" demek.
  Future<NoteLocation?> current() async {
    if (!supported) return null;
    try {
      return NoteLocation.fromMap(
        await _channel.invokeMethod<Map<Object?, Object?>>('current'),
      );
    } catch (error) {
      debugPrint('Konum alınamadı: $error');
      return null;
    }
  }
}
