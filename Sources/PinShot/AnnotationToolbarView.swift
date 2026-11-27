import AppKit
import PinShotCore

enum AnnotationToolbarCommand {
  case tool(AnnotationTool)
  case style(AnnotationStyle)
  case undo, redo, reset, pin, ocr, cancel, copy
}

final class AnnotationToolbarView: PinShotSurfaceView {
  var onCommand: ((AnnotationToolbarCommand) -> Void)?

  private let stack = NSStackView()
  private var drawingButtons: [AnnotationTool: ToolbarIconButton] = [:]
  private let styleButton = ToolbarIconButton(symbol: "circle.fill", label: "线条样式")
  private var popover: NSPopover?
  private var style = AnnotationStyle.default

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  func setSelectedTool(_ tool: AnnotationTool) {
    for (kind, button) in drawingButtons { button.isSelected = kind == tool }
  }

  func currentStyle() -> AnnotationStyle { style }

  func closePopover() {
    popover?.close()
    popover = nil
  }

  private func buildContent() {
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 3
    addSubview(stack)

    styleButton.swatchColor = style.strokeColor.nsColor
    styleButton.target = self
    styleButton.action = #selector(showLineStyle)

    for (tool, symbol, label) in [
      (AnnotationTool.rectangle, "rectangle", "矩形"),
      (.arrow, "arrow.up.right", "箭头"),
      (.pen, "pencil", "画笔"),
      (.text, "T", "文字"),
      (.mosaic, "square.grid.3x3.fill", "马赛克"),
    ] {
      let button = ToolbarIconButton(symbol: symbol, label: label)
      button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
      button.target = self
      button.action = #selector(toolClicked(_:))
      drawingButtons[tool] = button
      if tool == .mosaic { stack.addArrangedSubview(styleButton) }
      stack.addArrangedSubview(button)
    }
    addSeparator()
    addCommand("arrow.uturn.backward", "撤销", "undo")
    addCommand("arrow.uturn.forward", "重做", "redo")
    addCommand("trash", "清空标注", "reset")
    addSeparator()
    addCommand("pin", "置顶", "pin")
    addCommand("text.viewfinder", "识别文字", "ocr")
    addSeparator()
    addCommand("xmark", "取消截图", "cancel")
    addCommand("square.on.square", "复制截图", "copy")

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
    ])
  }

  private func addCommand(_ symbol: String, _ label: String, _ key: String) {
    let button = ToolbarIconButton(symbol: symbol, label: label)
    button.identifier = NSUserInterfaceItemIdentifier(key)
    button.target = self
    button.action = #selector(commandClicked(_:))
    stack.addArrangedSubview(button)
  }

  private func addSeparator() {
    let separator = NSBox()
    separator.boxType = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
    separator.heightAnchor.constraint(equalToConstant: 18).isActive = true
    stack.addArrangedSubview(separator)
    stack.setCustomSpacing(7, after: separator)
    if stack.arrangedSubviews.count > 1 {
      stack.setCustomSpacing(7, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
    }
  }

  @objc private func toolClicked(_ sender: NSButton) {
    guard let key = sender.identifier?.rawValue, let tool = AnnotationTool(rawValue: key) else { return }
    setSelectedTool(tool)
    onCommand?(.tool(tool))
    if tool == .text { showOptions(relativeTo: sender, editsText: true) }
  }

  @objc private func showLineStyle() {
    showOptions(relativeTo: styleButton, editsText: false)
  }

  private func showOptions(relativeTo button: NSView, editsText: Bool) {
    closePopover()
    let controller = NSViewController()
    controller.view = AnnotationStyleOptionsView(style: style, editsText: editsText) { [weak self] style in
      self?.style = style
      self?.styleButton.swatchColor = style.strokeColor.nsColor
      self?.onCommand?(.style(style))
    }
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = controller
    self.popover = popover
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
  }

  @objc private func commandClicked(_ sender: NSButton) {
    let command: AnnotationToolbarCommand
    switch sender.identifier?.rawValue {
    case "undo": command = .undo
    case "redo": command = .redo
    case "reset": command = .reset
    case "pin": command = .pin
    case "ocr": command = .ocr
    case "cancel": command = .cancel
    case "copy": command = .copy
    default: return
    }
    onCommand?(command)
  }
}

private final class ToolbarIconButton: NSButton {
  var isSelected = false { didSet { needsDisplay = true } }
  var swatchColor: NSColor? { didSet { needsDisplay = true } }
  private var isHovered = false { didSet { needsDisplay = true } }
  private var pointerTracking: NSTrackingArea?

