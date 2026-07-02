import AppKit
import PinShotCore

enum AnnotationToolbarCommand {
  case tool(AnnotationTool)
  case style(AnnotationStyle)
  case undo
  case reset
  case pin
  case ocr
}

final class AnnotationToolbarView: NSVisualEffectView {
  var onCommand: ((AnnotationToolbarCommand) -> Void)?

  private let stack = NSStackView()
  private let toolboxButton = NSButton()
  private let textButton = NSButton()
  private let mosaicButton = NSButton()
  private var popover: NSPopover?
  private var selectedTool: AnnotationTool = .move
  private var style = AnnotationStyle.default

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    material = .hudWindow
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 14
    layer?.masksToBounds = true
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func setSelectedTool(_ tool: AnnotationTool) {
    selectedTool = tool
    toolboxButton.state = [.rectangle, .arrow, .pen].contains(tool) ? .on : .off
    textButton.state = tool == .text ? .on : .off
    mosaicButton.state = tool == .mosaic ? .on : .off
  }

  func currentStyle() -> AnnotationStyle {
    style
  }

  private func buildContent() {
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    addSubview(stack)

    configureToolboxButton()
    configureTextButton()
    configureMosaicButton()

    stack.addArrangedSubview(toolboxButton)
    stack.addArrangedSubview(textButton)
    stack.addArrangedSubview(mosaicButton)
    stack.addArrangedSubview(separator())
    addIconCommand(.undo, symbolName: "arrow.uturn.backward", fallback: "↶", tooltip: "撤销")
    addIconCommand(.reset, symbolName: "arrow.counterclockwise", fallback: "重置", tooltip: "重置")
    stack.addArrangedSubview(separator())
    addIconCommand(.pin, symbolName: "pin", fallback: "置顶", tooltip: "置顶")
    addIconCommand(.ocr, symbolName: "text.viewfinder", fallback: "OCR", tooltip: "识别文字")

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
    ])
  }

  private func configureToolboxButton() {
    configureButton(toolboxButton, title: "工具", symbolName: "pencil.tip", fallback: "✎")
    toolboxButton.target = self
    toolboxButton.action = #selector(showToolboxPopover)
  }

  private func configureTextButton() {
    configureButton(textButton, title: "T", symbolName: "textformat", fallback: "T")
    textButton.font = .systemFont(ofSize: 15, weight: .bold)
    textButton.target = self
    textButton.action = #selector(showTextPopover)
  }

  private func configureMosaicButton() {
    configureButton(mosaicButton, title: "▦", symbolName: "checkerboard.rectangle", fallback: "▦")
    mosaicButton.target = self
    mosaicButton.action = #selector(selectMosaic)
  }

  private func configureButton(_ button: NSButton, title: String, symbolName: String, fallback: String) {
    button.title = title
    button.bezelStyle = .rounded
    button.controlSize = .regular
    button.setButtonType(.toggle)
    button.font = .systemFont(ofSize: 13, weight: .semibold)
    button.imagePosition = .imageOnly
    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
    if button.image == nil {
      button.title = fallback
      button.imagePosition = .noImage
    }
    button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
  }

  private func addIconCommand(
    _ command: AnnotationToolbarCommand,
    symbolName: String,
    fallback: String,
    tooltip: String
  ) {
    let button = NSButton()
    button.bezelStyle = .rounded
    button.controlSize = .regular
    button.font = .systemFont(ofSize: 13, weight: .semibold)
    button.toolTip = tooltip
    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
    if button.image != nil {
      button.imagePosition = .imageOnly
      button.title = tooltip
    } else {
      button.title = fallback
    }
    button.identifier = NSUserInterfaceItemIdentifier(commandKey(for: command))
    button.target = self
    button.action = #selector(commandButtonClicked(_:))
    button.widthAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
    stack.addArrangedSubview(button)
  }

  private func separator() -> NSView {
    let view = NSBox()
    view.boxType = .separator
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 1).isActive = true
    view.heightAnchor.constraint(equalToConstant: 18).isActive = true
    return view
  }

  @objc private func showToolboxPopover() {
    showPopover(
      relativeTo: toolboxButton,
      content: ToolOptionsView(
        selectedTool: selectedTool,
        style: style,
        onToolChanged: { [weak self] tool in
          self?.select(tool)
        },
        onStyleChanged: { [weak self] style in
          self?.updateStyle(style)
        }
      )
    )
  }

  @objc private func showTextPopover() {
    select(.text)
    showPopover(
      relativeTo: textButton,
      content: TextOptionsView(
        style: style,
        onStyleChanged: { [weak self] style in
          self?.updateStyle(style)
        }
      )
    )
  }

  @objc private func selectMosaic() {
    select(.mosaic)
  }

  @objc private func commandButtonClicked(_ sender: NSButton) {
    guard let rawValue = sender.identifier?.rawValue else {
      return
    }

    switch rawValue {
    case "undo":
      onCommand?(.undo)
    case "reset":
      onCommand?(.reset)
    case "pin":
      onCommand?(.pin)
    case "ocr":
      onCommand?(.ocr)
    default:
      break
    }
  }

  private func select(_ tool: AnnotationTool) {
    selectedTool = tool
    setSelectedTool(tool)
    onCommand?(.tool(tool))
  }

  private func updateStyle(_ style: AnnotationStyle) {
    self.style = style
    onCommand?(.style(style))
  }

  private func showPopover(relativeTo button: NSButton, content: NSView) {
    popover?.close()
    let controller = NSViewController()
    controller.view = content
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = controller
    self.popover = popover
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
  }

  private func commandKey(for command: AnnotationToolbarCommand) -> String {
    switch command {
    case .undo:
      "undo"
    case .reset:
      "reset"
    case .pin:
      "pin"
    case .ocr:
      "ocr"
    case .tool(let tool):
      tool.rawValue
    case .style:
      "style"
    }
  }
}
private final class ToolOptionsView: NSView {
  private var style: AnnotationStyle
  private let onToolChanged: (AnnotationTool) -> Void
  private let onStyleChanged: (AnnotationStyle) -> Void
  private let widthSlider = NSSlider(value: 4, minValue: 1, maxValue: 12, target: nil, action: nil)
  private let colorWell = NSColorWell(frame: .zero)

