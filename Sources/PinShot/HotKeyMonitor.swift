import AppKit
import Carbon
import PinShotCore

@MainActor
final class HotKeyMonitor {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var currentShortcut: KeyboardShortcut?
  private let identity: HotKeyIdentity
  private let callbackContext: HotKeyCallbackContext

  init(identity: HotKeyIdentity = .capture, onTrigger: @escaping () -> Void) {
    self.identity = identity
    callbackContext = HotKeyCallbackContext(identity: identity) {
      Task { @MainActor in
        onTrigger()
      }
    }
  }

  @discardableResult
  func start(shortcut: KeyboardShortcut, showsErrorAlert: Bool = true) -> Bool {
    currentShortcut = shortcut
    return register(shortcut: shortcut, showsErrorAlert: showsErrorAlert)
  }

  func refresh() {
    guard let currentShortcut else {
      return
    }
    _ = register(shortcut: currentShortcut, showsErrorAlert: false)
  }

  private func register(shortcut: KeyboardShortcut, showsErrorAlert: Bool) -> Bool {
    stopHotKey()
    guard installEventHandlerIfNeeded() else {
      if showsErrorAlert {
        showHotKeyRegistrationError(OSStatus(eventInternalErr))
      }
      return false
    }

    let hotKeyID = EventHotKeyID(signature: identity.signature, id: identity.id)
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
      if showsErrorAlert {
        showHotKeyRegistrationError(status)
      }
      return false
    }
    return true
  }

  func stop() {
    stopHotKey()
    currentShortcut = nil
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
  }

  private func installEventHandlerIfNeeded() -> Bool {
    guard eventHandlerRef == nil else {
      return true
    }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: OSType(kEventHotKeyPressed)
    )

    let contextPointer = Unmanaged.passUnretained(callbackContext).toOpaque()
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else {
          return OSStatus(eventNotHandledErr)
        }

        var eventHotKeyID = EventHotKeyID()
        let parameterStatus = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &eventHotKeyID
        )
        guard parameterStatus == noErr else {
          return OSStatus(eventNotHandledErr)
        }

        let context = Unmanaged<HotKeyCallbackContext>.fromOpaque(userData).takeUnretainedValue()
        guard context.identity.matches(signature: eventHotKeyID.signature, id: eventHotKeyID.id) else {
          return OSStatus(eventNotHandledErr)
        }
        context.trigger()
        return noErr
      },
      1,
      &eventType,
      contextPointer,
      &eventHandlerRef
    )
    if status != noErr {
      eventHandlerRef = nil
      return false
    }
    return true
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

  private func showHotKeyRegistrationError(_ status: OSStatus) {
    let alert = NSAlert()
    alert.messageText = "截图快捷键注册失败"
    alert.informativeText = "当前快捷键可能已被系统或其他 App 占用。错误码：\(status)"
    alert.alertStyle = .warning
    alert.runModal()
  }
}

private final class HotKeyCallbackContext {
  let identity: HotKeyIdentity
  let trigger: () -> Void

  init(identity: HotKeyIdentity, trigger: @escaping () -> Void) {
    self.identity = identity
    self.trigger = trigger
  }
}
