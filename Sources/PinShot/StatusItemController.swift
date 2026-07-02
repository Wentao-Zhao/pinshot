import AppKit

@MainActor
final class StatusItemController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let onShowPreferences: () -> Void
  private let onQuit: () -> Void

  init(onShowPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
    self.onShowPreferences = onShowPreferences
    self.onQuit = onQuit
    super.init()
    configure()
  }

  private func configure() {
    guard let button = statusItem.button else {
      return
    }
    button.image = MenuBarIcon.image
    button.imagePosition = .imageOnly
    button.toolTip = "PinShot：使用 ⌘⇧2 开始区域截图"
    button.target = self
    button.action = #selector(handleStatusItem)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  @objc private func handleStatusItem() {
    guard NSApp.currentEvent?.type == .rightMouseUp, let button = statusItem.button else {
      return
    }

    let menu = NSMenu()
    let preferencesItem = NSMenuItem(title: "偏好设置", action: #selector(showPreferences), keyEquivalent: ",")
    preferencesItem.target = self
    menu.addItem(preferencesItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "退出 PinShot", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
  }

  @objc private func showPreferences() {
    onShowPreferences()
  }

  @objc private func quit() {
    onQuit()
  }
}

