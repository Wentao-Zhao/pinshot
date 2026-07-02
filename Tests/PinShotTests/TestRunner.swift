import Foundation
import PinShotCore

private final class TestRecorder {
  private(set) var checks = 0
  private(set) var failures: [String] = []

  func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    checks += 1
    if !condition() {
      failures.append("\(message) (\(file):\(line))")
    }
  }
}

@main
struct TestRunner {
  static func main() {
    let recorder = TestRecorder()

    testDefaultConfiguration(recorder)
    testShortcutMatching(recorder)
    testFileNaming(recorder)
    testSelectionGeometry(recorder)
    testScreenCoordinateMapping(recorder)
    testAnnotationStyleDefaults(recorder)
    testAnnotationUndoRedo(recorder)
    testAnnotationResetDiscardsRedo(recorder)
    testOCRPanelState(recorder)

    if recorder.failures.isEmpty {
      print("PASS: \(recorder.checks) checks")
      exit(0)
    }

    for failure in recorder.failures {
      print("FAIL: \(failure)")
    }
    print("\(recorder.failures.count) failures across \(recorder.checks) checks")
    exit(1)
  }

  private static func testDefaultConfiguration(_ recorder: TestRecorder) {
    let config = PinShotConfiguration.default
    recorder.expect(config.defaultAction == .copyToClipboard, "default action copies to clipboard")
    recorder.expect(config.shortcut == .defaultCapture, "default shortcut is Command Shift 2")
    recorder.expect(!config.launchAtLoginEnabled, "launch at login defaults to disabled")
    recorder.expect(config.saveDirectoryPath.hasSuffix("/Desktop"), "default save directory is Desktop")
    recorder.expect(ScreenshotDefaultAction.allCases == [.copyToClipboard, .saveToFile, .pinImage], "default action options are stable")
  }

  private static func testShortcutMatching(_ recorder: TestRecorder) {
    let shortcut = KeyboardShortcut.defaultCapture
    recorder.expect(shortcut.matches(keyCode: 19, modifiers: [.command, .shift]), "default shortcut matches Command Shift 2")
    recorder.expect(!shortcut.matches(keyCode: 19, modifiers: [.command]), "default shortcut rejects missing Shift")
    recorder.expect(!KeyboardShortcut(keyCode: 19, modifiers: []).isValid, "shortcut requires modifiers")
  }

  private static func testFileNaming(_ recorder: TestRecorder) {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
    components.year = 2026
    components.month = 7
    components.day = 2
    components.hour = 9
    components.minute = 8
    components.second = 7
    let date = components.date!

    recorder.expect(
      ScreenshotFileNamer.fileName(for: date, timeZone: components.timeZone!) == "Screenshot-20260702-090807.png",
      "file name uses configured timestamp format"
    )
    recorder.expect(
      ScreenshotFileNamer.fileURL(directoryPath: "/tmp/screens", date: date, timeZone: components.timeZone!).path == "/tmp/screens/Screenshot-20260702-090807.png",
      "file URL appends generated file name"
    )
  }

  private static func testSelectionGeometry(_ recorder: TestRecorder) {
    let rect = Rect2D.normalized(from: Point2D(x: 40, y: 10), to: Point2D(x: 10, y: 50))
    recorder.expect(rect == Rect2D(x: 10, y: 10, width: 30, height: 40), "selection normalizes drag direction")
    recorder.expect(rect.isUsable, "selection with enough size is usable")

    let moved = rect.movedBy(
      dx: 500,
      dy: -500,
      constrainedTo: Rect2D(x: 0, y: 0, width: 120, height: 90)
    )
    recorder.expect(moved == Rect2D(x: 90, y: 0, width: 30, height: 40), "moving selection clamps to bounds")
  }

