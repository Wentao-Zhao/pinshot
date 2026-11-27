import AppKit
import PinShotCore

final class CaptureOverlayView: NSView {
  var onCommand: ((CaptureCommand, NSImage?) -> Void)?

  private enum Interaction {
    case idle
    case selecting(start: NSPoint)
    case movingSelection(last: NSPoint)
    case movingAnnotation(id: UUID, last: NSPoint)
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
  private var editingTextItem: AnnotationItem?
  private var textSession = TextAnnotationSession()
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

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    CaptureInteractionPolicy.acceptsFirstMouse
  }

  override func viewDidMoveToWindow() {
    window?.makeFirstResponder(self)
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    guard textSession.usesTextCursor, let selectionRect else {
      return
    }
    addCursorRect(selectionRect, cursor: .iBeam)
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
      for item in annotations.items where item.id != editingTextItem?.id {
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
    if state.recognizedText == nil, window?.firstResponder is OCRResultTextView {
      window?.makeFirstResponder(self)
    }
    ocrState = state
    ocrPanel.update(state: state)
    ocrPanel.isHidden = !state.isVisible
    updateOCRPanelFrame()
  }

  override func mouseDown(with event: NSEvent) {
    guard snapshot.image != nil else {
      return
    }

    toolbar.closePopover()

    if textField != nil {
      commitTextIfNeeded()
      return
    }
    window?.makeFirstResponder(self)
    let point = localPoint(from: event)

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

    if selectedTool == .text {
      guard textSession.beginEditing() else {
        return
      }
      let existingText = hitAnnotation(at: point, kinds: [.text]).flatMap { annotations.item(id: $0) }
      beginTextEditing(at: point, existing: existingText)
      interaction = .idle
      return
    }

    switch selectedTool {
    case .move:
      if let itemID = hitAnnotation(at: point) {
        interaction = .movingAnnotation(id: itemID, last: point)
      } else {
        interaction = .movingSelection(last: point)
      }
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
      break
    }
  }

  override func mouseDragged(with event: NSEvent) {
    let point = localPoint(from: event)

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
    case .movingAnnotation(let id, let last):
      let dx = point.x - last.x
      let dy = point.y - last.y
      _ = annotations.move(id: id, dx: dx, dy: dy)
      interaction = .movingAnnotation(id: id, last: point)
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
        textSession.finish()
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
    case .idle, .movingSelection, .movingAnnotation:
      break
    }

    interaction = .idle
    window?.invalidateCursorRects(for: self)
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
      commitTextIfNeeded(exitTextMode: false)
      selectedTool = tool
      if tool == .text {
        textSession.activate()
      } else {
        textSession.finish()
      }
      window?.invalidateCursorRects(for: self)
    case .style(let style):
      annotationStyle = style
    case .undo:
      commitTextIfNeeded()
      _ = annotations.undo()
      setNeedsDisplay(bounds)
    case .redo:
      commitTextIfNeeded()
      _ = annotations.redo()
      setNeedsDisplay(bounds)
    case .reset:
      commitTextIfNeeded()
      annotations.reset()
      setNeedsDisplay(bounds)
    case .cancel:
      toolbar.closePopover()
      onCommand?(.cancel, nil)
    case .copy:
      toolbar.closePopover()
      onCommand?(.copy, renderedImage())
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

  private func beginTextEditing(at point: NSPoint, existing: AnnotationItem? = nil) {
    textField?.removeFromSuperview()

    let style = existing?.style ?? annotationStyle
    let origin = existing?.points.first.map { NSPoint(x: $0.x, y: $0.y) }
      ?? NSPoint(x: point.x, y: point.y - CGFloat(style.fontSize))
    let existingWidth = existing.map { textBounds(for: $0).width } ?? 0
    let fieldWidth = max(220, existingWidth + 20)
    let fieldHeight = max(28, CGFloat(style.fontSize) + 8)
    let field = NSTextField(frame: NSRect(x: origin.x, y: origin.y, width: fieldWidth, height: fieldHeight))
    field.placeholderString = existing == nil ? "输入文字" : nil
    field.stringValue = existing?.text ?? ""
    field.font = .systemFont(ofSize: CGFloat(style.fontSize), weight: .semibold)
    field.textColor = style.textColor.nsColor
    field.isBezeled = false
    field.isBordered = false
    field.drawsBackground = false
    field.backgroundColor = .clear
    field.focusRingType = .none
    field.target = self
    field.action = #selector(commitTextField)
    addSubview(field)
    editingTextItem = existing
    textField = field
    window?.makeFirstResponder(field)
    if let editor = field.currentEditor() {
      editor.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0)
    }
  }

