import Foundation

public enum OCRPanelState: Equatable, Sendable {
  case hidden
  case recognizing
  case result(text: String?)

  public static func result(from text: String?) -> OCRPanelState {
    let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return .result(text: trimmed.isEmpty ? nil : trimmed)
  }

  public var isVisible: Bool {
    self != .hidden
  }

  public var displayText: String {
    switch self {
    case .hidden:
      ""
    case .recognizing:
      "识别中"
    case .result(let text):
      text ?? "未识别到文字"
    }
  }

  public var recognizedText: String? {
    guard case .result(let text) = self else { return nil }
    return text
  }
}
