import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App Store / Play Store'un kendi değerlendirme yüzeyine küçük bir adaptör.
/// Testler platform kanalını açmadan davranış politikasını sınayabilsin diye
/// arayüz ayrı tutulur.
abstract interface class ReviewRequester {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

final class SystemReviewRequester implements ReviewRequester {
  const SystemReviewRequester();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Kullanıcıyı rahatsız etmeden native değerlendirme isteğini zamanlar.
///
/// Politika bilinçli biçimde muhafazakâr:
/// * en az üç başarılı yeni kayıt,
/// * ilk kayıt gününden farklı bir gün,
/// * aynı uygulama sürümünde en fazla bir deneme,
/// * sürüm değişse bile denemeler arasında en az 3 gün,
/// * kayıttan sonra arayüzün dinlenmesi için kısa bir bekleme.
///
/// Native API pencerenin gerçekten gösterildiğini, kapatıldığını ya da puan
/// verildiğini açıklamaz. Bu yüzden "gösterildi" değil, **istek denendi**
/// bilgisini tutarız. Durum cihazda kalır ve yedeğe girmez.
final class ReviewPromptService {
  ReviewPromptService({
    this.requester = const SystemReviewRequester(),
    Future<File> Function()? stateFile,
    Future<String> Function()? appVersion,
    DateTime Function()? now,
    Future<void> Function(Duration)? pause,
    bool Function()? isForeground,
  }) : _stateFile = stateFile ?? _defaultStateFile,
       _appVersion = appVersion ?? _defaultAppVersion,
       _now = now ?? DateTime.now,
       _pause = pause ?? Future<void>.delayed,
       _isForeground = isForeground ?? _defaultIsForeground;

  static const minimumSuccessfulSaves = 3;
  static const cooldown = Duration(days: 3);
  static const settleDelay = Duration(milliseconds: 2400);
  static const _stateVersion = 1;

  final ReviewRequester requester;
  final Future<File> Function() _stateFile;
  final Future<String> Function() _appVersion;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _pause;
  final bool Function() _isForeground;

  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  /// Yalnızca veritabanına başarıyla giren **yeni** nottan sonra çağrılır.
  /// Düzenleme, restore ve başarısız kayıtlar etkileşim sayılmaz.
  Future<void> recordSuccessfulSave() {
    _queue = _queue.then((_) => _recordSafely());
    return _queue;
  }

  void dispose() => _disposed = true;

  Future<void> _recordSafely() async {
    if (_disposed) return;
    try {
      final file = await _stateFile();
      final state = await _read(file);
      final now = _now();
      final updated = state.copyWith(
        successfulSaves: state.successfulSaves + 1,
        firstSuccessfulSaveAt: state.firstSuccessfulSaveAt ?? now,
      );
      await _write(file, updated);

      if (!_hasEnoughExperience(updated, now)) return;

      // Apple'ın örnek akışındaki gibi, tamamlanma ekranının yerleşmesine ve
      // kullanıcının bir sonraki işe geçip geçmediğinin belli olmasına izin
      // ver. Uygulama arka plana gittiyse bu doğal an kaçmıştır; sonraki
      // başarılı kayıtta yeniden değerlendirilir, açılışta pusu kurulmaz.
      await _pause(settleDelay);
      if (_disposed || !_isForeground()) return;

      final version = await _appVersion();
      if (!_canAttempt(updated, now: _now(), version: version)) return;
      if (!await requester.isAvailable()) return;

      // Platform sonucu "kullanıcı puan verdi" anlamına gelmez ve bunu
      // öğrenmenin bir API'si yoktur. İsteği göndermeden hemen önce işaretle;
      // böylece kapatılan pencere aynı sürümde tekrar kovalanmaz.
      final attemptedAt = _now();
      await _write(
        file,
        updated.copyWith(
          lastAttemptAt: attemptedAt,
          lastAttemptVersion: version,
        ),
      );
      await requester.requestReview();
    } catch (error, stackTrace) {
      // Puan istemek uygulamanın asıl işi değil; mağaza servisi bulunamazsa
      // not kaydı asla bundan etkilenmez.
      debugPrint('Review prompt hazırlanamadı: $error\n$stackTrace');
    }
  }

  bool _hasEnoughExperience(_ReviewState state, DateTime now) {
    final first = state.firstSuccessfulSaveAt;
    if (state.successfulSaves < minimumSuccessfulSaves || first == null) {
      return false;
    }
    return _day(now).isAfter(_day(first));
  }

  bool _canAttempt(
    _ReviewState state, {
    required DateTime now,
    required String version,
  }) {
    if (state.lastAttemptVersion == version) return false;
    final previous = state.lastAttemptAt;
    if (previous == null) return true;
    final elapsed = now.difference(previous);
    return !elapsed.isNegative && elapsed >= cooldown;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _defaultIsForeground() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  static Future<String> _defaultAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<File> _defaultStateFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'review_prompt.json'));
  }

  static Future<_ReviewState> _read(File file) async {
    if (!file.existsSync()) return const _ReviewState();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != _stateVersion) {
        return const _ReviewState();
      }
      return _ReviewState.fromJson(decoded);
    } on FormatException {
      return const _ReviewState();
    } on FileSystemException {
      return const _ReviewState();
    }
  }

  static Future<void> _write(File file, _ReviewState state) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}

final class _ReviewState {
  const _ReviewState({
    this.successfulSaves = 0,
    this.firstSuccessfulSaveAt,
    this.lastAttemptAt,
    this.lastAttemptVersion,
  });

  factory _ReviewState.fromJson(Map<String, Object?> json) {
    DateTime? date(String key) {
      final value = json[key];
      return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
    }

    final saves = json['successfulSaves'];
    final version = json['lastAttemptVersion'];
    return _ReviewState(
      successfulSaves: saves is int && saves >= 0 ? saves : 0,
      firstSuccessfulSaveAt: date('firstSuccessfulSaveAt'),
      lastAttemptAt: date('lastAttemptAt'),
      lastAttemptVersion: version is String && version.isNotEmpty
          ? version
          : null,
    );
  }

  final int successfulSaves;
  final DateTime? firstSuccessfulSaveAt;
  final DateTime? lastAttemptAt;
  final String? lastAttemptVersion;

  _ReviewState copyWith({
    int? successfulSaves,
    DateTime? firstSuccessfulSaveAt,
    DateTime? lastAttemptAt,
    String? lastAttemptVersion,
  }) {
    return _ReviewState(
      successfulSaves: successfulSaves ?? this.successfulSaves,
      firstSuccessfulSaveAt:
          firstSuccessfulSaveAt ?? this.firstSuccessfulSaveAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastAttemptVersion: lastAttemptVersion ?? this.lastAttemptVersion,
    );
  }

  Map<String, Object?> toJson() => {
    'version': ReviewPromptService._stateVersion,
    'successfulSaves': successfulSaves,
    'firstSuccessfulSaveAt': firstSuccessfulSaveAt?.millisecondsSinceEpoch,
    'lastAttemptAt': lastAttemptAt?.millisecondsSinceEpoch,
    'lastAttemptVersion': lastAttemptVersion,
  };
}
