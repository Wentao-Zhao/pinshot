import AppKit
import Carbon
import PinShotCore

@MainActor
final class HotKeyMonitor {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private let onTrigger: () -> Void

  init(onTrigger: @escaping () -> Void) {
    self.onTrigger = onTrigger
  }

  func start(shortcut: KeyboardShortcut) {
    stopHotKey()
    installEventHandlerIfNeeded()

    let hotKeyID = EventHotKeyID(signature: fourCharCode("PINS"), id: 1)
    let status = RegisterEventHotKey(
      UInt32(shortcut.keyCode),
      carbonModifiers(for: shortcut.modifiers),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    if status != noErr {
      hotKeyRef = nil
      showHotKeyRegistrationError(status)
    }
  }

  func stop() {
    stopHotKey()
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
  }

  private func installEventHandlerIfNeeded() {
    guard eventHandlerRef == nil else {
      return
    }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: OSType(kEventHotKeyPressed)
    )

    let selfPointer = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else {
          return noErr
        }
        let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
        Task { @MainActor in
          monitor.onTrigger()
        }
        return noErr
      },
      1,
      &eventType,
      selfPointer,
      &eventHandlerRef
    )
  }

  private func stopHotKey() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }

  private func carbonModifiers(for modifiers: Set<CommandModifier>) -> UInt32 {
    var value: UInt32 = 0
    if modifiers.contains(.command) { value |= UInt32(cmdKey) }
    if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
    if modifiers.contains(.option) { value |= UInt32(optionKey) }
    if modifiers.contains(.control) { value |= UInt32(controlKey) }
    return value
  }

  private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
  }

  private func showHotKeyRegistrationError(_ status: OSStatus) {
    let alert = NSAlert()
    alert.messageText = "截图快捷键注册失败"
    alert.informativeText = "当前快捷键可能已被系统或其他 App 占用。错误码：\(status)"
    alert.alertStyle = .warning
    alert.runModal()
  }
}
