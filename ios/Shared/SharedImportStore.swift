import Foundation

/// Share Extension ile Runner'ın App Group üzerinden paylaştığı dayanıklı
/// gelen kutusu. JSON en son yazılır; böylece yarım kalan görsel kopyaları
/// hiçbir zaman Flutter'a tamamlanmış bir öğe gibi görünmez.
enum SharedImportStore {
  private static let appGroup = "group.com.mersev.latermark"
  private static let folderName = "shared_imports"

  private struct Metadata: Codable {
    let id: String
    let imageName: String
    let initialText: String
    let createdAtMilliseconds: Int64
    let saveImmediately: Bool
  }

  static func enqueue(
    imageAt source: URL,
    initialText: String,
    saveImmediately: Bool
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
          imageName: imageName,
          initialText: initialText,
          createdAtMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
          saveImmediately: saveImmediately
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
    saveImmediately: Bool
  ) throws {
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
    try imageData.write(to: temporary, options: .atomic)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try enqueue(
      imageAt: temporary,
      initialText: initialText,
      saveImmediately: saveImmediately
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

    for metadataURL in metadataFiles {
      guard
        let data = try? Data(contentsOf: metadataURL),
        let metadata = try? JSONDecoder().decode(Metadata.self, from: data),
        UUID(uuidString: metadata.id) != nil
      else {
        try? FileManager.default.removeItem(at: metadataURL)
        continue
      }

      let imageURL = directory.appendingPathComponent(metadata.imageName)
      guard
        imageURL.deletingLastPathComponent().standardizedFileURL
          == directory.standardizedFileURL,
        FileManager.default.fileExists(atPath: imageURL.path)
      else {
        try? FileManager.default.removeItem(at: metadataURL)
        continue
      }

      return [
        "id": metadata.id,
        "path": imageURL.path,
        "initialText": metadata.initialText,
        "createdAtMilliseconds": metadata.createdAtMilliseconds,
        "saveImmediately": metadata.saveImmediately,
      ]
    }
    return nil
  }

  static func complete(id: String) {
    guard UUID(uuidString: id) != nil, let directory = try? inboxDirectory()
    else { return }

    let metadataURL = directory.appendingPathComponent("\(id).json")
    if
      let data = try? Data(contentsOf: metadataURL),
      let metadata = try? JSONDecoder().decode(Metadata.self, from: data)
    {
      let imageURL = directory.appendingPathComponent(metadata.imageName)
      if imageURL.deletingLastPathComponent().standardizedFileURL
          == directory.standardizedFileURL
      {
        try? FileManager.default.removeItem(at: imageURL)
      }
    }
    try? FileManager.default.removeItem(at: metadataURL)
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
}
