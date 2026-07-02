import AppKit
import PinShotCore

@MainActor
final class CaptureSessionController {
  private let preferencesStore: PreferencesStore
  private let pinnedImageWindowManager: PinnedImageWindowManager
  private var overlayControllers: [CaptureOverlayWindowController] = []

  init(
    preferencesStore: PreferencesStore,
    pinnedImageWindowManager: PinnedImageWindowManager
  ) {
    self.preferencesStore = preferencesStore
    self.pinnedImageWindowManager = pinnedImageWindowManager
  }

  func beginCapture() {
    guard overlayControllers.isEmpty else {
      return
    }

    guard ScreenCaptureService.hasScreenCaptureAccess() || ScreenCaptureService.requestScreenCaptureAccess() else {
      showScreenRecordingPermissionAlert()
      return
    }

    let snapshots = NSScreen.screens.compactMap { ScreenCaptureService.capture(screen: $0) }
    guard !snapshots.isEmpty else {
      showError(message: "无法捕获屏幕", detail: "没有获取到可用的屏幕图像。")
      return
    }

    overlayControllers = snapshots.map { snapshot in
      let controller = CaptureOverlayWindowController(snapshot: snapshot)
      controller.onCommand = { [weak self] command, image in
        self?.handle(command: command, image: image)
      }
      return controller
    }
    overlayControllers.forEach { $0.show() }
  }

  private func handle(command: CaptureCommand, image: NSImage?) {
    switch command {
    case .cancel:
      endCapture()
    case .finishDefault:
      guard let image else {
        endCapture()
        return
      }
      performDefaultAction(with: image)
      endCapture()
    case .copy:
      guard let image else {
        return
      }
      PasteboardWriter.copy(image: image)
      endCapture()
    case .save:
      guard let image else {
        return
      }
      save(image: image)
      endCapture()
    case .pin:
      guard let image else {
        return
      }
      pinnedImageWindowManager.show(image: image)
      endCapture()
    case .ocr:
      guard let image else {
        return
      }
      Task { @MainActor in
        let text = await ImageTextRecognizer.recognizedText(from: image)
        OCRResultWindowController.show(text: text ?? "未识别到文字")
      }
    }
  }

  private func performDefaultAction(with image: NSImage) {
    switch preferencesStore.configuration.defaultAction {
    case .copyToClipboard:
      PasteboardWriter.copy(image: image)
    case .saveToFile:
      save(image: image)
    case .pinImage:
      pinnedImageWindowManager.show(image: image)
    }
  }

  private func save(image: NSImage) {
    let config = preferencesStore.configuration
    let directoryURL = URL(fileURLWithPath: config.saveDirectoryPath, isDirectory: true)

    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      let fileURL = uniqueFileURL(in: directoryURL)
      try PNGWriter.write(image: image, to: fileURL)
      NSSound(named: "Glass")?.play()
    } catch {
      showError(message: "截图保存失败", detail: error.localizedDescription)
    }
  }

  private func uniqueFileURL(in directoryURL: URL) -> URL {
    let base = ScreenshotFileNamer.fileName(for: Date())
      .replacingOccurrences(of: ".png", with: "")
    var candidate = directoryURL.appendingPathComponent("\(base).png")
    var index = 2

    while FileManager.default.fileExists(atPath: candidate.path) {
      candidate = directoryURL.appendingPathComponent("\(base)-\(index).png")
      index += 1
    }
    return candidate
  }

  private func endCapture() {
    overlayControllers.forEach { $0.close() }
    overlayControllers.removeAll()
  }

  private func showScreenRecordingPermissionAlert() {
    showError(
      message: "需要开启屏幕录制权限",
      detail: "请在「系统设置 > 隐私与安全性 > 屏幕录制」中允许 PinShot，然后重新触发截图。"
    )
  }

  private func showError(message: String, detail: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = detail
    alert.alertStyle = .warning
    alert.runModal()
  }
}

