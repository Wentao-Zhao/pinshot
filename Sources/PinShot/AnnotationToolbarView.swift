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
  private let toolboxButton = ToolbarIconButton(kind: .toolbox)
  private let textButton = ToolbarIconButton(kind: .text)
  private let mosaicButton = ToolbarIconButton(kind: .mosaic)
  private var popover: NSPopover?
  private var selectedTool: AnnotationTool = .move
  private var style = AnnotationStyle.default

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    material = .hudWindow
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 18
    layer?.masksToBounds = true
    layer?.borderWidth = 0.5
    layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func setSelectedTool(_ tool: AnnotationTool) {
    selectedTool = tool
    toolboxButton.isSelected = [.rectangle, .arrow, .pen].contains(tool)
    textButton.isSelected = tool == .text
    mosaicButton.isSelected = tool == .mosaic
  }

  func currentStyle() -> AnnotationStyle {
    style
  }

  private func buildContent() {
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 6
    addSubview(stack)

    configureToolboxButton()
    configureTextButton()
    configureMosaicButton()

    stack.addArrangedSubview(toolboxButton)
    stack.addArrangedSubview(textButton)
    stack.addArrangedSubview(mosaicButton)
    stack.addArrangedSubview(separator())
    addIconCommand(.undo, tooltip: "撤销")
    addIconCommand(.reset, tooltip: "重置")
    stack.addArrangedSubview(separator())
    addIconCommand(.pin, tooltip: "置顶")
    addIconCommand(.ocr, tooltip: "识别文字")

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
    ])
  }

  private func configureToolboxButton() {
    toolboxButton.toolTip = "工具箱"
    toolboxButton.target = self
    toolboxButton.action = #selector(showToolboxPopover)
  }

  private func configureTextButton() {
    textButton.toolTip = "文字"
    textButton.target = self
    textButton.action = #selector(showTextPopover)
  }

  private func configureMosaicButton() {
    mosaicButton.toolTip = "马赛克"
    mosaicButton.target = self
    mosaicButton.action = #selector(selectMosaic)
  }

  private func addIconCommand(
    _ command: AnnotationToolbarCommand,
    tooltip: String
  ) {
    let kind: ToolbarIconButton.Kind
    switch command {
    case .undo:
      kind = .undo
    case .reset:
      kind = .reset
    case .pin:
      kind = .pin
    case .ocr:
      kind = .ocr
    default:
      kind = .toolbox
    }
    let button = ToolbarIconButton(kind: kind)
    button.toolTip = tooltip
    button.identifier = NSUserInterfaceItemIdentifier(commandKey(for: command))
    button.target = self
    button.action = #selector(commandButtonClicked(_:))
    stack.addArrangedSubview(button)
  }

  private func separator() -> NSView {
    let view = ToolbarSeparatorView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 1).isActive = true
    view.heightAnchor.constraint(equalToConstant: 20).isActive = true
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

  private func showPopover(relativeTo button: NSView, content: NSView) {
    popover?.close()
    let controller = NSViewController()
    controller.view = content
    let popover = NSPopover()
    popover.behavior = .transient
    popover.appearance = NSAppearance(named: .vibrantDark)
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
    super.init(frame: NSRect(x: 0, y: 0, width: 224, height: 126))
    wantsLayer = true
    layer?.cornerRadius = 14
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
    stack.spacing = 9
    stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    addSubview(stack)

    let toolStack = NSStackView()
    toolStack.orientation = .horizontal
    toolStack.spacing = 8
    toolStack.addArrangedSubview(toolButton(.rectangle, kind: .rectangle, selectedTool: selectedTool))
    toolStack.addArrangedSubview(toolButton(.arrow, kind: .arrow, selectedTool: selectedTool))
    toolStack.addArrangedSubview(toolButton(.pen, kind: .pen, selectedTool: selectedTool))
    stack.addArrangedSubview(toolStack)

    widthSlider.doubleValue = style.strokeWidth
    widthSlider.target = self
    widthSlider.action = #selector(widthChanged)
    widthSlider.widthAnchor.constraint(equalToConstant: 132).isActive = true
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
    kind: ToolbarIconButton.Kind,
    selectedTool: AnnotationTool
  ) -> ToolbarIconButton {
    let button = ToolbarIconButton(kind: kind, size: NSSize(width: 48, height: 36))
    button.isSelected = tool == selectedTool
    button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
    button.target = self
    button.action = #selector(toolChanged(_:))
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
    super.init(frame: NSRect(x: 0, y: 0, width: 218, height: 88))
    wantsLayer = true
    layer?.cornerRadius = 14
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
    stack.spacing = 9
    stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    addSubview(stack)

    sizeSlider.doubleValue = style.fontSize
    sizeSlider.target = self
    sizeSlider.action = #selector(sizeChanged)
    sizeSlider.widthAnchor.constraint(equalToConstant: 132).isActive = true
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

private final class ToolbarSeparatorView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    NSColor.white.withAlphaComponent(0.16).setFill()
    bounds.insetBy(dx: 0, dy: 2).fill()
  }
}

