import 'dart:async';

import 'package:flutter/services.dart';

/// Uygulamanın dışından gelen bir yönlendirme.
///
/// Şimdilik tek üye var, ama kapalı hiyerarşi bilinçli: Spotlight sonucu,
/// ileride bir App Intent ya da bir kısayol aynı kapıdan girsin diye. Yeni bir
/// üye eklendiğinde bunu işleyen `switch`'ler derleme zamanında eksik kalır.
sealed class AppLink {
  const AppLink();
}

/// Belirli bir kaydın detayını aç.
final class OpenNoteLink extends AppLink {
  const OpenNoteLink(this.noteId);

  final int noteId;

  @override
  bool operator ==(Object other) =>
      other is OpenNoteLink && other.noteId == noteId;

  @override
  int get hashCode => noteId.hashCode;

  @override
  String toString() => 'OpenNoteLink($noteId)';
}

/// Native tarafın uygulama içi yönlendirmeleri geçtiği tek kanal.
///
/// Ana ekran widget'ının kendi yolu var (`HomeWidgetLink`); o `home_widget`
/// paketinin URL akışına bağlı ve dokunulmadı. Bu kanal onun taşımadığı
/// yönlendirmeler için: bugün Spotlight sonuçları, yarın bir App Intent ya da
/// kısayol.
///
/// Teslim `SharedImportBridge` ile aynı biçimde: native taraf yönlendirmeyi
/// **bekletir** ve yalnızca "bir şey var" der, Dart gelip alır. Soğuk açılışta
/// bu şart — kullanıcı sonuca dokunduğunda Flutter motoru henüz ayakta
/// olmayabiliyor — ve tek teslim yolu bıraktığı için aynı yönlendirmenin iki
/// kez işlenmesi de imkânsız.
abstract final class AppLinkBridge {
  static const _channel = MethodChannel('latermark/app_link');
  static final _controller = StreamController<AppLink>.broadcast();
  static bool _initialized = false;

  /// Uygulama çalışırken gelen yönlendirmeler.
  static Stream<AppLink> get links {
    _ensureInitialized();
    return _controller.stream;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'linkAvailable') return;
      final link = await takePending();
      if (link != null && !_controller.isClosed) _controller.add(link);
    });
  }

  /// Native tarafta bekleyen yönlendirmeyi alır ve kuyruktan düşürür.
  static Future<AppLink?> takePending() async {
    _ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<String>('takePendingLink');
      return raw == null ? null : appLinkFromUri(Uri.tryParse(raw));
    } on MissingPluginException {
      // Widget testleri ve kanalı olmayan platformlar.
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// `latermark://note/12` biçimindeki yönlendirmeyi çözer.
///
/// Şema ana ekran widget'ıyla aynı (`kWidgetUrlScheme`); ayıran şey widget'ın
/// eklediği `homeWidget` sorgu parametresi. Aynı sözleşmeyi paylaşmak, bir
/// bağlantının hangi kapıdan girdiğinden bağımsız olarak aynı şeyi ifade
/// etmesini sağlıyor.
AppLink? appLinkFromUri(Uri? uri) {
  if (uri == null || uri.scheme != 'latermark') return null;
  if (uri.host != 'note' || uri.pathSegments.length != 1) return null;

  final id = int.tryParse(uri.pathSegments.single);
  return id != null && id > 0 ? OpenNoteLink(id) : null;
}
