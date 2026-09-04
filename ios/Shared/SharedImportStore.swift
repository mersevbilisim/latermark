import Foundation
import UserNotifications

/// Share Extension ile Runner'ın App Group üzerinden paylaştığı dayanıklı
/// gelen kutusu. JSON en son yazılır; böylece yarım kalan görsel kopyaları
/// hiçbir zaman Flutter'a tamamlanmış bir öğe gibi görünmez.
enum SharedImportStore {
  private static let appGroup = "group.com.mersev.latermark"
  private static let folderName = "shared_imports"
  private static let proUnlockedKey = "share.pro_unlocked"
  private static let defaultRetentionMinutesKey =
    "share.default_retention_minutes"
  private static let reminderEnabledKey = "share.reminder_enabled"

  /// Ucretsiz katmanda kalan hatirlatma hakki.
  ///
  /// Uzanti veritabanini acamiyor; kotayi gorebilmesinin tek yolu bu ayna.
  /// Deger **tavsiye niteliginde**: son soz uygulamanin deposunun, uzanti
  /// yalniz Siri'nin dogru cumleyi kurabilmesi icin okuyor.
  private static let freeRemindersLeftKey = "share.free_reminders_left"
  private static let orphanGrace: TimeInterval = 24 * 60 * 60

  private enum ImportKind: String, Codable {
    case photo
    case text
  }

  private struct Metadata: Codable, Equatable {
    let id: String
    let kind: ImportKind
    let imageName: String
    let initialText: String
    let createdAtMilliseconds: Int64
    let saveImmediately: Bool
    let remindAfterDays: Int?
    let remindAtMilliseconds: Int64?

    private enum CodingKeys: String, CodingKey {
      case id
      case kind
      case imageName
      case initialText
      case createdAtMilliseconds
      case saveImmediately
      case remindAfterDays
      case remindAtMilliseconds
    }

    init(
      id: String,
      kind: ImportKind,
      imageName: String,
      initialText: String,
      createdAtMilliseconds: Int64,
      saveImmediately: Bool,
      remindAfterDays: Int?,
      remindAtMilliseconds: Int64?
    ) {
      self.id = id
      self.kind = kind
      self.imageName = imageName
      self.initialText = initialText
      self.createdAtMilliseconds = createdAtMilliseconds
      self.saveImmediately = saveImmediately
      self.remindAfterDays = remindAfterDays
      self.remindAtMilliseconds = remindAtMilliseconds
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      id = try values.decode(String.self, forKey: .id)
      // `kind` alanından önce yazılmış bütün teslimler fotoğraftır.
      kind = try values.decodeIfPresent(ImportKind.self, forKey: .kind)
        ?? .photo
      imageName = try values.decode(String.self, forKey: .imageName)
      initialText = try values.decode(String.self, forKey: .initialText)
      createdAtMilliseconds = try values.decode(
        Int64.self,
        forKey: .createdAtMilliseconds
      )
      saveImmediately = try values.decode(
        Bool.self,
        forKey: .saveImmediately
      )
      remindAfterDays = try values.decodeIfPresent(
        Int.self,
        forKey: .remindAfterDays
      )
      remindAtMilliseconds = try values.decodeIfPresent(
        Int64.self,
        forKey: .remindAtMilliseconds
      )
    }
  }

  enum StoreError: LocalizedError {
    case invalidIdentifier
    case conflictingImport(String)

    var errorDescription: String? {
      switch self {
      case .invalidIdentifier:
        return "The shared import identifier is not a UUID."
      case let .conflictingImport(id):
        return "A different shared import already exists for \(id)."
      }
    }
  }

  static var proUnlocked: Bool {
    UserDefaults(suiteName: appGroup)?.bool(forKey: proUnlockedKey) ?? false
  }

  /// `nil`, ana uygulamanın değeri henüz App Group'a aynalamadığı anlamına
  /// gelir. Sıfır ise geçerli ve farklı bir değerdir: varsayılan saklama
  /// süresi kapalıdır (kayıt kendiliğinden silinmez).
  static var defaultRetentionMinutes: Int? {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      defaults.object(forKey: defaultRetentionMinutesKey) != nil
    else {
      return nil
    }
    return defaults.integer(forKey: defaultRetentionMinutesKey)
  }