  init(
    selectedTool: AnnotationTool,
    style: AnnotationStyle,
    onToolChanged: @escaping (AnnotationTool) -> Void,
    onStyleChanged: @escaping (AnnotationStyle) -> Void
  ) {
    self.style = style
    self.onToolChanged = onToolChanged
    self.onStyleChanged = onStyleChanged
    super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 126))
    buildContent(selectedTool: selectedTool)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  private func buildContent(selectedTool: AnnotationTool) {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    addSubview(stack)

    let toolStack = NSStackView()
    toolStack.orientation = .horizontal
    toolStack.spacing = 8
    toolStack.addArrangedSubview(toolButton(.rectangle, symbol: "rectangle", fallback: "□", selectedTool: selectedTool))
    toolStack.addArrangedSubview(toolButton(.arrow, symbol: "arrow.up.right", fallback: "↗", selectedTool: selectedTool))
    toolStack.addArrangedSubview(toolButton(.pen, symbol: "pencil.line", fallback: "✎", selectedTool: selectedTool))
    stack.addArrangedSubview(toolStack)

    widthSlider.doubleValue = style.strokeWidth
    widthSlider.target = self
    widthSlider.action = #selector(widthChanged)
    widthSlider.widthAnchor.constraint(equalToConstant: 146).isActive = true
    stack.addArrangedSubview(optionRow(title: "粗细", control: widthSlider))

    colorWell.color = style.strokeColor.nsColor
    colorWell.target = self
    colorWell.action = #selector(colorChanged)
    stack.addArrangedSubview(optionRow(title: "颜色", control: colorWell))

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func toolButton(
    _ tool: AnnotationTool,
    symbol: String,
    fallback: String,
    selectedTool: AnnotationTool
  ) -> NSButton {
    let button = NSButton()
    button.bezelStyle = .rounded
    button.setButtonType(.toggle)
    button.state = tool == selectedTool ? .on : .off
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tool.rawValue)
    if button.image != nil {
      button.imagePosition = .imageOnly
      button.title = tool.rawValue
    } else {
      button.title = fallback
    }
    button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
    button.target = self
    button.action = #selector(toolChanged(_:))
    button.widthAnchor.constraint(equalToConstant: 46).isActive = true
    return button
  }

  private func optionRow(title: String, control: NSView) -> NSView {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    let label = NSTextField(labelWithString: title)
    label.textColor = .secondaryLabelColor
    label.font = .systemFont(ofSize: 12)
    label.widthAnchor.constraint(equalToConstant: 34).isActive = true
    row.addArrangedSubview(label)
    row.addArrangedSubview(control)
    return row
  }

  @objc private func toolChanged(_ sender: NSButton) {
    guard
      let rawValue = sender.identifier?.rawValue,
      let tool = AnnotationTool(rawValue: rawValue)
    else {
      return
    }
    onToolChanged(tool)
  }

  @objc private func widthChanged() {
    style.strokeWidth = widthSlider.doubleValue
    onStyleChanged(style)
  }

  @objc private func colorChanged() {
    style.strokeColor = AnnotationColor(nsColor: colorWell.color)
    onStyleChanged(style)
  }
}

