import Foundation

public enum CommandModifier: String, Hashable, Codable, CaseIterable, Sendable {
  case command
  case shift
  case option
  case control
  case function
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
  public var keyCode: UInt16
  public var modifiers: Set<CommandModifier>

  public init(keyCode: UInt16, modifiers: Set<CommandModifier>) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public static let defaultCapture = KeyboardShortcut(
    keyCode: 19,
    modifiers: [.command, .shift]
  )

  public var isValid: Bool {
    !modifiers.isEmpty
  }

  public func matches(keyCode: UInt16, modifiers: Set<CommandModifier>) -> Bool {
    isValid && self.keyCode == keyCode && self.modifiers == modifiers
  }
}