  /// Kullanıcının hatırlatmaları tümden kapatıp kapatmadığı.
  ///
  /// Ana uygulama bu tercih kapalıyken **bekleyen bütün bildirimleri
  /// siliyor** (`ReminderService.sync` → `cancelAll`). Uzantı bunu bilmeden
  /// alarm kurarsa, kullanıcının uygulamayı bir sonraki açışında alarm
  /// sessizce kaybolurdu. Ayna henüz yazılmamışsa `nil`.
  static var reminderEnabled: Bool? {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      defaults.object(forKey: reminderEnabledKey) != nil
    else {
      return nil
    }
    return defaults.bool(forKey: reminderEnabledKey)
  }

  /// Ucretsiz katmanda kalan hatirlatma hakki.
  ///
  /// Anahtar hic yoksa `nil`: "deger bilinmiyor" ile "hak kalmadi" ayri
  /// seyler. Bilinmiyorsa uzanti eski davranisina, yani Pro kapisina duser.
  static var freeRemindersLeft: Int? {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      defaults.object(forKey: freeRemindersLeftKey) != nil
    else {
      return nil
    }
    return defaults.integer(forKey: freeRemindersLeftKey)
  }

  /// Hakki yerel aynada bir dusurur.
  ///
  /// Uygulama acilmadan art arda soylenen istekler icin gerekli: ayna ancak
  /// uygulama onе geldiginde tazeleniyor, o zamana kadar sayiyi uzantinin
  /// kendisi tutuyor. Uygulama bir sonraki yayinda gercek degeri yaziyor.
  static func consumeFreeReminder() {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      defaults.object(forKey: freeRemindersLeftKey) != nil
    else {
      return
    }
    let left = defaults.integer(forKey: freeRemindersLeftKey)
    defaults.set(max(0, left - 1), forKey: freeRemindersLeftKey)
  }

  static func setProUnlocked(_ value: Bool) {
    UserDefaults(suiteName: appGroup)?.set(value, forKey: proUnlockedKey)
  }

  /// Uzantıların okuduğu bütün ayarları tek turda aynalar.
  ///
  /// `retentionMinutes` `nil` ise anahtar silinir: "değer yok" ile "sıfır
  /// dakika" (süresiz sakla) birbirinden ayrı kalmalı.
  static func mirrorSettings(
    proUnlocked: Bool,
    reminderEnabled: Bool,
    retentionMinutes: Int?,
    freeRemindersLeft: Int?
  ) {
    guard let defaults = UserDefaults(suiteName: appGroup) else { return }
    defaults.set(proUnlocked, forKey: proUnlockedKey)
    defaults.set(reminderEnabled, forKey: reminderEnabledKey)
    if let freeRemindersLeft {
      defaults.set(max(0, freeRemindersLeft), forKey: freeRemindersLeftKey)
    } else {
      defaults.removeObject(forKey: freeRemindersLeftKey)
    }
    if let retentionMinutes {
      defaults.set(retentionMinutes, forKey: defaultRetentionMinutesKey)
    } else {
      defaults.removeObject(forKey: defaultRetentionMinutesKey)
    }
  }

  static func enqueue(
    imageAt source: URL,
    initialText: String,
    saveImmediately: Bool,
    remindAfterDays: Int = 0
  ) throws {
    let directory = try inboxDirectory()
    let id = UUID().uuidString.lowercased()
    let sourceExtension = source.pathExtension.isEmpty
      ? "jpg"
      : source.pathExtension.lowercased()
    let safeExtension = sourceExtension.unicodeScalars.allSatisfy {
      CharacterSet.alphanumerics.contains($0)
    } ? sourceExtension : "jpg"
    let imageName = "\(id).\(safeExtension)"
    let image = directory.appendingPathComponent(imageName)
    let metadata = directory.appendingPathComponent("\(id).json")

    do {
      try FileManager.default.copyItem(at: source, to: image)
      try writeMetadata(
        Metadata(
          id: id,
          kind: .photo,
          imageName: imageName,
          initialText: initialText,
          createdAtMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
          saveImmediately: saveImmediately,
          remindAfterDays: max(0, min(remindAfterDays, 365)),
          remindAtMilliseconds: nil
        ),
        to: metadata
      )
    } catch {
      try? FileManager.default.removeItem(at: image)
      try? FileManager.default.removeItem(at: metadata)
      throw error
    }
  }

