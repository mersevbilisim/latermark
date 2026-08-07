import Social
import UniformTypeIdentifiers
import UIKit

/// Fotoğraflar'daki paylaşım sayfasında Latermark'ın kendi küçük not alanı.
/// Apple'ın önerdiği gibi işi uzantının içinde tamamlar; ana uygulamayı özel
/// URL hileleriyle zorla açmaya çalışmaz.
final class ShareViewController: SLComposeServiceViewController {
  private var isSaving = false

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
            saveImmediately: true
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

  override func configurationItems() -> [Any]! { [] }

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
          saveImmediately: true
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
