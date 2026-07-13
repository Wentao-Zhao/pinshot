import AppKit
import PinShotCore

@MainActor
final class CaptureSessionController {
  private let preferencesStore: PreferencesStore
  private let pinnedImageWindowManager: PinnedImageWindowManager
  private var overlayControllers: [CaptureOverlayWindowController] = []
  private var captureTask: Task<Void, Never>?
  private var ocrTask: Task<Void, Never>?
  private var captureSessionID: UUID?
  private var captureTargetsByID: [UInt32: ScreenCaptureTarget] = [:]
  private var cancelHotKeyRegistered = false
  private lazy var cancelHotKeyMonitor = HotKeyMonitor(identity: .captureCancel) { [weak self] in
    self?.endCapture()
  }

  init(
    preferencesStore: PreferencesStore,
    pinnedImageWindowManager: PinnedImageWindowManager
  ) {
    self.preferencesStore = preferencesStore
    self.pinnedImageWindowManager = pinnedImageWindowManager
  }

  func beginCapture() {
    guard overlayControllers.isEmpty, captureTask == nil else {
      return
    }

    guard ScreenCaptureService.hasScreenCaptureAccess() || ScreenCaptureService.requestScreenCaptureAccess() else {
      showScreenRecordingPermissionAlert()
      return
    }

    let targets = ScreenCaptureService.captureTargets()
    guard !targets.isEmpty else {
      showError(message: "无法捕获屏幕", detail: "没有获取到可用的屏幕图像。")
      return
    }

    let sessionID = UUID()
    captureSessionID = sessionID
    startCancelMonitoring()
    captureTargetsByID = Dictionary(uniqueKeysWithValues: targets.map { (UInt32($0.displayID), $0) })
    let plan = MultiDisplayCapturePlan(displayIDs: targets.map { UInt32($0.displayID) })
    captureTask = Task.detached(priority: .userInitiated) {
      var capturedImages: [UInt32: SendableCapturedImage] = [:]
      for step in plan.steps {
        guard !Task.isCancelled else {
          return
        }
        guard case .capture(let displayID) = step else {
          break
        }
        if let image = ScreenCaptureService.captureCGImage(displayID: CGDirectDisplayID(displayID)) {
          capturedImages[displayID] = image
        }
      }

      let completedImages = capturedImages
      await MainActor.run {
        self.presentCapturedImages(completedImages, plan: plan, sessionID: sessionID)
      }
    }
  }

  func runCaptureSmokeTest(onComplete: @escaping (Bool) -> Void) {
    let screens = NSScreen.screens
    guard overlayControllers.isEmpty, !screens.isEmpty else {
      onComplete(false)
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      guard let self else {
        onComplete(false)
        return
      }
      let controllers = screens.map { screen in
        self.makeOverlayController(snapshot: ScreenCaptureService.syntheticSnapshot(screen: screen))
      }
      let cancelRegistered = self.startCancelMonitoring()
      let wasActive = NSApp.isActive
      self.overlayControllers = controllers
      controllers.forEach { $0.show() }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        let visible = controllers.allSatisfy { $0.window?.isVisible == true }
        let activationPreserved = NSApp.isActive == wasActive
        self?.endCapture()
        onComplete(visible && activationPreserved && cancelRegistered)
      }
    }
  }

  private func presentCapturedImages(
    _ capturedImages: [UInt32: SendableCapturedImage],
    plan: MultiDisplayCapturePlan,
    sessionID: UUID
  ) {
    guard captureSessionID == sessionID else {
      return
    }

    captureTask = nil
    var controllers: [CaptureOverlayWindowController] = []
    for step in plan.steps {
      guard case .present(let displayID) = step else {
        continue
      }
      guard
        let target = captureTargetsByID[displayID],
        let capturedImage = capturedImages[displayID]
      else {
        continue
      }
      let image = NSImage(cgImage: capturedImage.cgImage, size: target.size)
      controllers.append(makeOverlayController(snapshot: ScreenSnapshot(screen: target.screen, image: image)))
    }

    captureTargetsByID.removeAll()
    guard !controllers.isEmpty else {
      endCapture()
      showError(message: "无法捕获屏幕", detail: "没有获取到可用的屏幕图像。")
      return
    }

    overlayControllers = controllers
    controllers.forEach { $0.show() }
    if !cancelHotKeyRegistered {
      controllers.first?.makeKey()
    }
  }

  @discardableResult
  private func startCancelMonitoring() -> Bool {
    cancelHotKeyRegistered = cancelHotKeyMonitor.start(
      shortcut: CaptureInteractionPolicy.cancelShortcut,
      showsErrorAlert: false
    )
    return cancelHotKeyRegistered
  }

  private func makeOverlayController(snapshot: ScreenSnapshot) -> CaptureOverlayWindowController {
    let controller = CaptureOverlayWindowController(snapshot: snapshot)
    controller.onCommand = { [weak self, weak controller] command, image in
      self?.handle(command: command, image: image, source: controller)
    }
    return controller
  }

  private func handle(command: CaptureCommand, image: NSImage?, source: CaptureOverlayWindowController?) {
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
        source?.setOCRPanelState(.result(from: nil))
        return
      }
      ocrTask?.cancel()
      source?.setOCRPanelState(.recognizing)
      ocrTask = Task { @MainActor in
        let text = await ImageTextRecognizer.recognizedText(from: image)
        guard !Task.isCancelled else {
          return
        }
        source?.setOCRPanelState(.result(from: text))
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
    cancelHotKeyMonitor.stop()
    cancelHotKeyRegistered = false
    captureSessionID = nil
    captureTargetsByID.removeAll()
    captureTask?.cancel()
    captureTask = nil
    ocrTask?.cancel()
    ocrTask = nil
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
