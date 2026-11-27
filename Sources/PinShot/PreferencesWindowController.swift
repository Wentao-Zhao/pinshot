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
      contentRect: NSRect(x: 0, y: 0, width: 540, height: 430),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "PinShot 设置"
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
    configureControls()
    let root = NSView()
    window?.contentView = root

    let heading = NSTextField(labelWithString: "PinShot")
    heading.font = .systemFont(ofSize: 22, weight: .semibold)
    let subtitle = NSTextField(labelWithString: "截图、标注与置顶，随手完成。")
    subtitle.textColor = .secondaryLabelColor
    subtitle.font = .systemFont(ofSize: 12)
    let header = NSStackView(views: [heading, subtitle])
    header.orientation = .vertical
    header.alignment = .leading
    header.spacing = 4

    let capture = section("截图操作", rows: [
      row(label: "截图快捷键", control: shortcutRecorderButton),
      row(label: "完成后", control: defaultActionPopup),
    ])
    let files = section("文件与启动", rows: [
      row(label: "保存位置", control: saveDirectoryControls()),
      row(label: "登录时启动", control: launchAtLoginSwitch),
    ])
    let note = NSTextField(wrappingLabelWithString:
      "OCR 在本地完成，截图内容不会上传。置顶图片支持拖动移动、滚轮缩放。")
    note.textColor = .secondaryLabelColor
    note.font = .systemFont(ofSize: 11)
    note.maximumNumberOfLines = 2

    let stack = NSStackView(views: [header, capture, files, note])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 18
    root.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
      stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
      stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
      capture.widthAnchor.constraint(equalTo: stack.widthAnchor),
      files.widthAnchor.constraint(equalTo: stack.widthAnchor),
      note.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  private func section(_ title: String, rows: [NSView]) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.textColor = .secondaryLabelColor
    let box = NSBox()
    box.boxType = .custom
    box.titlePosition = .noTitle
    box.fillColor = .controlBackgroundColor
    box.borderColor = .separatorColor
    box.borderWidth = 0.5
    box.cornerRadius = 10
    box.contentViewMargins = NSSize(width: 14, height: 6)
    box.translatesAutoresizingMaskIntoConstraints = false
    box.heightAnchor.constraint(equalToConstant: CGFloat(rows.count * 42 + 12)).isActive = true
    let content = NSStackView(views: rows)
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 0
    content.translatesAutoresizingMaskIntoConstraints = false
    let container = box.contentView!
    container.addSubview(content)
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      content.topAnchor.constraint(equalTo: container.topAnchor),
      content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    for row in rows {
      row.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
      row.heightAnchor.constraint(equalToConstant: 42).isActive = true
    }
    let section = NSStackView(views: [label, box])
    section.orientation = .vertical
    section.alignment = .leading
    section.spacing = 8
    box.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
    return section
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
    saveDirectoryField.widthAnchor.constraint(equalToConstant: 194).isActive = true
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
    labelField.widthAnchor.constraint(equalToConstant: 110).isActive = true
    labelField.font = .systemFont(ofSize: 13)

    let row = NSStackView()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10
    row.addArrangedSubview(labelField)
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    row.addArrangedSubview(spacer)

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

