import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';

/// Fotoğraflar/Galeri uygulamasından "Paylaş → Latermark" ile gelen bir kare.
///
/// Native taraf, geçici URI erişimi kaybolmadan önce görseli Latermark'ın
/// yönettiği bir gelen kutusuna kopyalar. Flutter kayıt tamamlanana ya da
/// kullanıcı vazgeçene kadar bu kopyayı kuyrukta bırakır.
class SharedImport {
  const SharedImport({
    required this.id,
    required this.image,
    required this.createdAt,
    required this.initialText,
    required this.saveImmediately,
  });

  final String id;
  final XFile image;
  final DateTime createdAt;
  final String initialText;

  /// iOS Share Extension notu kendi içinde aldığı için kayıt, uygulama yeniden
  /// açıldığında doğrudan tamamlanır. Android ana uygulamayı açabildiğinden
  /// mevcut Compose ekranı gösterilir.
  final bool saveImmediately;
}

/// iOS Share Extension ile Android ACTION_SEND'i tek Dart akışında birleştirir.
abstract final class SharedImportBridge {
  static const _channel = MethodChannel('latermark/shared_import');
  static final _available = StreamController<void>.broadcast();
  static bool _initialized = false;

  static Stream<void> get onImportAvailable {
    _ensureInitialized();
    return _available.stream;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedImportAvailable') {
        _available.add(null);
      }
    });
  }

  static Future<SharedImport?> takePending() async {
    _ensureInitialized();
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'takePendingSharedImport',
      );
      if (raw == null) return null;

      final id = raw['id'];
      final path = raw['path'];
      if (id is! String || id.isEmpty || path is! String || path.isEmpty) {
        return null;
      }

      final createdAtMilliseconds = raw['createdAtMilliseconds'];
      return SharedImport(
        id: id,
        image: XFile(path),
        createdAt: createdAtMilliseconds is num
            ? DateTime.fromMillisecondsSinceEpoch(createdAtMilliseconds.toInt())
            : DateTime.now(),
        initialText: raw['initialText'] is String
            ? raw['initialText']! as String
            : '',
        saveImmediately: raw['saveImmediately'] == true,
      );
    } on MissingPluginException {
      // Widget testleri ve desteklenmeyen masaüstü platformları.
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Native gelen kutusundaki görseli ve yan verisini birlikte temizler.
  static Future<void> complete(String id) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod<void>('completeSharedImport', {'id': id});
    } on MissingPluginException {
      // Desteklenmeyen platformda temizlenecek native gelen kutusu yoktur.
    } on PlatformException {
      // İşletim sistemi kendi önbelleğini daha sonra temizleyebilir. Kullanıcı
      // akışını yalnızca temizlik hatası yüzünden başarısız göstermeyiz.
    }
  }
}