  static func enqueue(
    imageData: Data,
    fileExtension: String,
    initialText: String,
    saveImmediately: Bool,
    remindAfterDays: Int = 0
  ) throws {
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
    try imageData.write(to: temporary, options: .atomic)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try enqueue(
      imageAt: temporary,
      initialText: initialText,
      saveImmediately: saveImmediately,
      remindAfterDays: remindAfterDays
    )
  }

  /// App Intent gibi görselsiz üreticiler için dayanıklı teslim.
  ///
  /// Kimlik ve zaman parametreleri normal kullanımda otomatik üretilir;
  /// testler veya yeniden denenen bir intent aynı değerleri geçirerek teslimi
  /// idempotent yapabilir. Aynı kimlikte birebir aynı metadata zaten varsa bu
  /// çağrı başarı sayılır. Farklı bir payload hiçbir zaman ezilmez.
  @discardableResult
  static func enqueue(
    text: String,
    saveImmediately: Bool = true,
    remindAtMilliseconds: Int64? = nil,
    id: String = UUID().uuidString.lowercased(),
    createdAtMilliseconds: Int64 = Int64(
      Date().timeIntervalSince1970 * 1_000
    )
  ) throws -> String {
    guard let normalizedID = normalizedIdentifier(id) else {
      throw StoreError.invalidIdentifier
    }

    let directory = try inboxDirectory()
    let metadataURL = directory.appendingPathComponent("\(normalizedID).json")
    let metadata = Metadata(
      id: normalizedID,
      kind: .text,
      imageName: "",
      initialText: text,
      createdAtMilliseconds: createdAtMilliseconds,
      saveImmediately: saveImmediately,
      remindAfterDays: nil,
      remindAtMilliseconds: remindAtMilliseconds
    )

    do {
      try writeMetadataWithoutOverwriting(metadata, to: metadataURL)
    } catch {
      // Başka bir süreç aynı kimliği arada yazmış olabilir. Birebir aynı
      // teslim güvenli bir yeniden denemedir; farklı veri çakışmadır.
      if metadataAt(metadataURL) == metadata { return normalizedID }
      if FileManager.default.fileExists(atPath: metadataURL.path) {
        throw StoreError.conflictingImport(normalizedID)
      }
      throw error
    }
    return normalizedID
  }

  /// App Intents tarafının doğal `Date` değerini sözleşmedeki mutlak Unix
  /// milisaniyesine dönüştüren kolaylık katmanı.
  @discardableResult
  static func enqueue(text: String, remindAt: Date?) throws -> String {
    try enqueue(
      text: text,
      remindAtMilliseconds: remindAt.map {
        Int64($0.timeIntervalSince1970 * 1_000)
      }
    )
  }

