import Foundation
import SwiftUI
import WidgetKit

/// Flutter tarafındaki `WidgetKeys` ile birebir aynı olmalı.
enum NotKeys {
    static let appGroup = "group.com.mersev.latermark"

    static let hasNote = "not_has_note"
    static let noteId = "not_note_id"
    static let body = "not_body"
    static let time = "not_time"
    static let date = "not_date"
    static let expiresAt = "not_expires_at"
    static let count = "not_count"
    static let photo = "not_photo"
}

/// Widget'ın tek karesi.
struct NotEntry: TimelineEntry {
    let date: Date
    let hasNote: Bool
    let noteId: Int
    let body: String
    let time: String
    let day: String
    let expiresAt: Date?
    let count: Int
    let image: UIImage?

    static let placeholder = NotEntry(
        date: Date(),
        hasNote: true,
        noteId: 0,
        body: "Muhasebeye göndereceğim",
        time: "14:32",
        day: "BUGÜN",
        expiresAt: Date().addingTimeInterval(60 * 60 * 52),
        count: 12,
        image: nil
    )

    static let empty = NotEntry(
        date: Date(),
        hasNote: false,
        noteId: 0,
        body: "",
        time: "",
        day: "",
        expiresAt: nil,
        count: 0,
        image: nil
    )

    /// Kalan süreyi kısa Türkçe biçimde verir: `2g`, `5sa`, `9dk`.
    ///
    /// Metin burada üretilir ki widget saatler sonra tazelendiğinde bile
    /// doğru olsun.
    var remaining: String? {
        guard let expiresAt else { return nil }
        let left = expiresAt.timeIntervalSince(date)
        if left <= 0 { return "şimdi" }
        if left >= 86_400 { return "\(Int(left / 86_400))g" }
        if left >= 3_600 { return "\(Int(left / 3_600))sa" }
        if left >= 60 { return "\(Int(left / 60))dk" }
        return "<1dk"
    }

    /// Notun ömründen ne kadarının kaldığı (halka göstergesi için).
    var lifeFraction: Double {
        guard let expiresAt else { return 0 }
        let left = expiresAt.timeIntervalSince(date)
        // Toplam süreyi bilmiyoruz; en uzun seçenek olan bir haftaya oranlarız.
        return max(0, min(1, left / (7 * 86_400)))
    }
}

/// Paylaşılan kapsayıcıdan okuyup zaman çizelgesini üretir.
struct NotProvider: TimelineProvider {
    func placeholder(in context: Context) -> NotEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NotEntry) -> Void) {
        completion(context.isPreview ? .placeholder : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotEntry>) -> Void) {
        // Uygulama her değişiklikte widget'ı zaten tazeliyor. Buradaki saatlik
        // yenileme yalnızca "kalan süre" rozetinin taze kalması için.
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [load()], policy: .after(refresh)))
    }

    private func load() -> NotEntry {
        guard let store = UserDefaults(suiteName: NotKeys.appGroup),
              store.bool(forKey: NotKeys.hasNote)
        else {
            return .empty
        }

        let epoch = store.integer(forKey: NotKeys.expiresAt)

        return NotEntry(
            date: Date(),
            hasNote: true,
            noteId: store.integer(forKey: NotKeys.noteId),
            body: store.string(forKey: NotKeys.body) ?? "",
            time: store.string(forKey: NotKeys.time) ?? "",
            day: store.string(forKey: NotKeys.date) ?? "",
            expiresAt: epoch > 0 ? Date(timeIntervalSince1970: TimeInterval(epoch)) : nil,
            count: store.integer(forKey: NotKeys.count),
            image: loadImage(from: store)
        )
    }

    /// Kareyi önce kayıtlı mutlak yoldan, olmazsa grup kapsayıcısındaki
    /// bilinen adından okur. İkinci yol, uygulama yeniden kurulduğunda kayıtlı
    /// yolun eskimesine karşı güvence.
    private func loadImage(from store: UserDefaults) -> UIImage? {
        if let path = store.string(forKey: NotKeys.photo),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NotKeys.appGroup
        ) else { return nil }

        let fallback = container
            .appendingPathComponent("home_widget")
            .appendingPathComponent("\(NotKeys.photo).png")
        return UIImage(contentsOfFile: fallback.path)
    }
}
