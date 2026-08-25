/// Yedeğin yol haritası: içinde ne var, ne kadar yer tutuyor, hangi sırada.
///
/// Şifreli yükün **en başında** duruyor ve bilinçli olarak küçük tutuluyor:
/// geri yükleme önizlemesi ("20 not, 20 fotoğraf bulundu") koca dosyayı
/// çözmeden, yalnızca ilk parçaları açarak cevap verebilsin diye.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Yükün içindeki tek bir bayt bloğu.
final class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.length,
    required this.sha256,
  });

  factory BackupEntry.fromJson(Map<String, Object?> json) => BackupEntry(
    name: json['name']! as String,
    length: (json['len']! as num).toInt(),
    sha256: json['sha256']! as String,
  );

  /// `notes.json` ya da `photos/<dosya adı>`.
  final String name;
  final int length;

  /// Onaltılık SHA-256. Geri yüklerken her giriş tek tek doğrulanıyor.
  ///
  /// AEAD zaten bütünlüğü imzalıyor; bu ikinci kat şifrelemeye karşı değil,
  /// **kendi hatalarımıza** karşı: yanlış uzunluk hesabı ya da kayan bir
  /// akış, doğru çözülmüş ama yanlış bölünmüş baytlar üretebilir.
  final String sha256;

  Map<String, Object?> toJson() => {
    'name': name,
    'len': length,
    'sha256': sha256,
  };
}

/// Bir notun taşınabilir hâli.
///
/// Ham sqlite dosyası taşınmıyor: şema sürümleri arasında kırılgan olurdu ve
/// içine ne gittiğini tam bilemezdik. Alanlar tek tek yazılıyor.
final class BackupNote {
  const BackupNote({
    required this.imageName,
    required this.body,
    required this.createdAt,
    required this.retention,
    required this.customMinutes,
    this.expiresAt,
    this.lastSeenAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.remindAt,
    this.remindEveryDays = 0,
    this.legacyRemindAfterDays = 0,
    this.photoText,
  });

  factory BackupNote.fromJson(Map<String, Object?> json) => BackupNote(
    imageName: json['image']! as String,
    body: (json['body'] as String?) ?? '',
    createdAt: _time(json['created'])!,
    retention: (json['retention'] as num?)?.toInt() ?? 0,
    customMinutes: (json['customMinutes'] as num?)?.toInt() ?? 0,
    expiresAt: _time(json['expires']),
    lastSeenAt: _time(json['lastSeen']),
    updatedAt: _time(json['updated']),
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lon'] as num?)?.toDouble(),
    remindAt: _time(json['remindAt']),
    remindEveryDays: _remindEveryDaysOf(json),
    legacyRemindAfterDays: json['remindAt'] == null
        ? (json['remindDays'] as num?)?.toInt() ?? 0
        : 0,
    photoText: json['photoText'] as String?,
  );

  final String imageName;
  final String body;
  final DateTime createdAt;
  final int retention;
  final int customMinutes;
  final DateTime? expiresAt;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;

  /// Hatırlatmanın mutlak anı. Eski arşivlerde yok: o sürümler yalnızca "kaç
  /// gün sonra" saklıyordu ve o soru cihazdan bağımsız bir an vermiyor.
  final DateTime? remindAt;

  /// Tekrar aralığı (gün); `0` ise tek atış.
  final int remindEveryDays;

  /// Yalnızca [remindAt] taşımayan eski arşivlerden gelir.
  ///
  /// Geri yükleme onu **geri yükleme anından** sayar: yedek dosyası ne zaman
  /// alındığını bilse de o cihazdaki geri sayımın nerede olduğunu bilmiyor,
  /// dolayısıyla dürüst tek başlangıç bu. Yeni arşivler bu alanı hiç yazmaz.
  final int legacyRemindAfterDays;

  /// Karedeki yazının **katlanmış** hâli — arama indeksinin asıl değeri.
  ///
  /// Türetilmiş veri diye dışarıda bırakmak yanlış olurdu: geri yüklenen
  /// cihazda OCR desteklenmiyorsa indeks kalıcı olarak boş kalır ve eskiden
  /// "4521" ile bulunan fiş artık hiç bulunamaz — üstelik sessizce. Yüzlerce
  /// kareyi yeniden taramanın pil maliyeti de cabası.
  ///
  /// `null` = kare hiç okunamamış. Geri yüklemede o kayıtlara yeni cihazda
  /// temiz bir deneme hakkı veriliyor.
  ///
  /// Notun **gövdesinin** katlanmış hâli burada yok; o gövdeden yeniden
  /// hesaplanıyor. Katlama kuralı ileride değişirse eski katlanmış metni geri
  /// yazmak aramayı sessizce bozardı.
  final String? photoText;