  private static func testScreenCoordinateMapping(_ recorder: TestRecorder) {
    let secondaryFrame = Rect2D(x: -1920, y: 120, width: 1920, height: 1080)
    let globalPoint = Point2D(x: -1810, y: 350)
    recorder.expect(
      ScreenCoordinateMapper.localPoint(fromGlobal: globalPoint, inScreenFrame: secondaryFrame) == Point2D(x: 110, y: 230),
      "secondary screen global point maps to local overlay coordinates"
    )

    let mainFrame = Rect2D(x: 0, y: 0, width: 1512, height: 982)
    recorder.expect(
      ScreenCoordinateMapper.localBounds(forScreenFrame: mainFrame) == Rect2D(x: 0, y: 0, width: 1512, height: 982),
      "screen local bounds always start at zero"
    )
  }

  private static func testAnnotationUndoRedo(_ recorder: TestRecorder) {
    var document = AnnotationDocument()
    let first = AnnotationItem(kind: .rectangle, points: [Point2D(x: 1, y: 1), Point2D(x: 4, y: 4)])
    let second = AnnotationItem(kind: .text, points: [Point2D(x: 2, y: 2)], text: "hello")

    document.append(first)
    document.append(second)
    recorder.expect(document.items == [first, second], "annotations append in order")
    recorder.expect(document.undo() == second, "undo returns last annotation")
    recorder.expect(document.items == [first], "undo removes last annotation")
    recorder.expect(document.redo() == second, "redo returns restored annotation")
    recorder.expect(document.items == [first, second], "redo restores annotation")
    document.clear()
    recorder.expect(document.items.isEmpty, "clear removes annotations")
    recorder.expect(document.canRedo, "clear keeps redo data")
  }

  private static func testAnnotationStyleDefaults(_ recorder: TestRecorder) {
    let style = AnnotationStyle.default
    recorder.expect(style.strokeWidth == 4, "default stroke width is visible")
    recorder.expect(style.strokeColor == .red, "default stroke color is red")
    recorder.expect(style.fontSize == 24, "default text size is readable")
    recorder.expect(style.textColor == .red, "default text color is red")

    let customStyle = AnnotationStyle(
      strokeWidth: 7,
      strokeColor: .blue,
      fontSize: 32,
      textColor: .yellow
    )
    let item = AnnotationItem(kind: .arrow, points: [Point2D(x: 0, y: 0), Point2D(x: 10, y: 10)], style: customStyle)
    recorder.expect(item.style == customStyle, "annotation item keeps captured style")
  }

  private static func testAnnotationResetDiscardsRedo(_ recorder: TestRecorder) {
    var document = AnnotationDocument()
    document.append(AnnotationItem(kind: .rectangle, points: [Point2D(x: 1, y: 1), Point2D(x: 4, y: 4)]))
    document.reset()
    recorder.expect(document.items.isEmpty, "reset removes annotations")
    recorder.expect(!document.canRedo, "reset discards redo history")
  }

  private static func testOCRPanelState(_ recorder: TestRecorder) {
    recorder.expect(OCRPanelState.recognizing.isVisible, "recognizing state is visible")
    recorder.expect(!OCRPanelState.hidden.isVisible, "hidden state is not visible")

    let empty = OCRPanelState.result(from: " \n ")
    recorder.expect(empty.previewText == "未识别到文字", "blank OCR result uses fallback text")
    recorder.expect(!empty.canCopy, "blank OCR result cannot be copied")

    let readableText = String(repeating: "识别内容", count: 30)
    let readable = OCRPanelState.result(from: readableText)
    recorder.expect(readable.previewText.count > 80, "OCR result preview keeps enough text for the expanded panel")

    let longText = String(repeating: "识别内容", count: 50)
    let result = OCRPanelState.result(from: longText)
    recorder.expect(result.previewText.count <= 142, "long OCR result preview remains bounded")
    recorder.expect(result.previewText.hasSuffix("…"), "long OCR result preview shows truncation")
    recorder.expect(result.copyText == longText, "OCR result keeps full text for copying")
  }
}
