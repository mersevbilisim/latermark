import Foundation
import SwiftUI
import WidgetKit

/// Widget uzantısının kendi paketindeki yerelleştirilmiş metinler.
enum NotText {
    static func value(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: value(key), locale: Locale.current, arguments: arguments)
    }
}

/// Flutter tarafındaki `WidgetKeys` ile birebir aynı olmalı.
enum NotKeys {
    static let appGroup = "group.com.mersev.latermark"

    static let hasNote = "not_has_note"
    static let noteId = "not_note_id"
    static let body = "not_body"
    static let expiresAt = "not_expires_at"
    static let createdAt = "not_created_at"
    static let pro = "not_pro"
    static let accent = "not_accent"
    static let photo = "not_photo"
}

/// Widget'ın tek karesi.
struct NotEntry: TimelineEntry {
    let date: Date
    let hasNote: Bool
    let noteId: Int
    let body: String
    let expiresAt: Date?
    let createdAt: Date?
    let pro: Bool
    let accentARGB: String
    let image: UIImage?

    static let placeholder = NotEntry(
        date: Date(),
        hasNote: true,
        noteId: 0,
        body: NotText.value("widget.preview.note"),
        expiresAt: Date().addingTimeInterval(60 * 60 * 52),
        createdAt: Date().addingTimeInterval(-60 * 60 * 20),
        pro: true,
        accentARGB: "FFFF7A55",
        image: nil
    )

    static let empty = NotEntry(
        date: Date(),
        hasNote: false,
        noteId: 0,
        body: "",
        expiresAt: nil,
        createdAt: nil,
        pro: false,
        accentARGB: "FFFF7A55",
        image: nil
    )

    /// Kalan süreyi widget'ın yürürlükteki dilinde kısa biçimde verir.
    ///
    /// Metin burada üretilir ki widget saatler sonra tazelendiğinde bile
    /// doğru olsun.
    var remaining: String? {
        guard let expiresAt else { return nil }
        let left = expiresAt.timeIntervalSince(date)
        if left <= 0 { return NotText.value("remaining.now") }
        if left >= 86_400 {
            return NotText.format("remaining.days.short", Int(ceil(left / 86_400)))
        }
        if left >= 3_600 {
            return NotText.format("remaining.hours.short", Int(ceil(left / 3_600)))
        }
        if left >= 60 {
            return NotText.format("remaining.minutes.short", Int(ceil(left / 60)))
        }
        return NotText.value("remaining.less_than_minute.short")
    }

    /// Tek satırlık kilit ekranı alanına sığan kısa özet.
    var inlineSummary: String {
        // En dar ailede zamanı başa al: uzun bir not kesilse bile widget'ın
        // yalnızca gövde metninden ibaret olmadığı ilk bakışta anlaşılsın.
        if let temporalSummary { return "\(temporalSummary) · \(noteText)" }
        return noteText
    }

    var noteText: String {
        let value = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? NotText.value("widget.note.untitled") : value
    }

    /// Kaydın gün etiketi: `BUGÜN`, `DÜN`, `PAZARTESİ`, `6 AĞUSTOS`.
    ///
    /// Metin burada üretilir, Flutter'dan hazır gelmez. Hazır gelseydi
    /// paylaşılan alanda donardı: widget saatte bir tazelense bile aynı yazıyı
    /// yeniden okuyacağı için, uygulama açılmadığı sürece dün kaydedilmiş bir
    /// not ertesi gün hâlâ "BUGÜN" derdi.
    ///
    /// Karşılaştırma `date` üzerinden yapılıyor — kalan süre ve ömür oranı da
    /// aynı ana bakıyor, böylece tek bir karede anlatılan her şey birbiriyle
    /// tutarlı kalıyor.
    var displayDay: String {
        guard let createdAt else { return "" }

        let calendar = Calendar.current
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        let label: String
        if elapsed <= 0 {
            label = NotText.value("day.today")
        } else if elapsed == 1 {
            label = NotText.value("day.yesterday")
        } else if elapsed < 7 {
            label = createdAt.formatted(.dateTime.weekday(.wide))
        } else if calendar.component(.year, from: createdAt)
            == calendar.component(.year, from: date) {
            label = createdAt.formatted(.dateTime.day().month(.wide))
        } else {
            label = createdAt.formatted(.dateTime.day().month(.wide).year())
        }

        // Türkçede `i` → `İ`; yerel duyarlı büyütme bunu doğru yapar.
        return label.uppercased(with: .current)
    }

