import AppKit
import PinShotCore

final class CaptureOverlayView: NSView {
  var onCommand: ((CaptureCommand, NSImage?) -> Void)?

  private enum Interaction {
    case idle
    case selecting(start: NSPoint)
    case movingSelection(last: NSPoint)
    case drawing(start: NSPoint)
    case drawingPen(points: [Point2D])
  }

  private var snapshot: ScreenSnapshot
  private let toolbar = AnnotationToolbarView(frame: .zero)
  private let ocrPanel = OCRStatusPanelView(frame: .zero)
  private var selectionRect: NSRect?
  private var interaction: Interaction = .idle
  private var selectedTool: AnnotationTool = .move
  private var annotationStyle = AnnotationStyle.default
  private var annotations = AnnotationDocument()
  private var previewAnnotation: AnnotationItem?
  private var textField: NSTextField?
  private var ocrState = OCRPanelState.hidden

  init(snapshot: ScreenSnapshot) {
    self.snapshot = snapshot
    super.init(frame: NSRect(origin: .zero, size: snapshot.screen.frame.size))
    wantsLayer = true
    addSubview(toolbar)
    addSubview(ocrPanel)
    toolbar.isHidden = true
    ocrPanel.isHidden = true
    toolbar.onCommand = { [weak self] command in
      self?.handleToolbarCommand(command)
    }
    ocrPanel.onCopy = { text in
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(text, forType: .string)
    }
    ocrPanel.onClose = { [weak self] in
      self?.setOCRPanelState(.hidden)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func viewDidMoveToWindow() {
    window?.makeFirstResponder(self)
  }

  override func draw(_ dirtyRect: NSRect) {
    if let image = snapshot.image {
      image.draw(in: bounds)
    } else {
      NSColor.black.withAlphaComponent(0.12).setFill()
      bounds.fill()
    }

    NSColor.black.withAlphaComponent(0.32).setFill()
    if let selectionRect {
      let dimPath = NSBezierPath(rect: bounds)
      dimPath.append(NSBezierPath(rect: selectionRect))
      dimPath.windingRule = .evenOdd
      dimPath.fill()
      drawSelectionFrame(selectionRect)

      NSGraphicsContext.saveGraphicsState()
      NSBezierPath(rect: selectionRect).addClip()
      for item in annotations.items {
        AnnotationDrawing.draw(item: item, baseImage: snapshot.image)
      }
      if let previewAnnotation {
        AnnotationDrawing.draw(item: previewAnnotation, baseImage: snapshot.image)
      }
      NSGraphicsContext.restoreGraphicsState()
    } else {
      NSRect(origin: .zero, size: bounds.size).fill()
      drawHint(text: snapshot.image == nil ? "正在准备截图..." : "拖动选择截图区域，Esc 取消")
    }
  }

  func updateImage(_ image: NSImage?) {
    snapshot.image = image
    setNeedsDisplay(bounds)
  }

  func setOCRPanelState(_ state: OCRPanelState) {
    ocrState = state
    ocrPanel.update(state: state)
    ocrPanel.isHidden = !state.isVisible
    updateOCRPanelFrame()
  }

  override func mouseDown(with event: NSEvent) {
    guard snapshot.image != nil else {
      return
    }

    commitTextIfNeeded()
    let point = convert(event.locationInWindow, from: nil)

    guard let selectionRect else {
      setOCRPanelState(.hidden)
      interaction = .selecting(start: point)
      self.selectionRect = NSRect(origin: point, size: .zero)
      setNeedsDisplay(bounds)
      return
    }

    guard selectionRect.contains(point) else {
      return
    }

    if isSelectionMoveHandle(point, in: selectionRect) {
      interaction = .movingSelection(last: point)
      return
    }

    switch selectedTool {
    case .move:
      interaction = .movingSelection(last: point)
    case .rectangle:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .rectangle, points: [point.point2D, point.point2D], style: annotationStyle)
    case .arrow:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .arrow, points: [point.point2D, point.point2D], style: annotationStyle)
    case .mosaic:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .mosaic, points: [point.point2D, point.point2D], style: annotationStyle)
    case .pen:
      interaction = .drawingPen(points: [point.point2D])
      previewAnnotation = AnnotationItem(kind: .pen, points: [point.point2D], style: annotationStyle)
    case .text:
      beginTextEditing(at: point)
      interaction = .idle
    }
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    switch interaction {
    case .idle:
      return
    case .selecting(let start):
      selectionRect = normalizedRect(from: start, to: point).intersection(bounds)
      setNeedsDisplay(bounds)
    case .movingSelection(let last):
      guard let selectionRect else {
        return
      }
      let dx = point.x - last.x
      let dy = point.y - last.y
      let moved = Rect2D(
        x: selectionRect.origin.x,
        y: selectionRect.origin.y,
        width: selectionRect.width,
        height: selectionRect.height
      ).movedBy(
        dx: dx,
        dy: dy,
        constrainedTo: Rect2D(x: 0, y: 0, width: bounds.width, height: bounds.height)
      )
      let actualDX = moved.x - selectionRect.origin.x
      let actualDY = moved.y - selectionRect.origin.y
      self.selectionRect = moved.nsRect
      annotations.moveAll(dx: actualDX, dy: actualDY)
      interaction = .movingSelection(last: point)
      updateToolbarFrame()
      updateOCRPanelFrame()
      setNeedsDisplay(bounds)
    case .drawing(let start):
      updatePreview(from: start, to: point)
      setNeedsDisplay(bounds)
    case .drawingPen(var points):
      points.append(point.point2D)
      previewAnnotation = AnnotationItem(kind: .pen, points: points, style: annotationStyle)
      interaction = .drawingPen(points: points)
      setNeedsDisplay(bounds)
    }
  }

  override func mouseUp(with event: NSEvent) {
    switch interaction {
    case .selecting:
      if selectionRect?.size.isUsable == true {
        toolbar.isHidden = false
        selectedTool = .move
        toolbar.setSelectedTool(.move)
        annotationStyle = toolbar.currentStyle()
        updateToolbarFrame()
      } else {
        selectionRect = nil
      }
    case .drawing, .drawingPen:
      if let previewAnnotation {
        annotations.append(previewAnnotation)
      }
      previewAnnotation = nil
    case .idle, .movingSelection:
      break
    }

    interaction = .idle
    setNeedsDisplay(bounds)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      onCommand?(.cancel, nil)
      return
    }
    if event.keyCode == 36 {
      onCommand?(.finishDefault, renderedImage())
      return
    }
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
      if event.charactersIgnoringModifiers?.lowercased() == "z" {
        if event.modifierFlags.contains(.shift) {
          _ = annotations.redo()
        } else {
          _ = annotations.undo()
        }
        setNeedsDisplay(bounds)
        return
      }
    }
    super.keyDown(with: event)
  }

  private func handleToolbarCommand(_ command: AnnotationToolbarCommand) {
    switch command {
    case .tool(let tool):
      selectedTool = tool
    case .style(let style):
      annotationStyle = style
    case .undo:
      _ = annotations.undo()
      setNeedsDisplay(bounds)
    case .reset:
      annotations.reset()
      setNeedsDisplay(bounds)
    case .pin:
      onCommand?(.pin, renderedImage())
    case .ocr:
      guard ocrState != .recognizing else {
        return
      }
      setOCRPanelState(.recognizing)
      guard let image = renderedImage() else {
        setOCRPanelState(.result(from: nil))
        return
      }
      onCommand?(.ocr, image)
    }
  }

  private func updatePreview(from start: NSPoint, to point: NSPoint) {
    guard let existing = previewAnnotation else {
      return
    }
    previewAnnotation = AnnotationItem(
      id: existing.id,
      kind: existing.kind,
      points: [start.point2D, point.point2D],
      text: existing.text,
      style: annotationStyle
    )
  }

  private func beginTextEditing(at point: NSPoint) {
    textField?.removeFromSuperview()

    let field = NSTextField(frame: NSRect(x: point.x, y: point.y - 24, width: 220, height: 28))
    field.placeholderString = "输入文字"
    field.font = .systemFont(ofSize: CGFloat(annotationStyle.fontSize), weight: .semibold)
    field.textColor = annotationStyle.textColor.nsColor
    field.target = self
    field.action = #selector(commitTextField)
    addSubview(field)
    textField = field
    window?.makeFirstResponder(field)
  }

  @objc private func commitTextField() {
    commitTextIfNeeded()
  }

  private func commitTextIfNeeded() {
    guard let field = textField else {
      return
    }
    let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
      annotations.append(
        AnnotationItem(kind: .text, points: [field.frame.origin.point2D], text: text, style: annotationStyle)
      )
    }
    field.removeFromSuperview()
    textField = nil
    window?.makeFirstResponder(self)
    setNeedsDisplay(bounds)
  }

  private func renderedImage() -> NSImage? {
    commitTextIfNeeded()
    guard let selectionRect, snapshot.image != nil else {
      return nil
    }
    return ScreenshotRenderer.render(
      snapshot: snapshot,
      selectionRect: selectionRect,
      annotations: annotations.items
    )
  }

  private func updateToolbarFrame() {
    guard let selectionRect else {
      return
    }

    let size = toolbar.fittingSize
    let width = min(max(size.width, 330), bounds.width - 24)
    let height = min(max(size.height, 42), 46)
    let x = min(max(selectionRect.midX - width / 2, 12), bounds.width - width - 12)
    let yAbove = selectionRect.maxY + 10
    let yBelow = selectionRect.minY - height - 8
    let y = yAbove + height < bounds.maxY ? yAbove : max(12, yBelow)
    toolbar.frame = NSRect(x: x, y: y, width: width, height: height)
    updateOCRPanelFrame()
  }

  private func updateOCRPanelFrame() {
    guard !ocrPanel.isHidden else {
      return
    }
    let panelSize = ocrPanel.preferredSize(maxWidth: min(520, bounds.width - 24))
    let spacing: CGFloat = 8
    let rightX = toolbar.frame.maxX + spacing
    let leftX = toolbar.frame.minX - panelSize.width - spacing
    let x: CGFloat
    let y: CGFloat
    if rightX + panelSize.width <= bounds.maxX - 12 {
      x = rightX
      y = toolbar.frame.minY
    } else if leftX >= 12 {
      x = leftX
      y = toolbar.frame.minY
    } else {
      x = min(max(toolbar.frame.maxX - panelSize.width, 12), bounds.width - panelSize.width - 12)
      let yBelow = toolbar.frame.minY - panelSize.height - spacing
      let yAbove = toolbar.frame.maxY + spacing
      if yBelow >= 12 {
        y = yBelow
      } else {
        y = min(yAbove, bounds.maxY - panelSize.height - 12)
      }
    }
    ocrPanel.frame = NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
  }

  private func drawSelectionFrame(_ rect: NSRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
    NSColor.systemBlue.setStroke()
    path.lineWidth = 2
    path.stroke()

    NSColor.white.setFill()
    for handle in handleRects(for: rect) {
      NSBezierPath(ovalIn: handle).fill()
    }
  }

  private func isSelectionMoveHandle(_ point: NSPoint, in rect: NSRect) -> Bool {
    let edgeInset: CGFloat = 10
    let expanded = rect.insetBy(dx: -edgeInset, dy: -edgeInset)
    let inner = rect.insetBy(dx: edgeInset, dy: edgeInset)
    return expanded.contains(point) && !inner.contains(point)
  }

  private func drawHint(text: String) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
      .foregroundColor: NSColor.white.withAlphaComponent(0.9),
    ]
    let size = text.size(withAttributes: attributes)
    text.draw(
      at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
      withAttributes: attributes
    )
  }

  private func handleRects(for rect: NSRect) -> [NSRect] {
    let size: CGFloat = 8
    return [
      NSRect(x: rect.minX - size / 2, y: rect.minY - size / 2, width: size, height: size),
      NSRect(x: rect.maxX - size / 2, y: rect.minY - size / 2, width: size, height: size),
      NSRect(x: rect.minX - size / 2, y: rect.maxY - size / 2, width: size, height: size),
      NSRect(x: rect.maxX - size / 2, y: rect.maxY - size / 2, width: size, height: size),
    ]
  }

  private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
    NSRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    )
  }
}

