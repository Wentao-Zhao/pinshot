import AppKit

@main
@MainActor
enum PinShotMain {
  private static let appDelegate = AppDelegate()

  static func main() {
    let application = NSApplication.shared
    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
  }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferencesStore = PreferencesStore()
  private let pinnedImageWindowManager = PinnedImageWindowManager()
  private var statusItemController: StatusItemController?
  private var preferencesWindowController: PreferencesWindowController?
  private var hotKeyMonitor: HotKeyMonitor?
  private var captureSessionController: CaptureSessionController?
  private var notificationObservers: [(center: NotificationCenter, observer: NSObjectProtocol)] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    let smokeTest = ProcessInfo.processInfo.environment["PINSHOT_SMOKE_TEST"]
    if smokeTest == "startup" {
      statusItemController = StatusItemController(
        onShowPreferences: {},
        onQuit: {}
      )
      print("PASS: PinShot startup smoke")
      NSApp.terminate(nil)
      return
    }

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
    installHotKeyRecoveryObservers()

    if smokeTest == "capture" {
      captureSessionController?.runCaptureSmokeTest { passed in
        print(passed ? "PASS: PinShot capture smoke" : "FAIL: PinShot capture smoke")
        NSApp.terminate(nil)
      }
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationWillTerminate(_ notification: Notification) {
    removeHotKeyRecoveryObservers()
    hotKeyMonitor?.stop()
  }

  private func installHotKeyRecoveryObservers() {
    let notificationCenter = NotificationCenter.default
    notificationObservers.append((
      notificationCenter,
      notificationCenter.addObserver(
        forName: NSApplication.didBecomeActiveNotification,
        object: NSApp,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refreshHotKeyRegistration()
        }
      }
    ))
    notificationObservers.append((
      notificationCenter,
      notificationCenter.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refreshHotKeyRegistration()
        }
      }
    ))

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    notificationObservers.append((
      workspaceCenter,
      workspaceCenter.addObserver(
        forName: NSWorkspace.didWakeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refreshHotKeyRegistration()
        }
      }
    ))
    notificationObservers.append((
      workspaceCenter,
      workspaceCenter.addObserver(
        forName: NSWorkspace.screensDidWakeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.refreshHotKeyRegistration()
        }
      }
    ))
  }

  private func removeHotKeyRecoveryObservers() {
    for entry in notificationObservers {
      entry.center.removeObserver(entry.observer)
    }
    notificationObservers.removeAll()
  }

  private func refreshHotKeyRegistration() {
    hotKeyMonitor?.refresh()
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
