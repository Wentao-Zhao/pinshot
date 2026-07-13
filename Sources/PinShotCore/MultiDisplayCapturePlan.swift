public enum MultiDisplayCaptureStep: Equatable, Sendable {
  case capture(displayID: UInt32)
  case present(displayID: UInt32)
}

public struct MultiDisplayCapturePlan: Equatable, Sendable {
  public let steps: [MultiDisplayCaptureStep]

  public init(displayIDs: [UInt32]) {
    steps = displayIDs.map { .capture(displayID: $0) }
      + displayIDs.map { .present(displayID: $0) }
  }
}
