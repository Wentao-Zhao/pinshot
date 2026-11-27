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
    testMultiDisplayCapturePlan(recorder)
    testCaptureInteractionPolicy(recorder)
    testAnnotationStyleDefaults(recorder)
    testPrimaryDrawingTools(recorder)
    testAnnotationUndoRedo(recorder)
    testAnnotationResetDiscardsRedo(recorder)
    testAnnotationHitTesting(recorder)
    testAnnotationItemEditing(recorder)
    testTextAnnotationSession(recorder)
    testOCRPanelState(recorder)
    testPinnedImageZoom(recorder)

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

  private static func testPinnedImageZoom(_ recorder: TestRecorder) {
    let original = Rect2D(x: 100, y: 100, width: 400, height: 250)
    let anchor = Point2D(x: 200, y: 200)
    let bounds = Rect2D(x: -1000, y: -1000, width: 3000, height: 2000)
    func zoom(_ frame: Rect2D, _ delta: Double, precise: Bool = false, in visible: Rect2D? = nil) -> Rect2D {
      PinnedImageZoomPolicy.frame(byZooming: frame, at: anchor, scrollDelta: delta, precise: precise,
                                  minimumWidth: 106, minimumHeight: 44, visibleFrame: visible ?? bounds)
    }
    let enlarged = zoom(original, 1)
    recorder.expect(enlarged.width > original.width, "wheel up enlarges a pinned image")
    recorder.expect(abs(enlarged.width / enlarged.height - 1.6) < 0.000001, "zoom preserves aspect ratio")
    recorder.expect(abs((anchor.x - enlarged.x) / enlarged.width - 0.25) < 0.000001,
                    "zoom preserves the horizontal image point beneath the pointer")
    recorder.expect(abs((anchor.y - enlarged.y) / enlarged.height - 0.4) < 0.000001,
                    "zoom preserves the vertical image point beneath the pointer")
    let restored = zoom(enlarged, -1)
    recorder.expect(abs(restored.width - original.width) < 0.000001
                      && abs(restored.x - original.x) < 0.000001,
                    "opposite wheel steps exactly undo each other before pixel rounding")
    let tiny = zoom(original, -10000)
    recorder.expect(tiny.width >= 106 && tiny.height >= 44, "minimum zoom leaves tools usable")
    let large = zoom(original, 10000)
    recorder.expect(large.width <= bounds.width && large.height <= bounds.height, "maximum zoom fits the display")
    recorder.expect(large.minX >= bounds.minX && large.maxX <= bounds.maxX
                      && large.minY >= bounds.minY && large.maxY <= bounds.maxY,
                    "zoom clamps the entire pin to the visible display")
    recorder.expect(zoom(original, 1, precise: true).width < enlarged.width,
                    "trackpad pixel deltas use gentler sensitivity than wheel ticks")
    recorder.expect(zoom(original, 0) == original, "zero scroll leaves the pin in place")
    recorder.expect(zoom(original, .nan) == original, "invalid scroll leaves the pin unchanged")
    let portrait = zoom(Rect2D(x: 100, y: 100, width: 120, height: 800), -10000)
    recorder.expect(portrait.width >= 106 && portrait.height >= 44, "portrait zoom respects both minimum dimensions")
    let secondary = Rect2D(x: -1920, y: 0, width: 1920, height: 1080)
    let secondaryPin = zoom(Rect2D(x: -1500, y: 200, width: 400, height: 250), 10000, in: secondary)
    recorder.expect(secondaryPin.minX >= secondary.minX && secondaryPin.maxX <= secondary.maxX,
                    "zoom stays on a secondary screen with a negative origin")
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

  private static func testMultiDisplayCapturePlan(_ recorder: TestRecorder) {
    let plan = MultiDisplayCapturePlan(displayIDs: [101, 202])
    recorder.expect(
      plan.steps == [
        .capture(displayID: 101),
        .capture(displayID: 202),
        .present(displayID: 101),
        .present(displayID: 202),
      ],
      "all displays are captured before any overlay is presented"
    )
    recorder.expect(
      MultiDisplayCapturePlan(displayIDs: []).steps.isEmpty,
      "an empty display list does not start a capture session"
    )
  }

  private static func testCaptureInteractionPolicy(_ recorder: TestRecorder) {
    recorder.expect(
      CaptureInteractionPolicy.acceptsFirstMouse,
      "the first drag is delivered before an overlay becomes key"
    )
    recorder.expect(
      CaptureInteractionPolicy.cancelShortcut.keyCode == 53
        && CaptureInteractionPolicy.cancelShortcut.modifiers.isEmpty,
      "Escape cancels an inactive capture session without extra modifiers"
    )
    recorder.expect(
      HotKeyIdentity.capture != .captureCancel,
      "capture and cancel hot keys use distinct identities"
    )
    recorder.expect(
      HotKeyIdentity.capture.matches(signature: HotKeyIdentity.capture.signature, id: HotKeyIdentity.capture.id),
      "a hot key identity matches its own Carbon event"
    )
    recorder.expect(
      !HotKeyIdentity.capture.matches(
        signature: HotKeyIdentity.captureCancel.signature,
        id: HotKeyIdentity.captureCancel.id
      ),
      "a hot key identity rejects another monitor's Carbon event"
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

  private static func testPrimaryDrawingTools(_ recorder: TestRecorder) {
    recorder.expect(
      AnnotationTool.primaryDrawingTools == [.rectangle, .arrow, .pen],
      "primary drawing tools stay promoted to the top-level toolbar"
    )
  }

  private static func testAnnotationResetDiscardsRedo(_ recorder: TestRecorder) {
    var document = AnnotationDocument()
    document.append(AnnotationItem(kind: .rectangle, points: [Point2D(x: 1, y: 1), Point2D(x: 4, y: 4)]))
    document.reset()
    recorder.expect(document.items.isEmpty, "reset removes annotations")
    recorder.expect(!document.canRedo, "reset discards redo history")
  }

  private static func testAnnotationHitTesting(_ recorder: TestRecorder) {
    let rectangle = AnnotationItem(
      kind: .rectangle,
      points: [Point2D(x: 10, y: 10), Point2D(x: 80, y: 70)]
    )
    let arrow = AnnotationItem(
      kind: .arrow,
      points: [Point2D(x: 20, y: 20), Point2D(x: 100, y: 100)]
    )
    let text = AnnotationItem(
      kind: .text,
      points: [Point2D(x: 30, y: 30)],
      text: "editable"
    )
    let textBounds = [text.id: Rect2D(x: 30, y: 30, width: 90, height: 30)]

    recorder.expect(
      AnnotationHitTester.contains(Point2D(x: 12, y: 40), item: rectangle),
      "rectangle hit testing includes its visible border"
    )
    recorder.expect(
      !AnnotationHitTester.contains(Point2D(x: 40, y: 40), item: rectangle),
      "rectangle hit testing leaves its empty interior available"
    )
    recorder.expect(
      AnnotationHitTester.contains(Point2D(x: 55, y: 58), item: arrow),
      "arrow hit testing accepts points near its line"
    )
    recorder.expect(
      !AnnotationHitTester.contains(Point2D(x: 25, y: 90), item: arrow),
      "arrow hit testing rejects empty space inside its bounding box"
    )
    recorder.expect(
      AnnotationHitTester.topmostItemID(
        at: Point2D(x: 32, y: 32),
        in: [rectangle, text],
        textBounds: textBounds
      ) == text.id,
      "hit testing prefers the last drawn annotation"
    )
    recorder.expect(
      AnnotationHitTester.topmostItemID(
        at: Point2D(x: 32, y: 32),
        in: [rectangle, text],
        kinds: [.text],
        textBounds: textBounds
      ) == text.id,
      "hit testing can restrict matches to text annotations"
    )
  }

  private static func testAnnotationItemEditing(_ recorder: TestRecorder) {
    let first = AnnotationItem(kind: .rectangle, points: [Point2D(x: 1, y: 1), Point2D(x: 4, y: 4)])
    let text = AnnotationItem(kind: .text, points: [Point2D(x: 10, y: 10)], text: "old")
    var document = AnnotationDocument(items: [first, text])

    recorder.expect(document.move(id: first.id, dx: 5, dy: 7), "an existing annotation can be moved")
    recorder.expect(document.items[0].points[0] == Point2D(x: 6, y: 8), "moving updates only the target annotation")
    recorder.expect(document.items[1] == text, "moving one annotation leaves the others unchanged")

    var editedText = text
    editedText.text = "new"
    recorder.expect(document.replace(editedText), "an existing text annotation can be replaced")
    recorder.expect(document.items[1] == editedText, "text replacement preserves its drawing order")
    recorder.expect(document.remove(id: editedText.id) == editedText, "an emptied text annotation can be removed")
  }

  private static func testTextAnnotationSession(_ recorder: TestRecorder) {
    var session = TextAnnotationSession()
    recorder.expect(session.phase == .inactive, "text editing starts inactive")
    recorder.expect(!session.usesTextCursor, "inactive text editing uses the normal cursor")

    session.activate()
    recorder.expect(session.phase == .armed, "selecting the text tool arms one text annotation")
    recorder.expect(session.usesTextCursor, "armed text editing uses the text cursor")
    recorder.expect(session.beginEditing(), "the first canvas click starts text editing")
    recorder.expect(session.phase == .editing, "text editing records an active field")
    recorder.expect(!session.beginEditing(), "an active text field cannot create another field")

    session.finish()
    recorder.expect(session.phase == .inactive, "committing text exits text editing mode")
    recorder.expect(!session.usesTextCursor, "committing text restores the normal cursor")
  }

  private static func testOCRPanelState(_ recorder: TestRecorder) {
    recorder.expect(OCRPanelState.recognizing.isVisible, "recognizing state is visible")
    recorder.expect(!OCRPanelState.hidden.isVisible, "hidden state is not visible")

    let empty = OCRPanelState.result(from: " \n ")
    recorder.expect(empty.displayText == "未识别到文字", "blank OCR result uses fallback text")
    recorder.expect(empty.recognizedText == nil, "blank OCR result cannot be copied")

    let longText = "第一行\n\n" + String(repeating: "识别内容", count: 50)
    let result = OCRPanelState.result(from: longText)
    recorder.expect(result.displayText == longText, "OCR displays the full text with line breaks")
    recorder.expect(result.recognizedText == longText, "OCR result keeps full text for copying")
  }
}