private final class ToolbarIconButton: NSButton {
  enum Kind {
    case toolbox
    case text
    case mosaic
    case rectangle
    case arrow
    case pen
    case undo
    case reset
    case pin
    case ocr
  }

  var isSelected = false {
    didSet {
      needsDisplay = true
    }
  }

  private let kind: Kind
  private let preferredSize: NSSize
  private var trackingAreaRef: NSTrackingArea?
  private var isHovered = false {
    didSet {
      needsDisplay = true
    }
  }

  init(kind: Kind, size: NSSize = NSSize(width: 40, height: 32)) {
    self.kind = kind
    self.preferredSize = size
    super.init(frame: NSRect(origin: .zero, size: size))
    title = ""
    isBordered = false
    bezelStyle = .regularSquare
    focusRingType = .none
    setButtonType(.momentaryChange)
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: size.width).isActive = true
    heightAnchor.constraint(equalToConstant: size.height).isActive = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var intrinsicContentSize: NSSize {
    preferredSize
  }

  override func updateTrackingAreas() {
    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    trackingAreaRef = trackingArea
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 2, dy: 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
    let pressed = isHighlighted || isSelected
    let fillAlpha: CGFloat
    if pressed {
      fillAlpha = 0.18
    } else if isHovered {
      fillAlpha = 0.08
    } else {
      fillAlpha = 0
    }
    if fillAlpha > 0 {
      NSColor.white.withAlphaComponent(fillAlpha).setFill()
      path.fill()
    }

    if pressed {
      NSColor.white.withAlphaComponent(0.18).setStroke()
      path.lineWidth = 1
      path.stroke()
    }

    drawIcon(in: rect.insetBy(dx: 9, dy: 7), color: NSColor.white.withAlphaComponent(pressed ? 0.95 : 0.78))
  }

  private func drawIcon(in rect: NSRect, color: NSColor) {
    switch kind {
    case .toolbox:
      drawPen(in: rect, color: color)
    case .text:
      drawTextIcon(in: rect, color: color)
    case .mosaic:
      drawMosaic(in: rect, color: color)
    case .rectangle:
      drawRectangle(in: rect, color: color)
    case .arrow:
      drawArrow(in: rect, color: color)
    case .pen:
      drawFreePen(in: rect, color: color)
    case .undo:
      drawUndo(in: rect, color: color)
    case .reset:
      drawReset(in: rect, color: color)
    case .pin:
      drawPin(in: rect, color: color)
    case .ocr:
      drawOCR(in: rect, color: color)
    }
  }

