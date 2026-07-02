import Foundation

public enum OCRPanelState: Equatable, Sendable {
  case hidden
  case recognizing
  case result(previewText: String, copyText: String?)

  public static func result(from text: String?) -> OCRPanelState {
    let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else {
      return .result(previewText: "未识别到文字", copyText: nil)
    }

    return .result(previewText: preview(for: trimmed), copyText: trimmed)
  }

  public var isVisible: Bool {
    self != .hidden
  }

  public var previewText: String {
    switch self {
    case .hidden:
      ""
    case .recognizing:
      "识别中"
    case .result(let previewText, _):
      previewText
    }
  }

  public var copyText: String? {
    switch self {
    case .result(_, let copyText):
      copyText
    case .hidden, .recognizing:
      nil
    }
  }

  public var canCopy: Bool {
    copyText?.isEmpty == false
  }

  private static func preview(for text: String) -> String {
    let compact = text
      .split(whereSeparator: \.isNewline)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    let limit = 140
    guard compact.count > limit else {
      return compact
    }
    return String(compact.prefix(limit)) + "…"
  }
}