  static func nextPending() -> [String: Any]? {
    guard let directory = try? inboxDirectory() else { return nil }
    let keys: Set<URLResourceKey> = [.contentModificationDateKey]
    let metadataFiles = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: [.skipsHiddenFiles]
    ))?.filter { $0.pathExtension == "json" }.sorted {
      let lhs = try? $0.resourceValues(forKeys: keys).contentModificationDate
      let rhs = try? $1.resourceValues(forKeys: keys).contentModificationDate
      return (lhs ?? .distantPast) < (rhs ?? .distantPast)
    } ?? []

    pruneOrphanPayloads(in: directory, metadataFiles: metadataFiles)

    for metadataURL in metadataFiles {
      guard let metadata = metadataAt(metadataURL),
        let normalizedID = normalizedIdentifier(metadata.id),
        normalizedID == metadataURL.deletingPathExtension().lastPathComponent
      else {
        removePayloadFiles(
          id: metadataURL.deletingPathExtension().lastPathComponent,
          in: directory
        )
        try? FileManager.default.removeItem(at: metadataURL)
        continue
      }

      let path: String
      switch metadata.kind {
      case .photo:
        let imageURL = directory.appendingPathComponent(metadata.imageName)
        guard
          !metadata.imageName.isEmpty,
          imageURL.deletingLastPathComponent().standardizedFileURL
            == directory.standardizedFileURL,
          FileManager.default.fileExists(atPath: imageURL.path)
        else {
          try? FileManager.default.removeItem(at: metadataURL)
          continue
        }
        path = imageURL.path
      case .text:
        // Metin tesliminin görsel payload'ı yoktur. Boş olmayan ad, bozuk ya
        // da gelecekteki ve bu sürümün yorumlayamayacağı bir sözleşmedir.
        guard metadata.imageName.isEmpty else {
          try? FileManager.default.removeItem(at: metadataURL)
          continue
        }
        path = ""
      }

      var pending: [String: Any] = [
        "id": metadata.id,
        "kind": metadata.kind.rawValue,
        "imageName": metadata.imageName,
        "path": path,
        "initialText": metadata.initialText,
        "createdAtMilliseconds": metadata.createdAtMilliseconds,
        "saveImmediately": metadata.saveImmediately,
        "remindAfterDays": metadata.remindAfterDays ?? 0,
      ]
      pending["remindAtMilliseconds"] = metadata.remindAtMilliseconds
        .map { NSNumber(value: $0) } ?? NSNull()
      return pending
    }
    return nil
  }

  @discardableResult
  static func complete(id: String) -> Bool {
    guard
      let normalizedID = normalizedIdentifier(id),
      let directory = try? inboxDirectory()
    else { return false }

    let metadataURL = directory.appendingPathComponent("\(normalizedID).json")
    if let metadata = metadataAt(metadataURL), metadata.kind == .photo {
      let imageURL = directory.appendingPathComponent(metadata.imageName)
      if !metadata.imageName.isEmpty,
        imageURL.deletingLastPathComponent().standardizedFileURL
          == directory.standardizedFileURL
      {
        do {
          if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
          }
        } catch {
          return false
        }
      }
    }
    do {
      if FileManager.default.fileExists(atPath: metadataURL.path) {
        try FileManager.default.removeItem(at: metadataURL)
      }
      // Metadata okunamadıysa bile UUID ile başlayan görseli temizle.
      removePayloadFiles(id: normalizedID, in: directory)
      return true
    } catch {
      return false
    }
  }

  private static func removePayloadFiles(id: String, in directory: URL) {
    guard let normalizedID = normalizedIdentifier(id) else { return }
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )) ?? []
    for url in urls where
      url.deletingPathExtension().lastPathComponent.lowercased()
        == normalizedID &&
      url.pathExtension != "json"
    {
      try? FileManager.default.removeItem(at: url)
    }
  }

  /// Payload yazılıp süreç JSON yazılmadan kapanırsa geride kalan dosyayı
  /// toplar. Geçerli görseller kullanıcı uygulamayı ne zaman açarsa açsın
  /// korunur; yalnız hiçbir metadata'nın sahiplenmediği ve bir günden eski
  /// payload/hazırlık dosyaları silinir.
  private static func pruneOrphanPayloads(
    in directory: URL,
    metadataFiles: [URL]
  ) {
    let referenced = Set(metadataFiles.compactMap { url -> String? in
      guard let metadata = metadataAt(url), metadata.kind == .photo,
        !metadata.imageName.isEmpty
      else { return nil }
      return metadata.imageName
    })
    let keys: Set<URLResourceKey> = [.contentModificationDateKey]
    let cutoff = Date().addingTimeInterval(-orphanGrace)
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: [.skipsHiddenFiles]
    )) ?? []
    for url in urls where url.pathExtension != "json" {
      if referenced.contains(url.lastPathComponent) { continue }
      let modified = try? url.resourceValues(
        forKeys: keys
      ).contentModificationDate
      if let modified, modified > cutoff { continue }
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static func inboxDirectory() throws -> URL {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else {
      throw CocoaError(.fileNoSuchFile)
    }
    let directory = container.appendingPathComponent(
      folderName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private static func writeMetadata(_ value: Metadata, to url: URL) throws {
    let data = try JSONEncoder().encode(value)
    try data.write(to: url, options: [.atomic, .completeFileProtection])
  }

  private static func writeMetadataWithoutOverwriting(
    _ value: Metadata,
    to url: URL
  ) throws {
    let data = try JSONEncoder().encode(value)
    let stagingURL = url.deletingLastPathComponent().appendingPathComponent(
      "\(url.lastPathComponent).\(UUID().uuidString).pending"
    )
    defer { try? FileManager.default.removeItem(at: stagingURL) }

    // `Data.WritingOptions.atomic` ve `.withoutOverwriting` Foundation'da
    // birlikte desteklenmiyor. Hazır veriye aynı dosya sisteminde hard-link
    // açmak hem hedefi tek adımda görünür yapar hem de hedef zaten varsa onu
    // asla ezmez. Kaybeden eşzamanlı yazar aşağıdaki çağrıdan hata alır.
    try data.write(
      to: stagingURL,
      options: [.atomic, .completeFileProtection]
    )
    try FileManager.default.linkItem(at: stagingURL, to: url)
  }

  private static func metadataAt(_ url: URL) -> Metadata? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Metadata.self, from: data)
  }

  private static func normalizedIdentifier(_ id: String) -> String? {
    UUID(uuidString: id)?.uuidString.lowercased()
  }
}