  init(symbol: String, label: String) {
    super.init(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
    if symbol == "T" {
      let glyph = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3, y: 15))
        path.line(to: NSPoint(x: 15, y: 15))
        path.move(to: NSPoint(x: 9, y: 15))
        path.line(to: NSPoint(x: 9, y: 2))
        path.lineWidth = 1.8
        NSColor.black.setStroke()
        path.stroke()
        return true
      }
      glyph.isTemplate = true
      image = glyph
    } else {
      image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
        .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
    }
    imagePosition = .imageOnly
    imageScaling = .scaleProportionallyDown
    isBordered = false
    setButtonType(.momentaryChange)
    focusRingType = .none
    title = ""
    toolTip = label
    setAccessibilityLabel(label)
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 32), heightAnchor.constraint(equalToConstant: 32),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override var intrinsicContentSize: NSSize { NSSize(width: 32, height: 32) }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let pointerTracking { removeTrackingArea(pointerTracking) }
    let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                              owner: self, userInfo: nil)
    addTrackingArea(area)
    pointerTracking = area
  }

  override func mouseEntered(with event: NSEvent) { isHovered = true }
  override func mouseExited(with event: NSEvent) { isHovered = false }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    let selected = isSelected || isHighlighted
    if selected || isHovered {
      (selected ? PinShotTheme.accent.withAlphaComponent(0.16)
                : NSColor.labelColor.withAlphaComponent(0.07)).setFill()
      NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7).fill()
    }
    contentTintColor = swatchColor ?? (selected ? PinShotTheme.accent : .labelColor)
    super.draw(dirtyRect)
  }
}

final class AnnotationStyleOptionsView: NSView {
  private var style: AnnotationStyle
  private let editsText: Bool
  private let onStyleChanged: (AnnotationStyle) -> Void
  private let slider = NSSlider()
  private let colorWell = NSColorWell()
  private var swatches: [ColorSwatchButton] = []

  init(style: AnnotationStyle, editsText: Bool, onStyleChanged: @escaping (AnnotationStyle) -> Void) {
    self.style = style
    self.editsText = editsText
    self.onStyleChanged = onStyleChanged
    super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 108))
    buildContent()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  private func buildContent() {
    let palette = NSStackView()
    palette.orientation = .horizontal
    palette.spacing = 7
    for color in [NSColor.red, .orange, .yellow, .green, .blue, .black, .white] {
      let swatch = ColorSwatchButton(color: color)
      swatch.target = self
      swatch.action = #selector(colorSelected(_:))
      palette.addArrangedSubview(swatch)
      swatches.append(swatch)
    }
    colorWell.color = (editsText ? style.textColor : style.strokeColor).nsColor
    colorWell.target = self
    colorWell.action = #selector(colorChanged)
    colorWell.translatesAutoresizingMaskIntoConstraints = false
    colorWell.widthAnchor.constraint(equalToConstant: 28).isActive = true
    colorWell.heightAnchor.constraint(equalToConstant: 25).isActive = true
    colorWell.setAccessibilityLabel("自定义颜色")
    palette.addArrangedSubview(colorWell)

    slider.minValue = editsText ? 12 : 1
    slider.maxValue = editsText ? 56 : 12
    slider.doubleValue = editsText ? style.fontSize : style.strokeWidth
    slider.target = self
    slider.action = #selector(sizeChanged)
    slider.setAccessibilityLabel(editsText ? "文字字号" : "线条粗细")
    slider.widthAnchor.constraint(equalToConstant: 188).isActive = true

    let stack = NSStackView(views: [row("颜色", palette), row(editsText ? "字号" : "线宽", slider)])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    updateSwatches()
  }

  private func row(_ title: String, _ control: NSView) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 12)
    label.textColor = .secondaryLabelColor
    label.widthAnchor.constraint(equalToConstant: 30).isActive = true
    let row = NSStackView(views: [label, control])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    return row
  }

  @objc private func sizeChanged() {
    if editsText { style.fontSize = slider.doubleValue } else { style.strokeWidth = slider.doubleValue }
    onStyleChanged(style)
  }

  @objc private func colorSelected(_ sender: ColorSwatchButton) {
    colorWell.color = sender.color
    colorChanged()
  }

  @objc private func colorChanged() {
    let color = AnnotationColor(nsColor: colorWell.color)
    if editsText { style.textColor = color } else { style.strokeColor = color }
    updateSwatches()
    onStyleChanged(style)
  }

  private func updateSwatches() {
    for swatch in swatches {
      let lhs = swatch.color.usingColorSpace(.sRGB)!
      let rhs = colorWell.color.usingColorSpace(.sRGB)!
      swatch.state = abs(lhs.redComponent - rhs.redComponent) + abs(lhs.greenComponent - rhs.greenComponent)
        + abs(lhs.blueComponent - rhs.blueComponent) < 0.04 ? .on : .off
      swatch.needsDisplay = true
    }
  }
}

private final class ColorSwatchButton: NSButton {
  let color: NSColor
  override var allowsVibrancy: Bool { false }

  init(color: NSColor) {
    self.color = color
    super.init(frame: NSRect(x: 0, y: 0, width: 19, height: 24))
    isBordered = false
    title = ""
    setAccessibilityLabel(color.accessibilityName)
    translatesAutoresizingMaskIntoConstraints = false
    widthAnchor.constraint(equalToConstant: 19).isActive = true
    heightAnchor.constraint(equalToConstant: 24).isActive = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func draw(_ dirtyRect: NSRect) {
    let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 4))
    color.setFill()
    circle.fill()
    NSColor.labelColor.withAlphaComponent(0.18).setStroke()
    circle.lineWidth = 0.5
    circle.stroke()
    if state == .on {
      PinShotTheme.accent.setStroke()
      let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 0, dy: 2))
      ring.lineWidth = 1.5
      ring.stroke()
    }
  }
}

private extension AnnotationColor {
  var nsColor: NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
  }

  init(nsColor: NSColor) {
    let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
    self.init(red: Double(color.redComponent), green: Double(color.greenComponent),
              blue: Double(color.blueComponent), alpha: Double(color.alphaComponent))
  }
}
