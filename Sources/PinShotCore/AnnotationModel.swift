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

public struct AnnotationItem: Codable, Equatable, Sendable, Identifiable {
  public var id: UUID
  public var kind: AnnotationKind
  public var points: [Point2D]
  public var text: String

  public init(
    id: UUID = UUID(),
    kind: AnnotationKind,
    points: [Point2D],
    text: String = ""
  ) {
    self.id = id
    self.kind = kind
    self.points = points
    self.text = text
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
