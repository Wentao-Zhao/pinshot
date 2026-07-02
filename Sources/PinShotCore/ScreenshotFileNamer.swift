import Foundation

public enum ScreenshotFileNamer {
  public static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "Screenshot-\(formatter.string(from: date)).png"
  }

  public static func fileURL(
    directoryPath: String,
    date: Date = Date(),
    timeZone: TimeZone = .current
  ) -> URL {
    URL(fileURLWithPath: directoryPath, isDirectory: true)
      .appendingPathComponent(fileName(for: date, timeZone: timeZone))
  }
}

