import AppIntents
import Foundation

/// Siri veya Kestirmeler'den gelen metni App Group gelen kutusuna bırakır.
///
/// Kaydın veritabanı satırı Runner bir sonraki açılışında oluşuyor; oluşma
/// anı değil, **söylenme anı** yazılıyor (`createdAtMilliseconds`), yani
/// saklama süresi de listedeki sıra da doğru kalıyor. Kullanıcı açısından not
/// bu çağrıyla alınmış oluyor.
@available(iOS 16.0, *)
struct AddTextNoteIntent: AppIntent {
  static let title: LocalizedStringResource = "Add Note"
  static let description = IntentDescription(
    "Save a text note to Latermark."
  )

  @Parameter(
    title: "Note Text",
    description: "The text to save.",
    requestValueDialog: "What would you like to save?"
  )
  var text: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let normalizedText = LatermarkIntentSupport.normalized(text) else {
      return .result(
        dialog: "Tell me some text to save. Nothing was saved."
      )
    }

    do {
      try SharedImportStore.enqueue(text: normalizedText, remindAt: nil)
      return .result(dialog: "Added to Latermark.")
    } catch {
      return .result(
        dialog: "Latermark couldn't save the note. Please try again. Nothing was saved."
      )
    }
  }
}

/// Metinle birlikte mutlak hatırlatma zamanını alır.
///
/// Buradaki asıl iş **alarmı kurmak**. Not satırı gelen kutusunda bekleyebilir
/// ama bildirim bekleyemez: kullanıcı uygulamayı bir daha hiç açmasa bile
/// hatırlatma çalmalı. Bu yüzden bildirimi uzantı kendisi planlıyor
/// (`QueuedReminder`); Runner açılınca kayıt oluşuyor ve geçici alarm
/// gerçeğiyle değiştiriliyor.
@available(iOS 16.0, *)
struct AddReminderNoteIntent: AppIntent {
  static let title: LocalizedStringResource = "Add Reminder Note"
  static let description = IntentDescription(
    "Save a text note with a reminder to Latermark."
  )

  // Parametreler bilerek isteğe bağlı **değil**.
  //
  // İsteğe bağlı olduklarında değeri `perform()` içinde elle istemek
  // gerekiyordu; Kestirmeler o durumda tarih seçici yerine düz bir alan
  // gösteriyor ve kullanıcı hatırlatma zamanını hiç giremiyordu. Zorunlu
  // parametreyi sistem kendisi çözüyor: Kestirmeler'de gerçek tarih seçici,
  // Siri'de konuşarak soru.
  //
  // Bedeli şu: Pro kapısı artık iki sorudan **sonra** işliyor, yani hakkı
  // olmayan kullanıcı önce metni ve zamanı söyleyip sonra reddediliyor.
  // Alternatifi, hatırlatma zamanının hiç girilememesiydi.
  @Parameter(
    title: "Note Text",
    description: "The text to save.",
    requestValueDialog: "What would you like to save?"
  )
  var text: String

  @Parameter(
    title: "Reminder Time",
    description: "The date and time for the reminder.",
    kind: .dateTime,
    requestValueDialog: "When should I remind you?"
  )
  var remindAt: Date

