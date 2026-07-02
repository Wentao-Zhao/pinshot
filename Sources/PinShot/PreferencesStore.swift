import Foundation
import PinShotCore

@MainActor
final class PreferencesStore {
  private enum Key {
    static let defaultAction = "defaultAction"
    static let saveDirectoryPath = "saveDirectoryPath"
    static let shortcut = "shortcut"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var configuration: PinShotConfiguration {
    get {
      let fallback = PinShotConfiguration.default
      return PinShotConfiguration(
        defaultAction: defaultAction(fallback: fallback.defaultAction),
        saveDirectoryPath: defaults.string(forKey: Key.saveDirectoryPath) ?? fallback.saveDirectoryPath,
        shortcut: shortcut(fallback: fallback.shortcut),
        launchAtLoginEnabled: defaults.object(forKey: Key.launchAtLoginEnabled) as? Bool ?? fallback.launchAtLoginEnabled
      )
    }
    set {
      defaults.set(newValue.defaultAction.rawValue, forKey: Key.defaultAction)
      defaults.set(newValue.saveDirectoryPath, forKey: Key.saveDirectoryPath)
      defaults.set(newValue.launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled)
      if let data = try? JSONEncoder().encode(newValue.shortcut) {
        defaults.set(data, forKey: Key.shortcut)
      }
    }
  }

  private func defaultAction(fallback: ScreenshotDefaultAction) -> ScreenshotDefaultAction {
    guard let rawValue = defaults.string(forKey: Key.defaultAction) else {
      return fallback
    }
    return ScreenshotDefaultAction(rawValue: rawValue) ?? fallback
  }

  private func shortcut(fallback: KeyboardShortcut) -> KeyboardShortcut {
    guard
      let data = defaults.data(forKey: Key.shortcut),
      let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data),
      shortcut.isValid
    else {
      return fallback
    }
    return shortcut
  }
}

