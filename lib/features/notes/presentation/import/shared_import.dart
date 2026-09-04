import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';

enum QueuedReminderState { none, reserved, scheduled }

/// Uygulamanın dışından gelen bir teslim.
///
/// İki kaynağı var ve ikisi de aynı gelen kutusundan geçiyor:
/// Fotoğraflar/Galeri uygulamasından "Paylaş → Latermark" ile gelen bir kare,
/// ve Siri/Kestirmeler'den gelen karesiz bir metin notu. Native taraf, geçici
/// erişim kaybolmadan önce payload'ı Latermark'ın yönettiği bir gelen kutusuna
/// yazıyor; Flutter kayıt tamamlanana ya da kullanıcı vazgeçene kadar
/// kuyrukta bırakıyor.
class SharedImport {
  const SharedImport({
    required this.id,
    required this.image,
    required this.createdAt,
    required this.initialText,
    required this.saveImmediately,
    required this.remindAfterDays,
    this.remindAt,
    this.freeReminderReserved = false,
    this.freeReminderClaimed = false,
    this.queuedReminderState = QueuedReminderState.none,
  });

  final String id;

  /// Karesiz teslimde `null` — kayıt yalnızca yazıdan oluşur (bkz. `NoteKind`).
  final XFile? image;

  final DateTime createdAt;
  final String initialText;

  /// iOS Share Extension notu kendi içinde aldığı için kayıt, uygulama yeniden
  /// açıldığında doğrudan tamamlanır. Android ana uygulamayı açabildiğinden
  /// mevcut Compose ekranı gösterilir.
  final bool saveImmediately;

  /// Share Extension içinde seçilen tek-atışlı hatırlatma. Değer ana
  /// uygulamada entitlement ve bildirim izni kurallarından tekrar geçer.
  final int remindAfterDays;

  /// Siri'nin bildiği **mutlak** hatırlatma anı.
  ///
  /// Gün sayısına çevrilmiyor: "yarın 9'da" diyen birinin saati kaybolurdu.
  /// Uzantı bu anı beklerken bildirimi de kendisi kurdu; ana uygulama kaydı
  /// oluşturduğunda o geçici alarmı kaldırıp kendi programına alıyor.
  final DateTime? remindAt;

  /// Siri isteği Free katmanında alınırken App Group'ta ayrılan slot.
  /// 1.0.3 metadata'sında alan yoktur ve `false` çözülür.
  final bool freeReminderReserved;

  /// Rezervasyonun artık Drift'teki not tarafından sayıldığını gösterir.
  final bool freeReminderClaimed;

  /// Geçici `import/<id>` alarmının kalıcı devir durumu.
  final QueuedReminderState queuedReminderState;

  bool get queuedReminderWasScheduled =>
      queuedReminderState == QueuedReminderState.scheduled;

  bool get isText => image == null;
}

/// iOS Share Extension, iOS App Intents ve Android ACTION_SEND'i tek Dart
/// akışında birleştirir.
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
      if (id is! String || id.isEmpty) return null;

      // `kind` alanı olmayan teslimler bu sürümden öncesine ait ve her zaman
      // fotoğraftır; sözleşme geriye uyumlu.
      final isText = raw['kind'] == 'text';
      final path = raw['path'];
      if (!isText && (path is! String || path.isEmpty)) return null;

      final createdAtMilliseconds = raw['createdAtMilliseconds'];
      return SharedImport(
        id: id,
        image: isText ? null : XFile(path! as String),
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
        remindAt: switch (raw['remindAtMilliseconds']) {
          final num milliseconds => DateTime.fromMillisecondsSinceEpoch(
            milliseconds.toInt(),
          ),
          _ => null,
        },
        freeReminderReserved: raw['freeReminderReserved'] == true,
        freeReminderClaimed: raw['freeReminderClaimed'] == true,
        queuedReminderState: QueuedReminderState.values.firstWhere(
          (value) => value.name == raw['queuedReminderState'],
          orElse: () => QueuedReminderState.none,
        ),
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

  /// Uzantının Siri konuşurken kurduğu geçici alarmı kaldırır.
  ///
  /// Kayıt artık veritabanında olduğu için hatırlatmayı `ReminderService`
  /// devralıyor. Çağrı kaydın oluşmasından **sonra** yapılmalı: aksi hâlde
  /// arada bir hata olursa kullanıcı hem kaydı hem alarmı kaybeder.
  static Future<bool> cancelQueuedReminder(String id) async {
    _ensureInitialized();
    try {
      return await _channel.invokeMethod<bool>('cancelQueuedReminder', {
            'id': id,
          }) ??
          false;
    } on MissingPluginException {
      // Android ve widget testlerinde uzantı alarmı yoktur.
      return true;
    } on PlatformException {
      // Geçici alarm kaldırılmadıysa metadata da silinmemeli. Sonraki
      // foreground turu iptali idempotent biçimde yeniden dener.
      return false;
    }
  }

  /// App Group'taki Free rezervasyonunu artık kotayı taşıyan Drift notuna
  /// devreder. [databaseRemaining] aynı native kilit altında yazılır; aksi
  /// hâlde kısa bir yarışta slot iki kez veya hiç sayılabilirdi.
  static Future<bool> claimFreeReminderReservation(
    String id, {
    required int? databaseRemaining,
  }) async {
    _ensureInitialized();
    try {
      return await _channel.invokeMethod<bool>('claimFreeReminderReservation', {
            'id': id,
            'databaseRemaining': databaseRemaining,
          }) ??
          false;
    } on MissingPluginException {
      // Yalnız iOS uzantı teslimlerinde gerçek rezervasyon vardır.
      return true;
    } on PlatformException {
      // Devir kanıtı yazılmadan metadata temizlenmemeli; sonraki foreground
      // turu aynı import kimliğiyle güvenle yeniden dener.
      return false;
    }
  }

  /// Uzantıların okuduğu ayarları App Group'a aynalar.
  ///
  /// Doğruluk kaynağı yine Drift/mağazadır; ana uygulama payload'ı işlerken
  /// hakkı ve süreyi yeniden kontrol eder. Ayna yalnızca uzantının
  /// **konuşma sırasında** doğru şeyi söyleyebilmesi için var: Pro değilken
  /// hatırlatma sözü vermemek, saklama süresinden sonrasına alarm kurmamak.
  ///
  /// [retentionMinutes] sıfır ise saklama kapalıdır: kayıt kendiliğinden
  /// silinmez ve uzantı hatırlatmayı hiçbir tarihe göre reddetmez.
  static Future<void> setShareMirror({
    required bool proUnlocked,
    required bool reminderEnabled,
    required int retentionMinutes,
    required int? freeRemindersLeft,
  }) async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod<void>('setShareMirror', {
        'unlocked': proUnlocked,
        'reminderEnabled': reminderEnabled,
        'retentionMinutes': retentionMinutes,
        // Uzantı veritabanını açamıyor; ücretsiz hatırlatma hakkını
        // görebilmesinin tek yolu bu ayna. `null` "bilinmiyor" demek ve
        // uzantı o hâlde sade Pro kapısına düşüyor.
        'freeRemindersLeft': freeRemindersLeft,
      });
    } on MissingPluginException {
      // Android ve widget testlerinde iOS App Group'u yoktur.
    } on PlatformException {
      // Extension en kötü ihtimalle hatırlatma seçeneğini reddeder.
    }
  }
}