  @objc private func commitTextField() {
    commitTextIfNeeded()
  }

  private func commitTextIfNeeded(exitTextMode: Bool = true) {
    guard let field = textField else {
      return
    }
    let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let existing = editingTextItem
    if !text.isEmpty {
      let item = AnnotationItem(
        id: existing?.id ?? UUID(),
        kind: .text,
        points: [field.frame.origin.point2D],
        text: text,
        style: existing?.style ?? annotationStyle
      )
      if existing == nil {
        annotations.append(item)
      } else {
        _ = annotations.replace(item)
      }
    } else if let existing {
      _ = annotations.remove(id: existing.id)
    }
    field.removeFromSuperview()
    textField = nil
    editingTextItem = nil
    if exitTextMode {
      selectedTool = .move
      textSession.finish()
      toolbar.setSelectedTool(.move)
      window?.invalidateCursorRects(for: self)
    }
    window?.makeFirstResponder(self)
    setNeedsDisplay(bounds)
  }

  private func hitAnnotation(
    at point: NSPoint,
    kinds: Set<AnnotationKind>? = nil
  ) -> UUID? {
    let measuredTextBounds = Dictionary(
      uniqueKeysWithValues: annotations.items.compactMap { item -> (UUID, Rect2D)? in
        guard item.kind == .text else {
          return nil
        }
        let bounds = textBounds(for: item)
        return (item.id, Rect2D(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height))
      }
    )
    return AnnotationHitTester.topmostItemID(
      at: point.point2D,
      in: annotations.items,
      kinds: kinds,
      textBounds: measuredTextBounds
    )
  }

  private func textBounds(for item: AnnotationItem) -> NSRect {
    guard let origin = item.points.first else {
      return .zero
    }
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: CGFloat(item.style.fontSize), weight: .semibold),
    ]
    let size = (item.text as NSString).size(withAttributes: attributes)
    return NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
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
    let panelSize = ocrPanel.preferredSize(in: bounds.insetBy(dx: 12, dy: 12).size)
    let spacing: CGFloat = 8
    let rightX = toolbar.frame.maxX + spacing
    let leftX = toolbar.frame.minX - panelSize.width - spacing
    let x: CGFloat
    let y: CGFloat
    if rightX + panelSize.width <= bounds.maxX - 12 {
      x = rightX
      y = toolbar.frame.maxY - panelSize.height
    } else if leftX >= 12 {
      x = leftX
      y = toolbar.frame.maxY - panelSize.height
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
    let clampedY = max(12, min(y, bounds.maxY - panelSize.height - 12))
    ocrPanel.frame = NSRect(x: x, y: clampedY, width: panelSize.width, height: panelSize.height)
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

  private func localPoint(from event: NSEvent) -> NSPoint {
    let windowPoint = event.locationInWindow
    let globalPoint = window?.convertPoint(toScreen: windowPoint) ?? windowPoint
    let mapped = ScreenCoordinateMapper.localPoint(
      fromGlobal: Point2D(x: globalPoint.x, y: globalPoint.y),
      inScreenFrame: Rect2D(
        x: snapshot.screen.frame.minX,
        y: snapshot.screen.frame.minY,
        width: snapshot.screen.frame.width,
        height: snapshot.screen.frame.height
      )
    )
    return NSPoint(x: mapped.x, y: mapped.y)
  }
}

private extension NSSize {
  var isUsable: Bool {
    width >= 8 && height >= 8
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
