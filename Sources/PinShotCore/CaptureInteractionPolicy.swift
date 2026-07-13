public struct HotKeyIdentity: Equatable, Sendable {
  public let signature: UInt32
  public let id: UInt32

  public init(signature: UInt32, id: UInt32) {
    self.signature = signature
    self.id = id
  }

  public func matches(signature: UInt32, id: UInt32) -> Bool {
    self.signature == signature && self.id == id
  }

  public static let capture = HotKeyIdentity(signature: 0x5049_4E53, id: 1)
  public static let captureCancel = HotKeyIdentity(signature: 0x5049_4E53, id: 2)
}

public enum CaptureInteractionPolicy {
  public static let acceptsFirstMouse = true
  public static let cancelShortcut = KeyboardShortcut(keyCode: 53, modifiers: [])
}
