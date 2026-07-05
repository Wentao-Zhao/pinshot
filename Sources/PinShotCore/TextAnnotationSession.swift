public struct TextAnnotationSession: Equatable, Sendable {
  public enum Phase: Equatable, Sendable {
    case inactive
    case armed
    case editing
  }

  public private(set) var phase: Phase

  public init() {
    phase = .inactive
  }

  public var usesTextCursor: Bool {
    phase != .inactive
  }

  public mutating func activate() {
    phase = .armed
  }

  @discardableResult
  public mutating func beginEditing() -> Bool {
    guard phase == .armed else {
      return false
    }
    phase = .editing
    return true
  }

  public mutating func finish() {
    phase = .inactive
  }
}
