import Foundation

public enum ScreenshotDefaultAction: String, CaseIterable, Codable, Equatable, Sendable {
  case copyToClipboard
  case saveToFile
  case pinImage

  public var displayName: String {
    switch self {
    case .copyToClipboard:
      "复制到剪贴板"
    case .saveToFile:
      "保存到文件"
    case .pinImage:
      "置顶显示"
    }
  }
}

public struct PinShotConfiguration: Codable, Equatable, Sendable {
  public var defaultAction: ScreenshotDefaultAction
  public var saveDirectoryPath: String
  public var shortcut: KeyboardShortcut
  public var launchAtLoginEnabled: Bool

  public static let `default` = PinShotConfiguration(
    defaultAction: .copyToClipboard,
    saveDirectoryPath: FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Desktop", isDirectory: true)
      .path,
    shortcut: .defaultCapture,
    launchAtLoginEnabled: false
  )

  public init(
    defaultAction: ScreenshotDefaultAction,
    saveDirectoryPath: String,
    shortcut: KeyboardShortcut,
    launchAtLoginEnabled: Bool
  ) {
    self.defaultAction = defaultAction
    self.saveDirectoryPath = saveDirectoryPath
    self.shortcut = shortcut.isValid ? shortcut : .defaultCapture
    self.launchAtLoginEnabled = launchAtLoginEnabled
  }
}