  func perform() async throws -> some IntentResult & ProvidesDialog {
    // Kayıt yapılmadan önceki kapılar. Sırası önemli: hiçbiri geçmezse
    // gelen kutusuna hiçbir şey bırakılmaz ve alarm kurulmaz.
    // Hatirlatma Pro'ya kilitli **degil**, sayili: ucretsiz katmanin da hakki
    // var (bkz. `ProLimits.freeReminders`). Uzanti veritabanini acamadigi icin
    // kalan hakki aynadan okuyor.
    //
    // Ayna **tavsiye**, son soz uygulamanin: burasi bir kapi degil, Siri'nin
    // dogru cumleyi kurabilmesi icin var. Kullanici konustuktan sonra hakki
    // baska bir yoldan tukenmisse uygulama iceri alirken hatirlatmayi
    // dusuruyor ve bunu kullaniciya soyluyor.
    //
    // Anahtar hic yoksa (eski surumden yeni gelen ayna) eski davranisa,
    // yani Pro kapisina duselim: bilinmeyen bir sayiyi "hak var" saymak,
    // olmayan bir hakki vaat etmek olurdu.
    let availability = SharedImportStore.reminderAvailability
    guard availability.allowsReminder else {
      return .result(
        dialog: availability.freeRemindersLeft == nil
          ? "Reminders from Siri require Latermark Pro. Nothing was saved."
          : "You have used all your free reminders. Latermark Pro removes the limit. Nothing was saved."
      )
    }

    // Ana uygulama bu tercih kapalıyken bekleyen bütün bildirimleri siliyor;
    // kurulacak alarm ilk açılışta sessizce kaybolurdu.
    guard SharedImportStore.reminderEnabled != false else {
      return .result(
        dialog: "Reminders are turned off in Latermark. Turn them on there first. Nothing was saved."
      )
    }

    guard
      let retentionMinutes = SharedImportStore.defaultRetentionMinutes,
      retentionMinutes >= 0
    else {
      return .result(
        dialog: "Open Latermark once so Siri can read your retention setting. Nothing was saved."
      )
    }

    // İzin uzantıdan istenemez, yalnız okunur. İzin yokken alarm sözü vermek
    // bu akışı yeniden işe yaramaz hâle getirirdi.
    guard await QueuedReminder.authorized() else {
      return .result(
        dialog: "Latermark can't send notifications yet. Allow them in Latermark first. Nothing was saved."
      )
    }

    guard let normalizedText = LatermarkIntentSupport.normalized(text) else {
      return .result(
        dialog: "Tell me some text to save. Nothing was saved."
      )
    }

    let requestedReminder = remindAt
    let now = Date()
    guard requestedReminder > now else {
      return .result(
        dialog: "The reminder time must be in the future. Nothing was saved."
      )
    }

    // Sıfır dakika Latermark'ın "süresiz sakla" seçimidir.
    if retentionMinutes > 0 {
      let expiry = now.addingTimeInterval(TimeInterval(retentionMinutes) * 60)
      guard requestedReminder < expiry else {
        return .result(
          dialog: "That reminder is later than this note's deletion time. Choose an earlier time or extend retention in Latermark. Nothing was saved."
        )
      }
    }

    let queued: SharedImportStore.ReminderEnqueueResult
    do {
      // Kota kontrolü bu noktada **yeniden ve atomik** yapılır. Yukarıdaki
      // okuma yalnız erken diyalog içindir; iki eşzamanlı intent son slotu
      // birlikte görmüş olabilir.
      queued = try SharedImportStore.enqueueReminder(
        text: normalizedText,
        remindAt: requestedReminder
      )
    } catch SharedImportStore.StoreError.noFreeReminders {
      return .result(
        dialog: "You have used all your free reminders. Latermark Pro removes the limit. Nothing was saved."
      )
    } catch {
      return .result(
        dialog: "Latermark couldn't save the note. Please try again. Nothing was saved."
      )
    }

    do {
      try await QueuedReminder.schedule(
        importId: queued.id,
        body: normalizedText,
        at: requestedReminder,
        proUnlocked: queued.proUnlocked
      )
      guard SharedImportStore.markQueuedReminderScheduled(id: queued.id) else {
        // Alarm kuruldu ama dayanıklı kanıt yazılamadı. İzsiz bırakmak, vadesi
        // geçince kotayı doğru kapatmayı imkânsız kılardı.
        QueuedReminder.cancel(importId: queued.id)
        return .result(
          dialog: "Added to Latermark, but the reminder couldn't be set. Open Latermark to finish it."
        )
      }
    } catch {
      // Not duruyor ve Runner açıldığında hatırlatmayı kendisi kuracak. Söz
      // verilmeyen tek şey uygulama hiç açılmazsa alarmın çalması.
      return .result(
        dialog: "Added to Latermark, but the reminder couldn't be set. Open Latermark to finish it."
      )
    }

    return .result(dialog: "Added to Latermark. I'll remind you then.")
  }
}

private enum LatermarkIntentSupport {
  static func normalized(_ text: String) -> String? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}
