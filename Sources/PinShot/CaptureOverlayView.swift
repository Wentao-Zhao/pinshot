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

  private let snapshot: ScreenSnapshot
  private let toolbar = AnnotationToolbarView(frame: .zero)
  private var selectionRect: NSRect?
  private var interaction: Interaction = .idle
  private var selectedTool: AnnotationTool = .move
  private var annotations = AnnotationDocument()
  private var previewAnnotation: AnnotationItem?
  private var textField: NSTextField?

  init(snapshot: ScreenSnapshot) {
    self.snapshot = snapshot
    super.init(frame: NSRect(origin: .zero, size: snapshot.screen.frame.size))
    wantsLayer = true
    addSubview(toolbar)
    toolbar.isHidden = true
    toolbar.onCommand = { [weak self] command in
      self?.handleToolbarCommand(command)
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
    snapshot.image.draw(in: bounds)

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
        AnnotationDrawing.draw(item: item)
      }
      if let previewAnnotation {
        AnnotationDrawing.draw(item: previewAnnotation)
      }
      NSGraphicsContext.restoreGraphicsState()
    } else {
      NSRect(origin: .zero, size: bounds.size).fill()
      drawHint()
    }
  }

  override func mouseDown(with event: NSEvent) {
    commitTextIfNeeded()
    let point = convert(event.locationInWindow, from: nil)

    guard let selectionRect else {
      interaction = .selecting(start: point)
      self.selectionRect = NSRect(origin: point, size: .zero)
      setNeedsDisplay(bounds)
      return
    }

    guard selectionRect.contains(point) else {
      return
    }

    switch selectedTool {
    case .move:
      interaction = .movingSelection(last: point)
    case .rectangle:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .rectangle, points: [point.point2D, point.point2D])
    case .arrow:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .arrow, points: [point.point2D, point.point2D])
    case .mosaic:
      interaction = .drawing(start: point)
      previewAnnotation = AnnotationItem(kind: .mosaic, points: [point.point2D, point.point2D])
    case .pen:
      interaction = .drawingPen(points: [point.point2D])
      previewAnnotation = AnnotationItem(kind: .pen, points: [point.point2D])
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
      setNeedsDisplay(bounds)
    case .drawing(let start):
      updatePreview(from: start, to: point)
      setNeedsDisplay(bounds)
    case .drawingPen(var points):
      points.append(point.point2D)
      previewAnnotation = AnnotationItem(kind: .pen, points: points)
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
    case .undo:
      _ = annotations.undo()
      setNeedsDisplay(bounds)
    case .redo:
      _ = annotations.redo()
      setNeedsDisplay(bounds)
    case .clear:
      annotations.clear()
      setNeedsDisplay(bounds)
    case .finishDefault:
      onCommand?(.finishDefault, renderedImage())
    case .copy:
      onCommand?(.copy, renderedImage())
    case .save:
      onCommand?(.save, renderedImage())
    case .pin:
      onCommand?(.pin, renderedImage())
    case .ocr:
      onCommand?(.ocr, renderedImage())
    case .cancel:
      onCommand?(.cancel, nil)
    }
  }

  private func updatePreview(from start: NSPoint, to point: NSPoint) {
    guard let existing = previewAnnotation else {
      return
    }
    previewAnnotation = AnnotationItem(
      id: existing.id,
      kind: existing.kind,
      points: [start.point2D, point.point2D]
    )
  }

  private func beginTextEditing(at point: NSPoint) {
    textField?.removeFromSuperview()

    let field = NSTextField(frame: NSRect(x: point.x, y: point.y - 24, width: 220, height: 28))
    field.placeholderString = "输入文字"
    field.font = .systemFont(ofSize: 18, weight: .semibold)
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
        AnnotationItem(kind: .text, points: [field.frame.origin.point2D], text: text)
      )
    }
    field.removeFromSuperview()
    textField = nil
    window?.makeFirstResponder(self)
    setNeedsDisplay(bounds)
  }

  private func renderedImage() -> NSImage? {
    commitTextIfNeeded()
    guard let selectionRect else {
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
    let width = min(max(size.width, 760), bounds.width - 24)
    let x = min(max(selectionRect.midX - width / 2, 12), bounds.width - width - 12)
    let yAbove = selectionRect.maxY + 10
    let yBelow = selectionRect.minY - 48
    let y = yAbove + 44 < bounds.maxY ? yAbove : max(12, yBelow)
    toolbar.frame = NSRect(x: x, y: y, width: width, height: 40)
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

  private func drawHint() {
    let text = "拖动选择截图区域，Esc 取消"
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

