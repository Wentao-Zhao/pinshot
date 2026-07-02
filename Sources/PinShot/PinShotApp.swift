import AppKit

@main
@MainActor
final class PinShotApp: NSObject, NSApplicationDelegate {
  private let preferencesStore = PreferencesStore()
  private let pinnedImageWindowManager = PinnedImageWindowManager()
  private var statusItemController: StatusItemController?
  private var preferencesWindowController: PreferencesWindowController?
  private var hotKeyMonitor: HotKeyMonitor?
  private var captureSessionController: CaptureSessionController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    captureSessionController = CaptureSessionController(
      preferencesStore: preferencesStore,
      pinnedImageWindowManager: pinnedImageWindowManager
    )

    statusItemController = StatusItemController(
      onShowPreferences: { [weak self] in self?.showPreferences() },
      onQuit: { NSApp.terminate(nil) }
    )

    hotKeyMonitor = HotKeyMonitor { [weak self] in
      self?.captureSessionController?.beginCapture()
    }
    hotKeyMonitor?.start(shortcut: preferencesStore.configuration.shortcut)
  }

  private func showPreferences() {
    if preferencesWindowController == nil {
      preferencesWindowController = PreferencesWindowController(
        preferencesStore: preferencesStore,
        onConfigurationChanged: { [weak self] in
          guard let self else {
            return
          }
          self.hotKeyMonitor?.start(shortcut: self.preferencesStore.configuration.shortcut)
        }
      )
    }

    preferencesWindowController?.show()
  }
}