private extension NSSize {
  var isUsable: Bool {
    width >= 8 && height >= 8
  }
}

private final class OCRStatusPanelView: NSVisualEffectView {
  var onCopy: ((String) -> Void)?
  var onClose: (() -> Void)?

  private let stack = NSStackView()
  private let contentStack = NSStackView()
  private let spinner = NSProgressIndicator()
  private let titleLabel = NSTextField(labelWithString: "识别结果")
  private let label = NSTextField(labelWithString: "")
  private let copyButton = NSButton(title: "复制", target: nil, action: nil)
  private let closeButton = NSButton(title: "×", target: nil, action: nil)
  private var panelState = OCRPanelState.hidden

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

  func update(state: OCRPanelState) {
    panelState = state
    label.stringValue = state.previewText
    titleLabel.isHidden = state == .recognizing
    copyButton.isHidden = !state.canCopy
    closeButton.isHidden = state == .recognizing
    if state == .recognizing {
      spinner.isHidden = false
      spinner.startAnimation(nil)
    } else {
      spinner.stopAnimation(nil)
      spinner.isHidden = true
    }
    needsLayout = true
  }

  func preferredSize(maxWidth: CGFloat) -> NSSize {
    if panelState == .recognizing {
      return NSSize(width: min(148, maxWidth), height: 42)
    }
    let textWeight = CGFloat(min(max(panelState.previewText.count, 36), 90))
    let textWidth = min(max(textWeight * 6.8, 260), maxWidth - 92)
    let width = min(max(textWidth + 92, 340), maxWidth)
    return NSSize(width: width, height: panelState.canCopy ? 82 : 66)
  }