  private func drawRectangle(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 3), xRadius: 3, yRadius: 3)
    path.lineWidth = 2.4
    path.stroke()
  }

  private func drawArrow(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX + 2, y: rect.minY + 3))
    path.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - 3))
    path.move(to: NSPoint(x: rect.maxX - 3, y: rect.maxY - 10))
    path.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - 3))
    path.line(to: NSPoint(x: rect.maxX - 10, y: rect.maxY - 4))
    path.lineWidth = 2.5
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
  }

  private func drawPen(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.midX - 5, y: rect.minY + 2))
    path.line(to: NSPoint(x: rect.midX, y: rect.maxY - 2))
    path.line(to: NSPoint(x: rect.midX + 5, y: rect.minY + 2))
    path.move(to: NSPoint(x: rect.midX - 3, y: rect.minY + 7))
    path.line(to: NSPoint(x: rect.midX + 3, y: rect.minY + 7))
    path.lineWidth = 2.4
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
  }

  private func drawFreePen(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX + 1, y: rect.minY + 5))
    path.curve(
      to: NSPoint(x: rect.maxX - 1, y: rect.midY),
      controlPoint1: NSPoint(x: rect.minX + 7, y: rect.maxY - 2),
      controlPoint2: NSPoint(x: rect.midX, y: rect.minY)
    )
    path.lineWidth = 2.6
    path.lineCapStyle = .round
    path.stroke()
  }

  private func drawTextIcon(in rect: NSRect, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: min(rect.height + 1, 20), weight: .bold),
      .foregroundColor: color,
    ]
    let text = "T"
    let size = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
  }

  private func drawMosaic(in rect: NSRect, color: NSColor) {
    let cols = 3
    let rows = 3
    let gap: CGFloat = 1.6
    let cellWidth = (rect.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
    let cellHeight = (rect.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
    for row in 0..<rows {
      for col in 0..<cols {
        let alpha: CGFloat = (row + col).isMultiple(of: 2) ? 0.88 : 0.46
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(
          roundedRect: NSRect(
            x: rect.minX + CGFloat(col) * (cellWidth + gap),
            y: rect.minY + CGFloat(row) * (cellHeight + gap),
            width: cellWidth,
            height: cellHeight
          ),
          xRadius: 1.5,
          yRadius: 1.5
        ).fill()
      }
    }
  }

  private func drawUndo(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.appendArc(
      withCenter: NSPoint(x: rect.midX + 1, y: rect.midY),
      radius: min(rect.width, rect.height) * 0.34,
      startAngle: 315,
      endAngle: 115,
      clockwise: false
    )
    path.move(to: NSPoint(x: rect.minX + 4, y: rect.midY + 3))
    path.line(to: NSPoint(x: rect.minX + 3, y: rect.midY + 10))
    path.line(to: NSPoint(x: rect.minX + 10, y: rect.midY + 8))
    path.lineWidth = 2.3
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
  }

  private func drawReset(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.appendArc(
      withCenter: NSPoint(x: rect.midX, y: rect.midY),
      radius: min(rect.width, rect.height) * 0.34,
      startAngle: 35,
      endAngle: 335,
      clockwise: false
    )
    path.move(to: NSPoint(x: rect.maxX - 5, y: rect.midY + 8))
    path.line(to: NSPoint(x: rect.maxX - 2, y: rect.midY + 1))
    path.line(to: NSPoint(x: rect.maxX - 10, y: rect.midY + 2))
    path.lineWidth = 2.3
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
  }

  private func drawPin(in rect: NSRect, color: NSColor) {
    color.setFill()
    color.setStroke()
    let head = NSBezierPath(roundedRect: NSRect(x: rect.midX - 5, y: rect.maxY - 9, width: 10, height: 7), xRadius: 2, yRadius: 2)
    head.fill()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.midX, y: rect.maxY - 9))
    path.line(to: NSPoint(x: rect.midX, y: rect.minY + 5))
    path.move(to: NSPoint(x: rect.midX - 6, y: rect.midY))
    path.line(to: NSPoint(x: rect.midX + 6, y: rect.midY))
    path.move(to: NSPoint(x: rect.midX, y: rect.minY + 5))
    path.line(to: NSPoint(x: rect.midX + 4, y: rect.minY))
    path.lineWidth = 2.2
    path.lineCapStyle = .round
    path.stroke()
  }

  private func drawOCR(in rect: NSRect, color: NSColor) {
    color.setStroke()
    let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 3), xRadius: 3, yRadius: 3)
    frame.lineWidth = 2
    frame.stroke()

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .bold),
      .foregroundColor: color,
    ]
    let text = "A"
    let size = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
  }
}
