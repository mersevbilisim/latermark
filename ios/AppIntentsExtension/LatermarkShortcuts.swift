import AppIntents

/// Tetikleme cümleleri bilerek açık uçlu parametre taşımaz. Böylece Siri
/// intent'i seçtikten sonra zorunlu metin ve zaman alanlarını konuşarak sorar.
///
/// Her kısayolun dört cümlesi var çünkü eşleşme **şablonla** yapılıyor, serbest
/// anlamayla değil: kalıp tutmazsa Siri intent'i hiç çalıştırmıyor, olsa olsa
/// "bu uygulamanın kestirmeleri işine yarayabilir" diye öneriyor. Türkçede iki
/// biçim de gerekiyor — ek uygulama adına yapışan doğal söyleyiş
/// ("Latermark'ta not oluştur") ve adı ayrı bir sözcük bırakan güvenli söyleyiş
/// ("Latermark ile not oluştur"). İlki daha doğal, ikincisi ses tanıma adı bitişik
/// yazdığında da tutuyor.
/// Sürüm kapısı Runner yüzünden: uygulama iOS 15.6 hedefliyor, App Intents
/// iOS 16 istiyor. Dağıtım hedefini yükseltmek iOS 15 kullanıcılarını atardı.
@available(iOS 16.0, *)
struct LatermarkShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddTextNoteIntent(),
      phrases: [
        "Add a note with \(.applicationName)",
        "Create a note in \(.applicationName)",
        "Save a note to \(.applicationName)",
        "New note in \(.applicationName)",
      ],
      shortTitle: "Save Note",
      systemImageName: "square.and.pencil"
    )

    AppShortcut(
      intent: AddReminderNoteIntent(),
      phrases: [
        "Add a reminder note with \(.applicationName)",
        "Create a reminder note in \(.applicationName)",
        "Save a reminder note to \(.applicationName)",
        "New reminder note in \(.applicationName)",
      ],
      shortTitle: "Save Reminder Note",
      systemImageName: "bell.badge"
    )
  }

  static let shortcutTileColor: ShortcutTileColor = .navy
}
