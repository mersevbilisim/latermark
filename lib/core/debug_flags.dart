import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Yalnızca elde test etmek için açılan geçici anahtarlar.
///
/// İki kapıdan geçerler:
///
/// **Release'e sızamazlar.** Hepsi [kDebugMode] ile çarpılır; `flutter build
/// --release` ile üretilen pakette değerleri her koşulda `false` olur. Biri
/// açık unutulsa bile App Store'a Pro'yu bedavaya veren ya da saniyeler
/// içinde bildirim yağdıran bir sürüm çıkamaz.
///
/// **Test paketini de etkilemezler.** `flutter test` de debug modda koşar;
/// tek başına [kDebugMode]'a güvenmek, ücretsiz katmanı doğrulayan testleri
/// sessizce Pro'ya çevirip yeşil gösterirdi — yani testin tam olarak
/// korumakla görevli olduğu şeyi kör ederdi.
///
/// Test bittiğinde tek yapılacak: aşağıdaki iki değeri `false` çevirmek.
abstract final class DebugFlags {
  static const bool _forcePro = true;
  static const bool _fastReminders = true;

  /// Anahtarların gerçekten çalıştığı tek ortam: elde, debug yapısında.
  static final bool _live =
      kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST');

  /// Mağazaya hiç uğramadan Pro hakkı verir.
  ///
  /// Karar veritabanına yazılır, çünkü hak üç ayrı yerden okunuyor: arayüz
  /// tercihleri, not deposu (`_isProUnlocked`) ve hatırlatma servisi. Yalnızca
  /// arayüzü kandırmak, kaydetme anında yeniden gerçek hakka düşen tutarsız
  /// bir durum bırakırdı.
  static bool get forcePro => _live && _forcePro;

  /// Hatırlatmaları gün yerine [fastReminderDelay] sonrasına kurar.
  ///
  /// Gerçek akışta en kısa hatırlatma bir gün sonrasıdır; bildirim metnini,
  /// dokunma yönlendirmesini ve tepsi davranışını elde görmek için beklenecek
  /// bir süre değil.
  ///
  /// Yalnızca bildirimin kurulacağı **an** öne çekilir; "hangi notun
  /// hatırlatması var" kararına (`pendingReminderAt`) dokunulmaz. Yani gün
  /// verilmemiş bir not yine bildirim almaz — ve karttaki geri sayım gerçek
  /// kuralı yazmaya devam eder.
  static bool get fastReminders => _live && _fastReminders;

  /// [fastReminders] açıkken bildirimin kurulacağı gecikme.
  static const Duration fastReminderDelay = Duration(seconds: 15);
}