  Map<String, Object?> toJson() => {
    'image': imageName,
    if (body.isNotEmpty) 'body': body,
    'created': createdAt.toUtc().millisecondsSinceEpoch,
    'retention': retention,
    if (customMinutes != 0) 'customMinutes': customMinutes,
    if (expiresAt != null) 'expires': expiresAt!.toUtc().millisecondsSinceEpoch,
    if (lastSeenAt != null)
      'lastSeen': lastSeenAt!.toUtc().millisecondsSinceEpoch,
    if (updatedAt != null) 'updated': updatedAt!.toUtc().millisecondsSinceEpoch,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lon': longitude,
    if (remindAt != null) 'remindAt': remindAt!.toUtc().millisecondsSinceEpoch,
    if (remindEveryDays != 0) 'remindEvery': remindEveryDays,
    if (photoText != null) 'photoText': photoText,
  };

  /// Yeni arşivlerde aralık `remindEvery`'de. Eskilerde tek bir gün sayısı ve
  /// bir tekrar bayrağı vardı: tekrar kapalıysa o sayı aralık değil, yalnızca
  /// ilk anı bulmak içindi.
  static int _remindEveryDaysOf(Map<String, Object?> json) {
    final current = (json['remindEvery'] as num?)?.toInt();
    if (current != null) return current;
    if ((json['remindRepeats'] as bool?) != true) return 0;
    return (json['remindDays'] as num?)?.toInt() ?? 0;
  }

  static DateTime? _time(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          (value as num).toInt(),
          isUtc: true,
        ).toLocal();
}

/// Yedeklenen tercihler.
///
/// `proUnlocked` **kasten yok**. Pro hakkı mağazanın bildiği bir şey; dosyaya
/// yazılsaydı yedeği paylaşmak Pro'yu kopyalamanın yolu olurdu.
final class BackupSettings {
  const BackupSettings({
    required this.themeMode,
    required this.accent,
    required this.density,
    required this.reminderEnabled,
    required this.locationEnabled,
    required this.defaultRetention,
    required this.defaultCustomMinutes,
    required this.locale,
  });

  factory BackupSettings.fromJson(Map<String, Object?> json) => BackupSettings(
    themeMode: (json['theme'] as num?)?.toInt() ?? 2,
    accent: (json['accent'] as num?)?.toInt() ?? 0,
    density: (json['density'] as num?)?.toInt() ?? 1,
    reminderEnabled: (json['reminders'] as bool?) ?? false,
    locationEnabled: (json['location'] as bool?) ?? false,
    defaultRetention: (json['retention'] as num?)?.toInt() ?? 0,
    defaultCustomMinutes: (json['customMinutes'] as num?)?.toInt() ?? 0,
    locale: (json['locale'] as num?)?.toInt() ?? 0,
  );

  final int themeMode;
  final int accent;
  final int density;
  final bool reminderEnabled;
  final bool locationEnabled;
  final int defaultRetention;
  final int defaultCustomMinutes;
  final int locale;

  Map<String, Object?> toJson() => {
    'theme': themeMode,
    'accent': accent,
    'density': density,
    'reminders': reminderEnabled,
    'location': locationEnabled,
    'retention': defaultRetention,
    'customMinutes': defaultCustomMinutes,
    'locale': locale,
  };
}

final class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.noteCount,
    required this.photoCount,
    required this.settings,
    required this.entries,
  });

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt']! as num).toInt(),
      isUtc: true,
    ).toLocal(),
    appVersion: (json['app'] as String?) ?? '',
    schemaVersion: (json['schema'] as num?)?.toInt() ?? 0,
    noteCount: (json['notes'] as num?)?.toInt() ?? 0,
    photoCount: (json['photos'] as num?)?.toInt() ?? 0,
    settings: BackupSettings.fromJson(
      (json['settings'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
    entries: [
      for (final entry in (json['entries'] as List? ?? const []))
        BackupEntry.fromJson((entry as Map).cast<String, Object?>()),
    ],
  );

  factory BackupManifest.decode(Uint8List bytes) => BackupManifest.fromJson(
    (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>(),
  );

  final DateTime createdAt;
  final String appVersion;

  /// Yedeği üreten veritabanı şeması. Uygulamanınkinden **büyükse** dosya
  /// reddediliyor: daha yeni bir sürümün yazdığı alanları sessizce düşürmek,
  /// kullanıcının verisini haber vermeden budamak olurdu.
  final int schemaVersion;

  final int noteCount;
  final int photoCount;
  final BackupSettings settings;
  final List<BackupEntry> entries;

  Map<String, Object?> toJson() => {
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
    'app': appVersion,
    'schema': schemaVersion,
    'notes': noteCount,
    'photos': photoCount,
    'settings': settings.toJson(),
    'entries': [for (final entry in entries) entry.toJson()],
  };

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}
