import AppKit
import PinShotCore

enum AnnotationToolbarCommand {
  case tool(AnnotationTool)
  case undo
  case redo
  case clear
  case finishDefault
  case copy
  case save
  case pin
  case ocr
  case cancel
}

final class AnnotationToolbarView: NSVisualEffectView {
  var onCommand: ((AnnotationToolbarCommand) -> Void)?
  private var toolButtons: [AnnotationTool: NSButton] = [:]
  private var selectedTool: AnnotationTool = .move

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    material = .hudWindow
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 12
    layer?.masksToBounds = true
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func setSelectedTool(_ tool: AnnotationTool) {
    selectedTool = tool
    for (candidate, button) in toolButtons {
      button.state = candidate == tool ? .on : .off
    }
  }

  private func buildContent() {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 6
    addSubview(stack)

    addTool(.move, title: "移动", to: stack)
    addTool(.rectangle, title: "框", to: stack)
    addTool(.arrow, title: "箭头", to: stack)
    addTool(.pen, title: "画笔", to: stack)
    addTool(.text, title: "文字", to: stack)
    addTool(.mosaic, title: "马赛克", to: stack)
    stack.addArrangedSubview(separator())
    addCommand(.undo, title: "撤销", to: stack)
    addCommand(.redo, title: "重做", to: stack)
    addCommand(.clear, title: "清空", to: stack)
    stack.addArrangedSubview(separator())
    addCommand(.copy, title: "复制", to: stack)
    addCommand(.save, title: "保存", to: stack)
    addCommand(.pin, title: "置顶", to: stack)
    addCommand(.ocr, title: "识别", to: stack)
    addCommand(.finishDefault, title: "完成", to: stack)
    addCommand(.cancel, title: "取消", to: stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
    ])

    setSelectedTool(.move)
  }

  private func addTool(_ tool: AnnotationTool, title: String, to stack: NSStackView) {
    let button = button(title: title)
    button.setButtonType(.toggle)
    button.target = self
    button.action = #selector(toolButtonClicked(_:))
    button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
    toolButtons[tool] = button
    stack.addArrangedSubview(button)
  }

  private func addCommand(_ command: AnnotationToolbarCommand, title: String, to stack: NSStackView) {
    let button = button(title: title)
    button.target = self
    button.action = #selector(commandButtonClicked(_:))
    button.identifier = NSUserInterfaceItemIdentifier(commandKey(for: command))
    stack.addArrangedSubview(button)
  }

  private func button(title: String) -> NSButton {
    let button = NSButton(title: title, target: nil, action: nil)
    button.bezelStyle = .rounded
    button.controlSize = .small
    button.font = .systemFont(ofSize: 12, weight: .medium)
    return button
  }

  private func separator() -> NSView {
    let view = NSBox()
    view.boxType = .separator
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 1).isActive = true
    view.heightAnchor.constraint(equalToConstant: 18).isActive = true
    return view
  }

  @objc private func toolButtonClicked(_ sender: NSButton) {
    guard
      let rawValue = sender.identifier?.rawValue,
      let tool = AnnotationTool(rawValue: rawValue)
    else {
      return
    }
    setSelectedTool(tool)
    onCommand?(.tool(tool))
  }

  @objc private func commandButtonClicked(_ sender: NSButton) {
    guard let rawValue = sender.identifier?.rawValue else {
      return
    }
    onCommand?(command(for: rawValue))
  }

  private func commandKey(for command: AnnotationToolbarCommand) -> String {
    switch command {
    case .undo: "undo"
    case .redo: "redo"
    case .clear: "clear"
    case .finishDefault: "finishDefault"
    case .copy: "copy"
    case .save: "save"
    case .pin: "pin"
    case .ocr: "ocr"
    case .cancel: "cancel"
    case .tool(let tool): tool.rawValue
    }
  }

  private func command(for key: String) -> AnnotationToolbarCommand {
    switch key {
    case "undo": .undo
    case "redo": .redo
    case "clear": .clear
    case "finishDefault": .finishDefault
    case "copy": .copy
    case "save": .save
    case "pin": .pin
    case "ocr": .ocr
    case "cancel": .cancel
    default: .cancel
    }
  }
}
