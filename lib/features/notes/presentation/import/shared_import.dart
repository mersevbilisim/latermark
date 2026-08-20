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
    required this.remindAfterDays,
  });

  final String id;
  final XFile image;
  final DateTime createdAt;
  final String initialText;

  /// iOS Share Extension notu kendi içinde aldığı için kayıt, uygulama yeniden
  /// açıldığında doğrudan tamamlanır. Android ana uygulamayı açabildiğinden
  /// mevcut Compose ekranı gösterilir.
  final bool saveImmediately;

  /// Share Extension içinde seçilen tek-atışlı hatırlatma. Değer ana
  /// uygulamada entitlement ve bildirim izni kurallarından tekrar geçer.
  final int remindAfterDays;
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
        remindAfterDays: switch (raw['remindAfterDays']) {
          final num days => days.toInt().clamp(0, 365),
          _ => 0,
        },
      );
    } on MissingPluginException {
      // Widget testleri ve desteklenmeyen masaüstü platformları.
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Native gelen kutusundaki görseli ve yan verisini birlikte temizler.
  static Future<bool> complete(String id) async {
    _ensureInitialized();
    try {
      return await _channel.invokeMethod<bool>('completeSharedImport', {
            'id': id,
          }) ??
          true;
    } on MissingPluginException {
      // Desteklenmeyen platformda temizlenecek native gelen kutusu yoktur.
      return true;
    } on PlatformException {
      // DB ledger yeniden teslimi çoğaltmayacak; temizlik bir sonraki
      // foreground turunda tekrar denenebilir.
      return false;
    }
  }

  /// Share Extension'ın Pro-only seçenekleri göstermesi için son bilinen
  /// entitlement'ı App Group'a aynalar. Doğruluk kaynağı yine Drift/mağazadır;
  /// ana uygulama payload'ı işlerken hakkı yeniden kontrol eder.
  static Future<void> setProUnlocked(bool unlocked) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod<void>('setShareEntitlement', {
        'unlocked': unlocked,
      });
    } on MissingPluginException {
      // Android ve widget testlerinde iOS App Group'u yoktur.
    } on PlatformException {
      // Extension en kötü ihtimalle reminder seçeneğini gizler.
    }
  }
}
