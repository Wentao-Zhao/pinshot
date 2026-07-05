import Foundation

public enum AnnotationHitTester {
  public static func topmostItemID(
    at point: Point2D,
    in items: [AnnotationItem],
    kinds: Set<AnnotationKind>? = nil,
    textBounds: [UUID: Rect2D] = [:]
  ) -> UUID? {
    for item in items.reversed() {
      if let kinds, !kinds.contains(item.kind) {
        continue
      }
      if contains(point, item: item, textBounds: textBounds[item.id]) {
        return item.id
      }
    }
    return nil
  }

  public static func contains(
    _ point: Point2D,
    item: AnnotationItem,
    textBounds: Rect2D? = nil
  ) -> Bool {
    let tolerance = max(8, item.style.strokeWidth / 2 + 4)

    switch item.kind {
    case .rectangle:
      guard let bounds = bounds(for: item) else {
        return false
      }
      let outer = expanded(bounds, by: tolerance)
      let inner = inset(bounds, by: tolerance)
      return outer.contains(point) && (inner.width == 0 || inner.height == 0 || !inner.contains(point))
    case .mosaic:
      guard let bounds = bounds(for: item) else {
        return false
      }
      return expanded(bounds, by: tolerance).contains(point)
    case .arrow, .pen:
      return polylineContains(point, points: item.points, tolerance: tolerance)
    case .text:
      let bounds = textBounds ?? fallbackTextBounds(for: item)
      return expanded(bounds, by: 4).contains(point)
    }
  }

  public static func bounds(for item: AnnotationItem, textBounds: Rect2D? = nil) -> Rect2D? {
    if item.kind == .text {
      return textBounds ?? fallbackTextBounds(for: item)
    }
    guard let first = item.points.first else {
      return nil
    }
    var minX = first.x
    var maxX = first.x
    var minY = first.y
    var maxY = first.y
    for point in item.points.dropFirst() {
      minX = min(minX, point.x)
      maxX = max(maxX, point.x)
      minY = min(minY, point.y)
      maxY = max(maxY, point.y)
    }
    return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private static func fallbackTextBounds(for item: AnnotationItem) -> Rect2D {
    let origin = item.points.first ?? Point2D(x: 0, y: 0)
    let characterWidth = item.style.fontSize * 0.65
    return Rect2D(
      x: origin.x,
      y: origin.y,
      width: max(item.style.fontSize, Double(item.text.count) * characterWidth),
      height: item.style.fontSize * 1.25
    )
  }

  private static func polylineContains(
    _ point: Point2D,
    points: [Point2D],
    tolerance: Double
  ) -> Bool {
    guard let first = points.first else {
      return false
    }
    if points.count == 1 {
      return distance(from: point, to: first) <= tolerance
    }
    for index in 0..<(points.count - 1) {
      if distance(from: point, toSegmentFrom: points[index], to: points[index + 1]) <= tolerance {
        return true
      }
    }
    return false
  }

  private static func distance(from point: Point2D, to other: Point2D) -> Double {
    hypot(point.x - other.x, point.y - other.y)
  }

  private static func distance(
    from point: Point2D,
    toSegmentFrom start: Point2D,
    to end: Point2D
  ) -> Double {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else {
      return distance(from: point, to: start)
    }
    let projection = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
    let clamped = min(max(projection, 0), 1)
    let nearest = Point2D(x: start.x + clamped * dx, y: start.y + clamped * dy)
    return distance(from: point, to: nearest)
  }

  private static func expanded(_ rect: Rect2D, by amount: Double) -> Rect2D {
    Rect2D(
      x: rect.x - amount,
      y: rect.y - amount,
      width: rect.width + amount * 2,
      height: rect.height + amount * 2
    )
  }

  private static func inset(_ rect: Rect2D, by amount: Double) -> Rect2D {
    Rect2D(
      x: rect.x + min(amount, rect.width / 2),
      y: rect.y + min(amount, rect.height / 2),
      width: max(0, rect.width - amount * 2),
      height: max(0, rect.height - amount * 2)
    )
  }
}

private extension Rect2D {
  func contains(_ point: Point2D) -> Bool {
    point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
  }
}
