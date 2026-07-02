import Foundation

public struct Point2D: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public struct Rect2D: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = max(0, width)
    self.height = max(0, height)
  }

  public var minX: Double { x }
  public var minY: Double { y }
  public var maxX: Double { x + width }
  public var maxY: Double { y + height }
  public var isUsable: Bool { width >= 8 && height >= 8 }

  public static func normalized(from start: Point2D, to end: Point2D) -> Rect2D {
    Rect2D(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    )
  }

  public func movedBy(dx: Double, dy: Double, constrainedTo bounds: Rect2D) -> Rect2D {
    let newX = min(max(x + dx, bounds.minX), max(bounds.minX, bounds.maxX - width))
    let newY = min(max(y + dy, bounds.minY), max(bounds.minY, bounds.maxY - height))
    return Rect2D(x: newX, y: newY, width: width, height: height)
  }
}

