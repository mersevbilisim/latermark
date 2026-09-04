import Social
import UniformTypeIdentifiers
import UIKit

/// Fotoğraflar'daki paylaşım sayfasında Latermark'ın kendi küçük not alanı.
/// Apple'ın önerdiği gibi işi uzantının içinde tamamlar; ana uygulamayı özel
/// URL hileleriyle zorla açmaya çalışmaz.
final class ShareViewController: SLComposeServiceViewController {
  private var isSaving = false
  private var remindAfterDays = 0

  private func text(_ key: String) -> String {
    NSLocalizedString(key, tableName: "Localizable", bundle: .main, comment: "")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    placeholder = text("share.compose.hint")
  }

  override func isContentValid() -> Bool {
    !isSaving && contentText.count <= 5_000
  }

  override func didSelectPost() {
    guard !isSaving, let provider = imageProvider() else {
      showFailure()
      return
    }

    isSaving = true
    validateContent()
    let note = contentText.trimmingCharacters(in: .whitespacesAndNewlines)

    provider.loadFileRepresentation(
      forTypeIdentifier: UTType.image.identifier
    ) { [weak self] url, _ in
      guard let self else { return }
      if let url {
        do {
          try SharedImportStore.enqueue(
            imageAt: url,
            initialText: note,
            saveImmediately: true,
            remindAfterDays: remindAfterDays
          )
          finish()
          return
        } catch {
          // Bazı sağlayıcılar geçici URL vermek yerine yalnızca UIImage verir.
        }
      }
      loadImageObject(from: provider, note: note)
    }
  }

  override func configurationItems() -> [Any]! {
    // Extension mağaza/Drift açmaz; ana uygulamanın App Group'a aynaladığı son
    // bilinen Pro/kota durumunu kullanır ve Runner kaydederken yeniden doğrular.
    // Anahtar hiç yoksa eski sürüm aynasıdır ve güvenli biçimde Pro'ya düşer.
    let availability = SharedImportStore.reminderAvailability
    guard availability.allowsReminder else { return [] }

    guard let reminder = SLComposeSheetConfigurationItem() else { return [] }
    reminder.title = text("share.reminder.title")
    reminder.value = reminderValue
    reminder.tapHandler = { [weak self] in self?.chooseReminder() }
    return [reminder]
  }

  private var reminderValue: String {
    switch remindAfterDays {
    case 1: return text("share.reminder.tomorrow")
    case 7: return text("share.reminder.next_week")
    case 2...365:
      return String(format: text("share.reminder.days"), remindAfterDays)
    default: return text("share.reminder.off")
    }
  }

  private func chooseReminder() {
    let alert = UIAlertController(
      title: text("share.reminder.title"),
      message: nil,
      preferredStyle: .alert
    )
    addReminderAction(
      to: alert,
      title: text("share.reminder.off"),
      days: 0
    )
    addReminderAction(
      to: alert,
      title: text("share.reminder.tomorrow"),
      days: 1
    )
    addReminderAction(
      to: alert,
      title: text("share.reminder.next_week"),
      days: 7
    )
    alert.addAction(UIAlertAction(
      title: text("share.reminder.custom"),
      style: .default
    ) { [weak self] _ in
      self?.chooseCustomReminder()
    })
    alert.addAction(UIAlertAction(
      title: text("action.cancel"),
      style: .cancel
    ))
    present(alert, animated: true)
  }

  private func addReminderAction(
    to alert: UIAlertController,
    title: String,
    days: Int
  ) {
    alert.addAction(UIAlertAction(title: title, style: .default) {
      [weak self] _ in
      self?.remindAfterDays = days
      self?.reloadConfigurationItems()
    })
  }

  private func chooseCustomReminder() {
    let alert = UIAlertController(
      title: text("share.reminder.custom"),
      message: text("share.reminder.custom.message"),
      preferredStyle: .alert
    )
    alert.addTextField { [weak self] field in
      field.keyboardType = .numberPad
      field.placeholder = self?.text("share.reminder.custom.placeholder")
      if let self, self.remindAfterDays > 0 {
        field.text = String(self.remindAfterDays)
      }
    }
    alert.addAction(UIAlertAction(
      title: text("action.cancel"),
      style: .cancel
    ))
    alert.addAction(UIAlertAction(
      title: text("action.ok"),
      style: .default
    ) { [weak self, weak alert] _ in
      guard
        let self,
        let raw = alert?.textFields?.first?.text,
        let days = Int(raw),
        (1...365).contains(days)
      else { return }
      self.remindAfterDays = days
      self.reloadConfigurationItems()
    })
    present(alert, animated: true)
  }

  private func imageProvider() -> NSItemProvider? {
    extensionContext?.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] }
      .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
  }

  private func loadImageObject(from provider: NSItemProvider, note: String) {
    guard provider.canLoadObject(ofClass: UIImage.self) else {
      showFailure()
      return
    }
    provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
      guard
        let self,
        let image = object as? UIImage,
        let data = image.jpegData(compressionQuality: 0.94)
      else {
        self?.showFailure()
        return
      }
      do {
        try SharedImportStore.enqueue(
          imageData: data,
          fileExtension: "jpg",
          initialText: note,
          saveImmediately: true,
          remindAfterDays: remindAfterDays
        )
        finish()
      } catch {
        showFailure()
      }
    }
  }

  private func finish() {
    DispatchQueue.main.async { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }

  private func showFailure() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      isSaving = false
      validateContent()
      let alert = UIAlertController(
        title: text("share.error.title"),
        message: text("share.error.body"),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: text("action.ok"), style: .default))
      present(alert, animated: true)
    }
  }
}
