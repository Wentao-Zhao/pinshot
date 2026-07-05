import AppKit
import PinShotCore

enum AnnotationDrawing {
  static func draw(
    item: AnnotationItem,
    offset: NSPoint = .zero,
    baseImage: NSImage? = nil,
    mosaicSourceOffset: NSPoint = .zero
  ) {
    switch item.kind {
    case .rectangle:
      drawRectangle(item, offset: offset)
    case .arrow:
      drawArrow(item, offset: offset)
    case .pen:
      drawPen(item, offset: offset)
    case .text:
      drawText(item, offset: offset)
    case .mosaic:
      drawMosaic(item, offset: offset, baseImage: baseImage, sourceOffset: mosaicSourceOffset)
    }
  }

  private static func point(_ point: Point2D, offset: NSPoint) -> NSPoint {
    NSPoint(x: point.x + offset.x, y: point.y + offset.y)
  }

  private static func rect(from points: [Point2D], offset: NSPoint) -> NSRect? {
    guard let first = points.first, let last = points.last else {
      return nil
    }
    let start = point(first, offset: offset)
    let end = point(last, offset: offset)
    return NSRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    )
  }

  private static func drawRectangle(_ item: AnnotationItem, offset: NSPoint) {
    guard let rect = rect(from: item.points, offset: offset) else {
      return
    }
    let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
    item.style.strokeColor.nsColor.setStroke()
    path.lineWidth = CGFloat(item.style.strokeWidth)
    path.stroke()
  }

  private static func drawArrow(_ item: AnnotationItem, offset: NSPoint) {
    guard item.points.count >= 2 else {
      return
    }
    let start = point(item.points[0], offset: offset)
    let end = point(item.points[item.points.count - 1], offset: offset)
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    item.style.strokeColor.nsColor.setStroke()
    path.lineWidth = CGFloat(item.style.strokeWidth)
    path.lineCapStyle = .round
    path.stroke()

    let angle = atan2(end.y - start.y, end.x - start.x)
    let length: CGFloat = 14
    let spread: CGFloat = .pi / 7
    let arrow = NSBezierPath()
    arrow.move(to: end)
    arrow.line(to: NSPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread)))
    arrow.move(to: end)
    arrow.line(to: NSPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread)))
    arrow.lineWidth = CGFloat(item.style.strokeWidth)
    arrow.lineCapStyle = .round
    arrow.stroke()
  }

  private static func drawPen(_ item: AnnotationItem, offset: NSPoint) {
    guard item.points.count >= 2 else {
      return
    }
    let path = NSBezierPath()
    path.move(to: point(item.points[0], offset: offset))
    for pointValue in item.points.dropFirst() {
      path.line(to: point(pointValue, offset: offset))
    }
    item.style.strokeColor.nsColor.setStroke()
    path.lineWidth = CGFloat(item.style.strokeWidth)
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.stroke()
  }

  private static func drawText(_ item: AnnotationItem, offset: NSPoint) {
    guard let first = item.points.first, !item.text.isEmpty else {
      return
    }
    let point = point(first, offset: offset)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: CGFloat(item.style.fontSize), weight: .semibold),
      .foregroundColor: item.style.textColor.nsColor,
    ]
    item.text.draw(at: point, withAttributes: attributes)
  }

  private static func drawMosaic(
    _ item: AnnotationItem,
    offset: NSPoint,
    baseImage: NSImage?,
    sourceOffset: NSPoint
  ) {
    guard let rect = rect(from: item.points, offset: offset), rect.width > 2, rect.height > 2 else {
      return
    }

    let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
    guard let baseImage else {
      NSColor.black.withAlphaComponent(0.72).setFill()
      path.fill()
      return
    }

    let sourceRect = rect.offsetBy(dx: sourceOffset.x, dy: sourceOffset.y)
    let block: CGFloat = 12
    let pixelSize = NSSize(
      width: max(1, ceil(rect.width / block)),
      height: max(1, ceil(rect.height / block))
    )
    let pixelImage = NSImage(size: pixelSize)
    pixelImage.lockFocus()
    baseImage.draw(
      in: NSRect(origin: .zero, size: pixelSize),
      from: sourceRect,
      operation: .copy,
      fraction: 1
    )
    pixelImage.unlockFocus()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGraphicsContext.current?.imageInterpolation = .none
    pixelImage.draw(
      in: rect,
      from: NSRect(origin: .zero, size: pixelSize),
      operation: .copy,
      fraction: 1
    )
    NSColor.black.withAlphaComponent(0.16).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
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