private final class TextOptionsView: NSView {
  private var style: AnnotationStyle
  private let onStyleChanged: (AnnotationStyle) -> Void
  private let sizeSlider = NSSlider(value: 24, minValue: 12, maxValue: 56, target: nil, action: nil)
  private let colorWell = NSColorWell(frame: .zero)

  init(style: AnnotationStyle, onStyleChanged: @escaping (AnnotationStyle) -> Void) {
    self.style = style
    self.onStyleChanged = onStyleChanged
    super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 92))
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  private func buildContent() {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    addSubview(stack)

    sizeSlider.doubleValue = style.fontSize
    sizeSlider.target = self
    sizeSlider.action = #selector(sizeChanged)
    sizeSlider.widthAnchor.constraint(equalToConstant: 146).isActive = true
    stack.addArrangedSubview(optionRow(title: "字号", control: sizeSlider))

    colorWell.color = style.textColor.nsColor
    colorWell.target = self
    colorWell.action = #selector(colorChanged)
    stack.addArrangedSubview(optionRow(title: "颜色", control: colorWell))

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func optionRow(title: String, control: NSView) -> NSView {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    let label = NSTextField(labelWithString: title)
    label.textColor = .secondaryLabelColor
    label.font = .systemFont(ofSize: 12)
    label.widthAnchor.constraint(equalToConstant: 34).isActive = true
    row.addArrangedSubview(label)
    row.addArrangedSubview(control)
    return row
  }

  @objc private func sizeChanged() {
    style.fontSize = sizeSlider.doubleValue
    onStyleChanged(style)
  }

  @objc private func colorChanged() {
    style.textColor = AnnotationColor(nsColor: colorWell.color)
    onStyleChanged(style)
  }
}

private extension AnnotationColor {
  var nsColor: NSColor {
    NSColor(
      calibratedRed: CGFloat(red),
      green: CGFloat(green),
      blue: CGFloat(blue),
      alpha: CGFloat(alpha)
    )
  }

  init(nsColor: NSColor) {
    let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
    self.init(
      red: Double(color.redComponent),
      green: Double(color.greenComponent),
      blue: Double(color.blueComponent),
      alpha: Double(color.alphaComponent)
    )
  }
}