  private func buildContent() {
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 10
    addSubview(stack)

    spinner.style = .spinning
    spinner.controlSize = .small
    spinner.isDisplayedWhenStopped = false
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.widthAnchor.constraint(equalToConstant: 16).isActive = true
    spinner.heightAnchor.constraint(equalToConstant: 16).isActive = true

    titleLabel.textColor = NSColor.white.withAlphaComponent(0.58)
    titleLabel.font = .systemFont(ofSize: 11, weight: .medium)

    label.textColor = NSColor.white.withAlphaComponent(0.88)
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.usesSingleLineMode = false
    label.maximumNumberOfLines = 3
    label.lineBreakMode = .byTruncatingTail
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    contentStack.orientation = .vertical
    contentStack.alignment = .leading
    contentStack.spacing = 3
    contentStack.addArrangedSubview(titleLabel)
    contentStack.addArrangedSubview(label)

    configureButton(copyButton)
    copyButton.target = self
    copyButton.action = #selector(copyClicked)

    closeButton.isBordered = false
    closeButton.font = .systemFont(ofSize: 14, weight: .bold)
    closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.58)
    closeButton.target = self
    closeButton.action = #selector(closeClicked)
    closeButton.widthAnchor.constraint(equalToConstant: 18).isActive = true

    stack.addArrangedSubview(spinner)
    stack.addArrangedSubview(contentStack)
    stack.addArrangedSubview(copyButton)
    stack.addArrangedSubview(closeButton)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
      copyButton.widthAnchor.constraint(equalToConstant: 46),
    ])
  }

  private func configureButton(_ button: NSButton) {
    button.bezelStyle = .rounded
    button.controlSize = .small
    button.font = .systemFont(ofSize: 11, weight: .semibold)
  }

  @objc private func copyClicked() {
    guard let text = panelState.copyText else {
      return
    }
    onCopy?(text)
    label.stringValue = "已复制"
    copyButton.isHidden = true
  }

  @objc private func closeClicked() {
    onClose?()
  }
}

private extension NSPoint {
  var point2D: Point2D {
    Point2D(x: x, y: y)
  }
}

private extension Rect2D {
  var nsRect: NSRect {
    NSRect(x: x, y: y, width: width, height: height)
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
}
