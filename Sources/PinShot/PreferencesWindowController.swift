import AppKit
import PinShotCore

@MainActor
final class PreferencesWindowController: NSWindowController {
  private let preferencesStore: PreferencesStore
  private let onConfigurationChanged: () -> Void

  private let defaultActionPopup = NSPopUpButton()
  private let shortcutRecorderButton = ShortcutRecorderButton()
  private let saveDirectoryField = NSTextField(labelWithString: "")
  private let launchAtLoginSwitch = NSSwitch()

  init(
    preferencesStore: PreferencesStore,
    onConfigurationChanged: @escaping () -> Void
  ) {
    self.preferencesStore = preferencesStore
    self.onConfigurationChanged = onConfigurationChanged

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 268),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "PinShot 偏好设置"
    window.isReleasedWhenClosed = false

    super.init(window: window)
    buildContent()
    reloadControls()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show() {
    reloadControls()
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func buildContent() {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 16
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)

    configureControls()

    stack.addArrangedSubview(row(label: "完成后默认动作", control: defaultActionPopup))
    stack.addArrangedSubview(row(label: "截图快捷键", control: shortcutRecorderButton))
    stack.addArrangedSubview(row(label: "保存目录", control: saveDirectoryControls()))
    stack.addArrangedSubview(row(label: "开机自启", control: launchAtLoginSwitch))

    let note = NSTextField(labelWithString: "默认快捷键为 ⌘⇧2。OCR 只在点击「识别文字」时运行，截图内容不会上传。")
    note.textColor = .secondaryLabelColor
    note.font = .systemFont(ofSize: 12)
    note.maximumNumberOfLines = 2
    stack.addArrangedSubview(note)

    window?.contentView = stack
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor),
      stack.topAnchor.constraint(equalTo: window!.contentView!.topAnchor),
      stack.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor),
    ])
  }

  private func configureControls() {
    for action in ScreenshotDefaultAction.allCases {
      defaultActionPopup.addItem(withTitle: action.displayName)
      defaultActionPopup.lastItem?.representedObject = action.rawValue
    }
    defaultActionPopup.target = self
    defaultActionPopup.action = #selector(controlChanged)

    shortcutRecorderButton.onShortcutCaptured = { [weak self] shortcut in
      self?.shortcutCaptured(shortcut)
    }

    saveDirectoryField.lineBreakMode = .byTruncatingMiddle
    saveDirectoryField.textColor = .secondaryLabelColor

    launchAtLoginSwitch.target = self
    launchAtLoginSwitch.action = #selector(controlChanged)
  }

  private func reloadControls() {
    let config = preferencesStore.configuration
    defaultActionPopup.selectItem(withTitle: config.defaultAction.displayName)
    shortcutRecorderButton.shortcut = config.shortcut
    saveDirectoryField.stringValue = config.saveDirectoryPath
    launchAtLoginSwitch.state = config.launchAtLoginEnabled ? .on : .off
  }

  @objc private func controlChanged() {
    var config = preferencesStore.configuration

    if
      let rawValue = defaultActionPopup.selectedItem?.representedObject as? String,
      let action = ScreenshotDefaultAction(rawValue: rawValue)
    {
      config.defaultAction = action
    }

    config.launchAtLoginEnabled = launchAtLoginSwitch.state == .on
    preferencesStore.configuration = config
    applyLaunchAtLogin(config.launchAtLoginEnabled)
    onConfigurationChanged()
  }

  private func shortcutCaptured(_ shortcut: KeyboardShortcut) {
    var config = preferencesStore.configuration
    config.shortcut = shortcut
    preferencesStore.configuration = config
    reloadControls()
    onConfigurationChanged()
  }

  private func saveDirectoryControls() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8

    saveDirectoryField.translatesAutoresizingMaskIntoConstraints = false
    saveDirectoryField.widthAnchor.constraint(equalToConstant: 220).isActive = true
    stack.addArrangedSubview(saveDirectoryField)

    let button = NSButton(title: "选择", target: self, action: #selector(chooseSaveDirectory))
    button.bezelStyle = .rounded
    stack.addArrangedSubview(button)
    return stack
  }

  @objc private func chooseSaveDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: preferencesStore.configuration.saveDirectoryPath, isDirectory: true)

    guard panel.runModal() == .OK, let url = panel.url else {
      return
    }

    var config = preferencesStore.configuration
    config.saveDirectoryPath = url.path
    preferencesStore.configuration = config
    reloadControls()
    onConfigurationChanged()
  }

  private func applyLaunchAtLogin(_ enabled: Bool) {
    do {
      try LaunchAtLoginController.setEnabled(enabled)
    } catch {
      let alert = NSAlert()
      alert.messageText = "无法修改开机自启"
      alert.informativeText = error.localizedDescription
      alert.alertStyle = .warning
      alert.runModal()
    }
  }

  private func row(label: String, control: NSView) -> NSView {
    let labelField = NSTextField(labelWithString: label)
    labelField.translatesAutoresizingMaskIntoConstraints = false
    labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true

    let row = NSStackView()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10
    row.addArrangedSubview(labelField)

    control.translatesAutoresizingMaskIntoConstraints = false
    control.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
    row.addArrangedSubview(control)
    return row
  }
}

private final class ShortcutRecorderButton: NSButton {
  var shortcut: KeyboardShortcut? {
    didSet {
      updateTitle()
    }
  }
  var onShortcutCaptured: ((KeyboardShortcut) -> Void)?
  private var isRecording = false {
    didSet {
      updateTitle()
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    title = "点击录入"
    bezelStyle = .rounded
    target = self
    action = #selector(beginRecording)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func resignFirstResponder() -> Bool {
    isRecording = false
    return super.resignFirstResponder()
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }

    let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: Self.commandModifiers(from: event))
    guard shortcut.isValid else {
      NSSound.beep()
      return
    }

    self.shortcut = shortcut
    isRecording = false
    onShortcutCaptured?(shortcut)
  }

  @objc private func beginRecording() {
    isRecording = true
    window?.makeFirstResponder(self)
  }

  private func updateTitle() {
    if isRecording {
      title = "按下快捷键"
    } else if let shortcut {
      title = Self.displayString(for: shortcut)
    } else {
      title = "点击录入"
    }
  }

  private static func commandModifiers(from event: NSEvent) -> Set<CommandModifier> {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    var modifiers: Set<CommandModifier> = []
    if flags.contains(.command) { modifiers.insert(.command) }
    if flags.contains(.shift) { modifiers.insert(.shift) }
    if flags.contains(.option) { modifiers.insert(.option) }
    if flags.contains(.control) { modifiers.insert(.control) }
    if flags.contains(.function) { modifiers.insert(.function) }
    return modifiers
  }

  private static func displayString(for shortcut: KeyboardShortcut) -> String {
    let orderedModifiers: [(CommandModifier, String)] = [
      (.control, "⌃"),
      (.option, "⌥"),
      (.shift, "⇧"),
      (.command, "⌘"),
      (.function, "fn"),
    ]
    let modifierText = orderedModifiers
      .filter { shortcut.modifiers.contains($0.0) }
      .map(\.1)
      .joined()
    return modifierText + keyName(for: shortcut.keyCode)
  }

  private static func keyName(for keyCode: UInt16) -> String {
    let names: [UInt16: String] = [
      0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
      11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
      18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
      31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
      36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
      123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
    return names[keyCode] ?? "Key \(keyCode)"
  }
}

