import AppKit
import PinShotCore

enum AnnotationDrawing {
  static func draw(item: AnnotationItem, offset: NSPoint = .zero) {
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
      drawMosaic(item, offset: offset)
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
    NSColor.systemRed.setStroke()
    path.lineWidth = 3
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
    NSColor.systemRed.setStroke()
    path.lineWidth = 3
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
    arrow.lineWidth = 3
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
    NSColor.systemRed.setStroke()
    path.lineWidth = 3
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
      .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
      .foregroundColor: NSColor.systemRed,
      .backgroundColor: NSColor.white.withAlphaComponent(0.78),
    ]
    item.text.draw(at: point, withAttributes: attributes)
  }

  private static func drawMosaic(_ item: AnnotationItem, offset: NSPoint) {
    guard let rect = rect(from: item.points, offset: offset), rect.width > 2, rect.height > 2 else {
      return
    }
    NSColor.black.withAlphaComponent(0.28).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

    NSColor.white.withAlphaComponent(0.18).setStroke()
    let grid = NSBezierPath()
    let step: CGFloat = 10
    var x = rect.minX
    while x <= rect.maxX {
      grid.move(to: NSPoint(x: x, y: rect.minY))
      grid.line(to: NSPoint(x: x, y: rect.maxY))
      x += step
    }
    var y = rect.minY
    while y <= rect.maxY {
      grid.move(to: NSPoint(x: rect.minX, y: y))
      grid.line(to: NSPoint(x: rect.maxX, y: y))
      y += step
    }
    grid.lineWidth = 1
    grid.stroke()
  }
}

