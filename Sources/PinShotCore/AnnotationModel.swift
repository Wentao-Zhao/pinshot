import Foundation

public enum AnnotationTool: String, CaseIterable, Codable, Equatable, Sendable {
  case move
  case rectangle
  case arrow
  case pen
  case text
  case mosaic
}

public enum AnnotationKind: String, Codable, Equatable, Sendable {
  case rectangle
  case arrow
  case pen
  case text
  case mosaic
}

public struct AnnotationColor: Codable, Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = min(max(red, 0), 1)
    self.green = min(max(green, 0), 1)
    self.blue = min(max(blue, 0), 1)
    self.alpha = min(max(alpha, 0), 1)
  }

  public static let red = AnnotationColor(red: 1, green: 0.18, blue: 0.16)
  public static let blue = AnnotationColor(red: 0.12, green: 0.46, blue: 1)
  public static let yellow = AnnotationColor(red: 1, green: 0.78, blue: 0.18)
  public static let green = AnnotationColor(red: 0.18, green: 0.72, blue: 0.34)
  public static let white = AnnotationColor(red: 1, green: 1, blue: 1)
  public static let black = AnnotationColor(red: 0.08, green: 0.08, blue: 0.08)
}

public struct AnnotationStyle: Codable, Equatable, Sendable {
  public var strokeWidth: Double
  public var strokeColor: AnnotationColor
  public var fontSize: Double
  public var textColor: AnnotationColor

  public static let `default` = AnnotationStyle(
    strokeWidth: 4,
    strokeColor: .red,
    fontSize: 24,
    textColor: .red
  )

  public init(
    strokeWidth: Double,
    strokeColor: AnnotationColor,
    fontSize: Double,
    textColor: AnnotationColor
  ) {
    self.strokeWidth = min(max(strokeWidth, 1), 16)
    self.strokeColor = strokeColor
    self.fontSize = min(max(fontSize, 12), 72)
    self.textColor = textColor
  }
}

public struct AnnotationItem: Codable, Equatable, Sendable, Identifiable {
  public var id: UUID
  public var kind: AnnotationKind
  public var points: [Point2D]
  public var text: String
  public var style: AnnotationStyle

  public init(
    id: UUID = UUID(),
    kind: AnnotationKind,
    points: [Point2D],
    text: String = "",
    style: AnnotationStyle = .default
  ) {
    self.id = id
    self.kind = kind
    self.points = points
    self.text = text
    self.style = style
  }
}

public struct AnnotationDocument: Codable, Equatable, Sendable {
  public private(set) var items: [AnnotationItem]
  private var redoStack: [AnnotationItem]

  public init(items: [AnnotationItem] = []) {
    self.items = items
    self.redoStack = []
  }

  public var canUndo: Bool {
    !items.isEmpty
  }

  public var canRedo: Bool {
    !redoStack.isEmpty
  }

  public mutating func append(_ item: AnnotationItem) {
    items.append(item)
    redoStack.removeAll()
  }

  @discardableResult
  public mutating func undo() -> AnnotationItem? {
    guard let item = items.popLast() else {
      return nil
    }
    redoStack.append(item)
    return item
  }

  @discardableResult
  public mutating func redo() -> AnnotationItem? {
    guard let item = redoStack.popLast() else {
      return nil
    }
    items.append(item)
    return item
  }

  public mutating func clear() {
    guard !items.isEmpty else {
      return
    }
    redoStack.append(contentsOf: items.reversed())
    items.removeAll()
  }

  public mutating func reset() {
    items.removeAll()
    redoStack.removeAll()
  }

  public func item(id: UUID) -> AnnotationItem? {
    items.first { $0.id == id }
  }

  @discardableResult
  public mutating func move(id: UUID, dx: Double, dy: Double) -> Bool {
    guard dx != 0 || dy != 0, let index = items.firstIndex(where: { $0.id == id }) else {
      return false
    }
    items[index].points = items[index].points.map { point in
      Point2D(x: point.x + dx, y: point.y + dy)
    }
    redoStack.removeAll()
    return true
  }

  @discardableResult
  public mutating func replace(_ item: AnnotationItem) -> Bool {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else {
      return false
    }
    items[index] = item
    redoStack.removeAll()
    return true
  }

  @discardableResult
  public mutating func remove(id: UUID) -> AnnotationItem? {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      return nil
    }
    redoStack.removeAll()
    return items.remove(at: index)
  }

  public mutating func moveAll(dx: Double, dy: Double) {
    guard dx != 0 || dy != 0 else {
      return
    }

    items = items.map { item in
      var moved = item
      moved.points = item.points.map { point in
        Point2D(x: point.x + dx, y: point.y + dy)
      }
      return moved
    }
    redoStack.removeAll()
  }
}
