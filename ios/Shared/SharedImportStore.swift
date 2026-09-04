import Foundation
import Darwin
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
  private static let coordinationLockName = ".coordination.lock"

  private enum ImportKind: String, Codable {
    case photo
    case text
  }

  /// Uzantı hatırlatmasının native → Runner devrindeki dayanıklı durumu.
  ///
  /// Alan 1.0.3 metadata'sında yoktur; decoder aşağıda güvenli varsayıma
  /// düşer. Rezervasyonun Drift'e devri ayrı bir bayraktır; alarmın gerçekten
  /// kurulmuş olduğu bilgisi hiçbir geçişte kaybedilmez.
  private enum QueuedReminderState: String, Codable {
    case none
    case reserved
    case scheduled
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
    let freeReminderReserved: Bool
    var freeReminderClaimed: Bool
    var queuedReminderState: QueuedReminderState

    private enum CodingKeys: String, CodingKey {
      case id
      case kind
      case imageName
      case initialText
      case createdAtMilliseconds
      case saveImmediately
      case remindAfterDays
      case remindAtMilliseconds
      case freeReminderReserved
      case freeReminderClaimed
      case queuedReminderState
    }

    init(
      id: String,
      kind: ImportKind,
      imageName: String,
      initialText: String,
      createdAtMilliseconds: Int64,
      saveImmediately: Bool,
      remindAfterDays: Int?,
      remindAtMilliseconds: Int64?,
      freeReminderReserved: Bool = false,
      freeReminderClaimed: Bool = false,
      queuedReminderState: QueuedReminderState = .none
    ) {
      self.id = id
      self.kind = kind
      self.imageName = imageName
      self.initialText = initialText
      self.createdAtMilliseconds = createdAtMilliseconds
      self.saveImmediately = saveImmediately
      self.remindAfterDays = remindAfterDays
      self.remindAtMilliseconds = remindAtMilliseconds
      self.freeReminderReserved = freeReminderReserved
      self.freeReminderClaimed = freeReminderClaimed
      self.queuedReminderState = queuedReminderState
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
      // 1.0.3'ten kalan teslimler ücretli katmanda üretildi. Onları sonradan
      // Free hakkı gibi saymak sessiz bir hak kaybı olurdu.
      freeReminderReserved = try values.decodeIfPresent(
        Bool.self,
        forKey: .freeReminderReserved
      ) ?? false
      freeReminderClaimed = try values.decodeIfPresent(
        Bool.self,
        forKey: .freeReminderClaimed
      ) ?? false
      queuedReminderState = try values.decodeIfPresent(
        QueuedReminderState.self,
        forKey: .queuedReminderState
      ) ?? (remindAtMilliseconds == nil ? .none : .scheduled)
    }
  }

  enum StoreError: LocalizedError {
    case invalidIdentifier
    case conflictingImport(String)
    case noFreeReminders
    case coordinationUnavailable

    var errorDescription: String? {
      switch self {
      case .invalidIdentifier:
        return "The shared import identifier is not a UUID."
      case let .conflictingImport(id):
        return "A different shared import already exists for \(id)."
      case .noFreeReminders:
        return "No free reminder reservation is available."
      case .coordinationUnavailable:
        return "The shared import store could not be locked."
      }
    }
  }

  struct ReminderEnqueueResult {
    let id: String
    let proUnlocked: Bool
  }

  struct ReminderAvailability {
    let proUnlocked: Bool
    let freeRemindersLeft: Int?

    var allowsReminder: Bool {
      proUnlocked || (freeRemindersLeft ?? 0) > 0
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
    try? withInboxLock { directory in
      freeRemindersLeft(in: directory)
    }
  }

  /// Katman ile kalan slot aynı App Group karesinden okunur. Runner bu iki
  /// değeri tek kilitte aynaladığı için uzantı bir satın alma/iade geçişinin
  /// yarısını görmez.
  static var reminderAvailability: ReminderAvailability {
    (try? withInboxLock { directory in
      ReminderAvailability(
        proUnlocked: proUnlocked,
        freeRemindersLeft: freeRemindersLeft(in: directory)
      )
    }) ?? ReminderAvailability(proUnlocked: false, freeRemindersLeft: nil)
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
    try? withInboxLock { _ in
      guard let defaults = UserDefaults(suiteName: appGroup) else { return }
      defaults.set(proUnlocked, forKey: proUnlockedKey)
      defaults.set(reminderEnabled, forKey: reminderEnabledKey)
      if let freeRemindersLeft {
        // Bu, yalnız Drift'in bildiği kullanılabilir sayıdır. Henüz Drift'e
        // geçmemiş uzantı rezervasyonları getter'da ayrıca çıkarılır; böylece
        // Runner'ın ayna tazelemesi uzantının aldığı slotları geri açamaz.
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
  }

  static func enqueue(
    imageAt source: URL,
    initialText: String,
    saveImmediately: Bool,
    remindAfterDays: Int = 0
  ) throws {
    let directory = try inboxDirectory()
    let id = UUID().uuidString.lowercased()
    let reminderDays = max(0, min(remindAfterDays, 365))
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
      try withInboxLock { lockedDirectory in
        let currentProUnlocked = proUnlocked
        if reminderDays > 0 && !currentProUnlocked {
          guard
            let remaining = freeRemindersLeft(in: lockedDirectory),
            remaining > 0
          else { throw StoreError.noFreeReminders }
        }
        try writeMetadata(
          Metadata(
            id: id,
            kind: .photo,
            imageName: imageName,
            initialText: initialText,
            createdAtMilliseconds: Int64(
              Date().timeIntervalSince1970 * 1_000
            ),
            saveImmediately: saveImmediately,
            remindAfterDays: reminderDays,
            remindAtMilliseconds: nil,
            freeReminderReserved: reminderDays > 0 && !currentProUnlocked
          ),
          to: metadata
        )
      }
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

    return try withInboxLock { directory in
      try writeTextMetadata(metadata, in: directory)
    }
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

  /// Siri hatırlatmasını ve gerekiyorsa Free slotunu tek kilit altında alır.
  ///
  /// Önce ayrı bir sayaç okuyup sonra metadata yazmak iki eşzamanlı intent'in
  /// son slotu birlikte almasına izin verirdi. Rezervasyon metadata'nın
  /// kendisidir; Runner aynayı tazelese bile teslim tamamlanana kadar kaybolmaz.
  @discardableResult
  static func enqueueReminder(
    text: String,
    remindAt: Date,
    id: String = UUID().uuidString.lowercased(),
    createdAtMilliseconds: Int64 = Int64(
      Date().timeIntervalSince1970 * 1_000
    )
  ) throws -> ReminderEnqueueResult {
    guard let normalizedID = normalizedIdentifier(id) else {
      throw StoreError.invalidIdentifier
    }

    return try withInboxLock { directory in
      let url = directory.appendingPathComponent("\(normalizedID).json")
      let reminderMilliseconds = Int64(
        remindAt.timeIntervalSince1970 * 1_000
      )
      if let existing = metadataAt(url) {
        guard
          existing.id == normalizedID,
          existing.kind == .text,
          existing.imageName.isEmpty,
          existing.initialText == text,
          existing.createdAtMilliseconds == createdAtMilliseconds,
          existing.saveImmediately,
          existing.remindAfterDays == nil,
          existing.remindAtMilliseconds == reminderMilliseconds
        else {
          throw StoreError.conflictingImport(normalizedID)
        }
        // Alarm durumu veya Runner claim'i ilerlemiş olabilir; aynı intent'in
        // yeniden denenmesi bu monoton alanları ve ilk alınan katmanı geriye
        // çevirmemeli.
        return ReminderEnqueueResult(
          id: normalizedID,
          proUnlocked: !existing.freeReminderReserved
        )
      }

      // Katman da kota da aynı kilidin içinden okunur. Satın alma veya hak
      // geri alma tam bu anda aynalanırsa teslim ya bütünüyle Pro ya da
      // bütünüyle Free olur; metadata ile alarm başlığı farklı katmanları
      // temsil etmez.
      let currentProUnlocked = proUnlocked
      if !currentProUnlocked {
        guard let remaining = freeRemindersLeft(in: directory), remaining > 0
        else { throw StoreError.noFreeReminders }
      }

      let metadata = Metadata(
        id: normalizedID,
        kind: .text,
        imageName: "",
        initialText: text,
        createdAtMilliseconds: createdAtMilliseconds,
        saveImmediately: true,
        remindAfterDays: nil,
        remindAtMilliseconds: reminderMilliseconds,
        freeReminderReserved: !currentProUnlocked,
        queuedReminderState: .reserved
      )
      _ = try writeTextMetadata(metadata, in: directory)
      return ReminderEnqueueResult(
        id: normalizedID,
        proUnlocked: currentProUnlocked
      )
    }
  }

  /// `UNUserNotificationCenter.add` başarıyla döndükten sonra kanıtı kalıcı
  /// yapar. Yazma başarısızsa çağıran native alarmı geri kaldırır; izsiz alarm
  /// hiçbir zaman kullanıcı kotasını aşamaz.
  @discardableResult
  static func markQueuedReminderScheduled(id: String) -> Bool {
    guard let normalizedID = normalizedIdentifier(id) else { return false }
    return (try? withInboxLock { directory in
      let url = directory.appendingPathComponent("\(normalizedID).json")
      guard var metadata = metadataAt(url), metadata.id == normalizedID else {
        return false
      }
      metadata.queuedReminderState = .scheduled
      try writeMetadata(metadata, to: url)
      return true
    }) ?? false
  }

  /// Rezervasyonu Drift'teki nota devreder ve aynı kritik bölgede yeni DB
  /// aynasını yazar. İki işlem ayrılırsa kısa bir pencerede slot hem metadata
  /// hem not tarafından sayılabilir veya hiç sayılmayabilir.
  @discardableResult
  static func claimFreeReminderReservation(
    id: String,
    databaseRemaining: Int?
  ) -> Bool {
    guard let normalizedID = normalizedIdentifier(id) else { return false }
    return (try? withInboxLock { directory in
      let url = directory.appendingPathComponent("\(normalizedID).json")
      guard var metadata = metadataAt(url), metadata.id == normalizedID else {
        // Temizlik daha önce tamamlandıysa idempotent başarıdır.
        return !FileManager.default.fileExists(atPath: url.path)
      }
      if metadata.freeReminderReserved {
        metadata.freeReminderClaimed = true
        try writeMetadata(metadata, to: url)
      }
      if let databaseRemaining,
        let defaults = UserDefaults(suiteName: appGroup)
      {
        defaults.set(max(0, databaseRemaining), forKey: freeRemindersLeftKey)
      }
      return true
    }) ?? false
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
      pending["freeReminderReserved"] = metadata.freeReminderReserved
      pending["freeReminderClaimed"] = metadata.freeReminderClaimed
      pending["queuedReminderState"] = metadata.queuedReminderState.rawValue
      return pending
    }
    return nil
  }

  @discardableResult
  static func complete(id: String) -> Bool {
    guard let normalizedID = normalizedIdentifier(id) else { return false }
    return (try? withInboxLock { directory in
      let metadataURL = directory.appendingPathComponent("\(normalizedID).json")
      if let metadata = metadataAt(metadataURL), metadata.kind == .photo {
        let imageURL = directory.appendingPathComponent(metadata.imageName)
        if !metadata.imageName.isEmpty,
          imageURL.deletingLastPathComponent().standardizedFileURL
            == directory.standardizedFileURL
        {
          if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
          }
        }
      }
      if FileManager.default.fileExists(atPath: metadataURL.path) {
        try FileManager.default.removeItem(at: metadataURL)
      }
      // Metadata okunamadıysa bile UUID ile başlayan görseli temizle.
      removePayloadFiles(id: normalizedID, in: directory)
      return true
    }) ?? false
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

  private static func writeTextMetadata(
    _ metadata: Metadata,
    in directory: URL
  ) throws -> String {
    let metadataURL = directory.appendingPathComponent("\(metadata.id).json")
    do {
      try writeMetadataWithoutOverwriting(metadata, to: metadataURL)
    } catch {
      // Aynı intent yeniden yürütüldüyse birebir aynı teslim başarıdır;
      // farklı payload hiçbir zaman öncekinin rezervasyonunu ezmez.
      if metadataAt(metadataURL) == metadata { return metadata.id }
      if FileManager.default.fileExists(atPath: metadataURL.path) {
        throw StoreError.conflictingImport(metadata.id)
      }
      throw error
    }
    return metadata.id
  }

  /// Runner'ın aynaladığı DB boşluğundan, henüz DB'ye devredilmemiş uzantı
  /// rezervasyonlarını çıkarır. Metadata dosyaları kaynak olduğu için Runner
  /// aynayı tekrar yazsa bile uygulama kapalıyken alınan slotlar geri gelmez.
  private static func freeRemindersLeft(in directory: URL) -> Int? {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      defaults.object(forKey: freeRemindersLeftKey) != nil
    else { return nil }

    let metadataURLs = (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ))?.filter { $0.pathExtension == "json" } ?? []
    let reserved = metadataURLs.reduce(into: 0) { count, url in
      guard let metadata = metadataAt(url),
        metadata.freeReminderReserved,
        !metadata.freeReminderClaimed
      else { return }
      count += 1
    }
    return max(0, defaults.integer(forKey: freeRemindersLeftKey) - reserved)
  }

  /// Runner, Share Extension ve App Intents ayrı süreçlerdir. UserDefaults
  /// read-modify-write ve "dosyaları say → metadata yaz" işlemleri süreçler
  /// arasında atomik değildir; POSIX advisory lock son slotu tek kazanana
  /// verir. Kilit aynı App Group dosya sistemindedir ve süreç ölünce kernel
  /// tarafından otomatik bırakılır.
  private static func withInboxLock<T>(
    _ operation: (URL) throws -> T
  ) throws -> T {
    let directory = try inboxDirectory()
    let lockURL = directory.appendingPathComponent(coordinationLockName)
    let descriptor = open(
      lockURL.path,
      O_CREAT | O_RDWR,
      mode_t(S_IRUSR | S_IWUSR)
    )
    guard descriptor >= 0 else { throw StoreError.coordinationUnavailable }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX) == 0 else {
      throw StoreError.coordinationUnavailable
    }
    defer { flock(descriptor, LOCK_UN) }
    return try operation(directory)
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
    at date: Date,
    proUnlocked: Bool
  ) async throws {
    let content = UNMutableNotificationContent()
    // Ana uygulamadaki `ReminderService._titleFor` ile aynı katman ayrımı.
    content.title = proUnlocked ? "Latermark Pro" : "Latermark"
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