    /// Kaydın saati. Cihazın 12/24 saat tercihini sistem biçimlendiricisi
    /// uygular; künyedeki her metin gibi bu da widget'ın kendi işi.
    var displayTime: String {
        createdAt?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    /// "BUGÜN · 14:32" gibi, dil ve bölgeye uyan kayıt damgası.
    var captureStamp: String {
        [displayDay, displayTime]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Kalan ömür, yoksa kaydın yaşı. Kilit ekranında her notun
    /// yalnızca bir cümle değil, zamanda bir iz olduğunu anlatır.
    var temporalSummary: String? {
        if let remaining { return remaining }
        guard let createdAt else {
            return displayTime.isEmpty ? nil : displayTime
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let value = formatter.localizedString(for: createdAt, relativeTo: date)
        return value.isEmpty ? (displayTime.isEmpty ? nil : displayTime) : value
    }

    /// Kaydın süresi dolmuş mu.
    ///
    /// Silme işini uygulama yapıyor ve yalnızca çalışırken yapabiliyor.
    /// Kullanıcı uygulamayı günlerce açmazsa widget bayat bir kaydı
    /// göstermeye devam ederdi; karar burada widget'ın kendisinde.
    var expired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= date
    }

    /// Ekranda kayıt gösterilecek mi.
    var showsNote: Bool { hasNote && !expired }

    var accent: Color { NotDesign.accent(accentARGB) }

    /// Notun ömründen ne kadarının kaldığı: 1 = yeni, 0 = süresi doldu.
    ///
    /// Oran notun **kendi** toplam süresine göre hesaplanır. Sabit bir haftaya
    /// oranlamak, 3 günlük bir notu doğduğu anda yarı tükenmiş gösteriyordu.
    var lifeFraction: Double {
        guard let expiresAt, let createdAt else { return 0 }
        let total = expiresAt.timeIntervalSince(createdAt)
        guard total > 0 else { return 0 }
        return max(0, min(1, expiresAt.timeIntervalSince(date) / total))
    }
}

/// Paylaşılan kapsayıcıdan okuyup zaman çizelgesini üretir.
///
/// [withPhoto] kapalıyken kare diskten hiç çözülmez. Kilit ekranı aksesuarları
/// WidgetKit'in en dar bellek bütçesiyle çalışıyor ve hiç çizmeyecekleri bir
/// görseli çözmek, uzantının öldürülüp widget'ın boş kalmasına yol açabiliyor.
struct NotProvider: TimelineProvider {
    var withPhoto: Bool = true

    func placeholder(in context: Context) -> NotEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NotEntry) -> Void) {
        completion(context.isPreview ? .placeholder : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotEntry>) -> Void) {
        // Uygulama her değişiklikte widget'ı zaten tazeliyor. Buradaki saatlik
        // yenileme yalnızca "kalan süre" rozetinin taze kalması için.
        let entry = load()
        let calendar = Calendar.current
        var refresh = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

        // Gün etiketi gece yarısı değişiyor. Yalnızca saatlik yenilemeye
        // bırakılırsa "BUGÜN" bir saate kadar geç dönerdi.
        if let midnight = calendar.nextDate(
            after: entry.date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ), midnight < refresh {
            refresh = midnight
        }

        // Süre dolduğu anda tazele: widget kaydı kendiliğinden bıraksın,
        // bir sonraki saatlik yenilemeyi beklemesin.
        if let expiresAt = entry.expiresAt, expiresAt > entry.date, expiresAt < refresh {
            refresh = expiresAt
        }
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func load() -> NotEntry {
        guard let store = UserDefaults(suiteName: NotKeys.appGroup) else {
            return .empty
        }

        let pro = store.bool(forKey: NotKeys.pro)
        // Entitlement, veri katmanında da sınırdır. Flutter kilitli yayında
        // alanları zaten temizler; bu maskeleme eski/yarım kalmış paylaşılan
        // verinin başka bir görünüm yoluyla yeniden kullanılmasını önler.
        let hasNote = pro && store.bool(forKey: NotKeys.hasNote)
        let epoch = hasNote ? store.integer(forKey: NotKeys.expiresAt) : 0
        let born = hasNote ? store.integer(forKey: NotKeys.createdAt) : 0

        return NotEntry(
            date: Date(),
            hasNote: hasNote,
            noteId: hasNote ? store.integer(forKey: NotKeys.noteId) : 0,
            body: hasNote ? (store.string(forKey: NotKeys.body) ?? "") : "",
            expiresAt: epoch > 0 ? Date(timeIntervalSince1970: TimeInterval(epoch)) : nil,
            createdAt: born > 0 ? Date(timeIntervalSince1970: TimeInterval(born)) : nil,
            pro: pro,
            accentARGB: store.string(forKey: NotKeys.accent) ?? "FFFF7A55",
            image: withPhoto && hasNote ? loadImage(from: store) : nil
        )
    }

    /// Kareyi önce kayıtlı mutlak yoldan, olmazsa grup kapsayıcısındaki
    /// bilinen adından okur. Bir yol hiç yoksa eski sabit dosyaya düşmeyiz;
    /// Flutter bu anahtarı yeni fotoğraf üretilemediğinde özellikle siliyor.
    /// Böylece önceki notun karesi yeni notta yeniden görünmez.
    private func loadImage(from store: UserDefaults) -> UIImage? {
        guard let path = store.string(forKey: NotKeys.photo), !path.isEmpty else {
            return nil
        }

        if let image = UIImage(contentsOfFile: path) {
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