/// Gelen kutusundaki bir teslimin **alarmı**.
///
/// Kaydın kendisi Runner açılana kadar bekliyor ve bu teknik bir zorunluluk:
/// veritabanı Flutter motorunun içinde yaşıyor, Pro kapısı ve saklama süresi
/// hesabı Dart tarafında. Uzantıdan oraya yazmak sqlite kilidini kırar.
///
/// Alarm ise bekleyemez. "Akşam 6'da hatırlat" diyen biri uygulamayı hiç
/// açmayabilir; bildirim o zaman hiç çalmazsa Siri yolu tümden işe yaramaz.
/// Bu yüzden bildirimi uzantı kendisi kuruyor: `UNUserNotificationCenter`
/// uzantıda da ana uygulamanın merkezini döndürür, teslim ana uygulama adına
/// yapılır.
///
/// Runner açıldığında kayıt gerçekten oluşuyor ve `ReminderService` alarmı
/// kendi kimlik şemasıyla yeniden kuruyor; buradaki geçici istek o anda
/// [cancel] ile kaldırılıyor. İkisi bir arada asla çalmaz.
enum QueuedReminder {
  /// Bildirim başlığı. `ReminderService._title` ile aynı sabit metin.
  private static let title = "Latermark Pro"
  private static let soundName = "notification.wav"

  /// `flutter_local_notifications` bekleyen isteklerini tamsayı kimlikle
  /// adresliyor. Harfle başlayan bir kimlik onun şemasıyla çakışmaz ve
  /// payload'ı `note/<id>` kalıbına uymadığı için senkron döngüsü de bu
  /// isteği atlar.
  static func identifier(for importId: String) -> String {
    "latermark.queued.\(importId)"
  }

  /// Ana uygulamanın bildirim izni.
  ///
  /// İzin uzantıdan **istenemez**; yalnız okunur. Kullanıcı izni hiç
  /// vermediyse alarm sözü verilmemeli.
  static func authorized() async -> Bool {
    let settings = await UNUserNotificationCenter.current()
      .notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return true
    default:
      return false
    }
  }

  static func schedule(
    importId: String,
    body: String,
    at date: Date
  ) async throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound(
      named: UNNotificationSoundName(soundName)
    )
    // Ana uygulamanın eylem düğmeleri (`latermark.reminder.once`) bilerek
    // takılmıyor: o düğmeler payload'daki not kimliğiyle çalışıyor ve kayıt
    // henüz oluşmadı. Dokunma uygulamayı açar, açılış zaten kaydı üretir.
    content.userInfo = ["payload": "import/\(importId)"]

    // Takvim tetikleyicisi, ana uygulamanın `zonedSchedule` davranışıyla aynı:
    // an, yerel duvar saatine göre çözülür.
    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: date
    )
    let request = UNNotificationRequest(
      identifier: identifier(for: importId),
      content: content,
      trigger: UNCalendarNotificationTrigger(
        dateMatching: components,
        repeats: false
      )
    )
    try await UNUserNotificationCenter.current().add(request)
  }

  /// Yalnız bekleyen isteği kaldırır.
  ///
  /// Teslim edilmiş satır tepside kalır: kullanıcı henüz okumamış olabilir ve
  /// alarm görevini zaten yapmıştır.
  static func cancel(importId: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [identifier(for: importId)]
    )
  }
}
