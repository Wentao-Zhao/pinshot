import AppKit
import PinShotCore

// Observe copy commands without replacing the user's clipboard.
@MainActor
enum PasteboardWriter {
  static var images: [NSImage] = []
  static var texts: [String] = []

  static func copy(image: NSImage) { images.append(image) }
  static func copy(text: String) { texts.append(text) }
}

@main
@MainActor
enum PinShotAppTests {
  private static var failures = 0
  private static var checks = 0

  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    guard let screen = NSScreen.main else {
      print("FAIL: an active macOS display is required")
      exit(1)
    }

    testThemeContrast()
    let toolbar = AnnotationToolbarView(frame: NSRect(x: 0, y: 0, width: 640, height: 48))
    for label in ["取消截图", "复制截图"] {
      expect(button(label, in: toolbar) != nil, "capture toolbar exposes \(label)")
    }

    let manager = PinnedImageWindowManager()
    let first = NSImage(size: NSSize(width: 320, height: 200))
    first.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: first.size).fill()
    ("PINSHOT TEST 123" as NSString).draw(at: NSPoint(x: 25, y: 85), withAttributes: [
      .font: NSFont.systemFont(ofSize: 26, weight: .bold), .foregroundColor: NSColor.black,
    ])
    first.unlockFocus()
    let second = NSImage(size: NSSize(width: 200, height: 320))
    manager.show(image: first)
    let firstWindow = app.windows.first { $0.isVisible }!
    manager.show(image: second)
    let secondWindow = app.windows.first { $0.isVisible && $0 !== firstWindow }!

    let copy = key("c", in: firstWindow)
    expect(firstWindow.performKeyEquivalent(with: copy), "pinned window handles Command-C")
    expect(PasteboardWriter.images.last === first, "Command-C copies the addressed pin's original image")
    let shiftedCopy = key("c", modifiers: [.command, .shift], in: firstWindow)
    expect(!firstWindow.performKeyEquivalent(with: shiftedCopy), "pin does not capture Command-Shift-C")

    let imageView = descendants(of: secondWindow.contentView).compactMap { $0 as? NSImageView }.first
    if let menu = imageView?.menu, let index = menu.items.firstIndex(where: { $0.title == "复制图片" }) {
      menu.performActionForItem(at: index)
      expect(PasteboardWriter.images.last === second, "context menu copies the second pin, not the first")
    } else {
      expect(false, "pinned image offers Copy Image in its context menu")
    }
    expect(!firstWindow.styleMask.contains(.titled), "pin has no native title bar")
    firstWindow.contentView?.layoutSubtreeIfNeeded()
    let pin = firstWindow.contentView!
    if let fullImage = descendants(of: pin).compactMap({ $0 as? NSImageView }).first {
      expect(fullImage.frame.equalTo(pin.bounds), "ordinary screenshot fills the pin without an inset")
    }
    expect(abs(firstWindow.frame.width / firstWindow.frame.height - first.size.width / first.size.height) < 0.01,
           "initial frame fits the image ratio")
    let beforeResize = firstWindow.frame
    let corner = NSPoint(x: pin.bounds.maxX - 7, y: pin.bounds.minY + 7)
    if let handle = pin.hitTest(corner), handle !== pin {
      handle.mouseDown(with: mouse(.leftMouseDown, at: corner, in: firstWindow))
      let largerCorner = NSPoint(x: corner.x + 48, y: corner.y - 30)
      handle.mouseDragged(with: mouse(.leftMouseDragged, at: largerCorner, in: firstWindow))
      handle.mouseUp(with: mouse(.leftMouseUp, at: corner, in: firstWindow))
      expect(firstWindow.frame.width > beforeResize.width, "dragging the bottom right resizes the pin")
      expect(abs(firstWindow.frame.width / firstWindow.frame.height - 1.6) < 0.01,
             "resizing keeps the screenshot's aspect ratio")
    } else {
      expect(false, "pin has a bottom-right resize handle")
    }

    if let imageView = descendants(of: pin).compactMap({ $0 as? NSImageView }).first {
      let beforeWheel = firstWindow.frame
      imageView.scrollWheel(with: scroll(1))
      expect(firstWindow.frame.width > beforeWheel.width, "scrolling up over the image enlarges the pin")
      expect(abs(firstWindow.frame.width / firstWindow.frame.height - 1.6) < 0.01,
             "wheel zoom preserves image aspect ratio")
      let enlarged = firstWindow.frame
      imageView.scrollWheel(with: scroll(-1))
      expect(firstWindow.frame.width < enlarged.width, "scrolling down over the image shrinks the pin")
      expect(abs(firstWindow.frame.width - beforeWheel.width) <= 1,
             "equal opposite wheel steps restore the pin size within window pixel rounding")
      let beforeHorizontal = firstWindow.frame
      imageView.scrollWheel(with: scroll(0, horizontal: 5))
      expect(firstWindow.frame.equalTo(beforeHorizontal),
             "horizontal scrolling does not zoom the pin")
      imageView.scrollWheel(with: scroll(1, horizontal: 8))
      expect(firstWindow.frame.equalTo(beforeHorizontal), "mostly horizontal trackpad gestures do not zoom")
      imageView.scrollWheel(with: scroll(5, momentum: 2))
      expect(firstWindow.frame.equalTo(beforeHorizontal), "trackpad inertia does not keep zooming after release")
      imageView.scrollWheel(with: scroll(-10000))
      expect(firstWindow.frame.width >= firstWindow.minSize.width
               && firstWindow.frame.height >= firstWindow.minSize.height,
             "wheel zoom respects minimum pin dimensions")
      imageView.scrollWheel(with: scroll(10000))
      expect(firstWindow.frame.width <= screen.visibleFrame.width + 0.1
               && firstWindow.frame.height <= screen.visibleFrame.height + 0.1,
             "wheel zoom fits the current display")
      firstWindow.setFrame(beforeWheel, display: false)
    }

    if let copyButton = button("复制图片", in: pin),
       let ocrButton = button("识别文字", in: pin),
       let closeButton = button("关闭置顶", in: pin) {
      expect(copyButton.isHiddenOrHasHiddenAncestor, "pin starts with its toolbar hidden")
      pin.mouseEntered(with: tracking(.mouseEntered, in: firstWindow))
      expect(!copyButton.isHiddenOrHasHiddenAncestor, "hover shows the toolbar")
      expect(button("复制图片", in: secondWindow.contentView!)?.isHiddenOrHasHiddenAncestor == true,
             "hovering one pin does not show tools on another")
      copyButton.performClick(nil)
      expect(PasteboardWriter.images.last === first, "toolbar copies its own original image")
      pin.mouseExited(with: tracking(.mouseExited, in: firstWindow))
      expect(copyButton.isHiddenOrHasHiddenAncestor, "leaving the pin hides its toolbar")
      pin.mouseEntered(with: tracking(.mouseEntered, in: firstWindow))
      ocrButton.performClick(nil)
      var result: NSTextView?
      for _ in 0..<50 {
        result = app.windows.flatMap { descendants(of: $0.contentView) }
          .compactMap { $0 as? NSTextView }
          .first { $0.string.contains("PINSHOT") }
        if result != nil { break }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
      }
      if let result, let ocrWindow = result.window {
        expect(result.isSelectable, "pin OCR shows selectable text")
        ocrWindow.makeFirstResponder(result)
        result.setSelectedRange((result.string as NSString).range(of: "PINSHOT"))
        _ = result.performKeyEquivalent(with: key("c", in: ocrWindow))
        expect(PasteboardWriter.texts.last == "PINSHOT", "pin OCR Command-C copies selected text")
      } else {
        expect(false, "pin OCR recognizes the actual image asynchronously")
      }
      closeButton.performClick(nil)
      expect(!firstWindow.isVisible && secondWindow.isVisible, "closing one pin leaves the other open")
    } else {
      expect(false, "pin offers a three-action hover toolbar")
    }
    if firstWindow.isVisible { firstWindow.close() }
    secondWindow.close()
    PasteboardWriter.texts.removeAll()

    testPinnedWindowEscape(app: app, image: first)

    let controller = CaptureOverlayWindowController(snapshot: ScreenSnapshot(screen: screen, image: first))
    let window = controller.window!
    let captureView = window.contentView!
    captureView.mouseDown(with: mouse(.leftMouseDown, at: NSPoint(x: 100, y: 100), in: window))
    captureView.mouseDragged(with: mouse(.leftMouseDragged, at: NSPoint(x: 600, y: 400), in: window))
    captureView.mouseUp(with: mouse(.leftMouseUp, at: NSPoint(x: 600, y: 400), in: window))
    var received: CaptureCommand?
    var receivedImage: NSImage?
    controller.onCommand = { command, image in received = command; receivedImage = image }
    button("复制截图", in: captureView)?.performClick(nil)
    if case .copy? = received {
      expect(receivedImage != nil, "toolbar copy emits the rendered selection")
    } else { expect(false, "toolbar copy routes to the capture command") }
    captureView.keyDown(with: key("\r", modifiers: [], keyCode: 36, in: window))
    if case .finishDefault? = received {
      expect(receivedImage != nil, "Return emits the rendered selection")
    } else { expect(false, "Return follows the configured completion action") }
    button("取消截图", in: captureView)?.performClick(nil)
    if case .cancel? = received {
      expect(receivedImage == nil, "toolbar cancel does not export a screenshot")
    } else { expect(false, "toolbar cancel routes to the capture command") }
    let text = "第一行：你好 🌏\n" + String(repeating: "保留完整内容，不截断。\n", count: 50) + "最后一行"
    controller.setOCRPanelState(.result(from: text))
    window.contentView?.layoutSubtreeIfNeeded()
    let views = descendants(of: window.contentView)
    if let result = views.compactMap({ $0 as? NSTextView }).first {
      expect(result.isSelectable && !result.isEditable, "OCR results support native text selection")
      expect(result.string == text && result.enclosingScrollView != nil, "the full OCR result is visible in a scroll view")
      if let scrollView = result.enclosingScrollView {
        result.layoutManager?.ensureLayout(for: result.textContainer!)
        expect(scrollView.contentSize.height > 80, "OCR scroll viewport has room for multiple lines")
        expect(result.frame.height > scrollView.contentSize.height, "long OCR text scrolls beyond the viewport")
      }
      let range = (text as NSString).range(of: "你好 🌏")
      expect(window.makeFirstResponder(result), "OCR result can take focus in the nonactivating capture overlay")
      result.setSelectedRange(range)
      expect(window.performKeyEquivalent(with: key("c", in: window)), "the capture panel routes Command-C to OCR selection")
      expect(PasteboardWriter.texts.last == "你好 🌏", "copy sends only the selected OCR text, preserving Unicode")
      result.setSelectedRange(NSRange(location: 0, length: 0))
      result.copy(nil)
      expect(PasteboardWriter.texts.count == 1, "copy with no selection leaves the clipboard untouched")
      if let copyAll = views.compactMap({ $0 as? NSButton }).first(where: { $0.title == "复制全部" }) {
        copyAll.performClick(nil)
        expect(PasteboardWriter.texts.last == text && result.string == text, "copy all keeps the original OCR result available")
      } else {
        expect(false, "copy all is still available")
      }
      expect(window.performKeyEquivalent(with: key("a", in: window)), "the capture panel routes Command-A to OCR")
      expect(result.selectedRange().length == (text as NSString).length, "Command-A selects the whole result")
      controller.setOCRPanelState(.hidden)
      expect(window.firstResponder === window.contentView, "closing OCR returns keyboard focus to the capture overlay")
    } else {
      expect(false, "OCR shows a selectable text view instead of a label")
    }
    controller.close()

    if let path = ProcessInfo.processInfo.environment["PINSHOT_UI_PREVIEW_DIR"] {
      do {
        try PreviewRenderer.render(to: URL(fileURLWithPath: path, isDirectory: true), sample: first)
        expect(true, "light and dark previews render successfully")
      } catch { expect(false, "UI previews failed: \(error)") }
    }

    print(failures == 0 ? "PASS: \(checks) AppKit interaction checks" : "FAIL: \(failures) of \(checks) checks")
    exit(failures == 0 ? 0 : 1)
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    checks += 1
    if !condition() {
      failures += 1
      print("FAIL: \(description)")
    }
  }

  private static func testPinnedWindowEscape(app: NSApplication, image: NSImage) {
    let manager = PinnedImageWindowManager()
    manager.show(image: image)
    let first = app.windows.first { $0.isVisible && $0.title == "置顶截图" }!
    manager.show(image: image)
    let second = app.windows.first { $0.isVisible && $0.title == "置顶截图" && $0 !== first }!
    defer {
      if first.isVisible { first.close() }
      if second.isVisible { second.close() }
    }

    let unrelated = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 200, height: 100),
                            styleMask: [.titled], backing: .buffered, defer: false)
    unrelated.isReleasedWhenClosed = false
    unrelated.makeKeyAndOrderFront(nil)
    app.sendEvent(key("\u{1b}", modifiers: [], keyCode: 53, in: unrelated))
    expect(first.isVisible && second.isVisible, "Escape in an unrelated window leaves all pins open")
    unrelated.close()

    first.makeKeyAndOrderFront(nil)
    app.sendEvent(key("\u{1b}", modifiers: [], keyCode: 53, in: first))
    expect(!first.isVisible && second.isVisible, "Escape closes only the key pin, not the most recently created pin")

    manager.show(image: image)
    let third = app.windows.first { $0.isVisible && $0.title == "置顶截图" && $0 !== second }!
    defer { if third.isVisible { third.close() } }
    second.makeKeyAndOrderFront(nil)
    guard let pin = second.contentView, let ocrButton = button("识别文字", in: pin) else {
      expect(false, "Escape OCR test finds the pin's OCR action")
      return
    }
    pin.mouseEntered(with: tracking(.mouseEntered, in: second))
    ocrButton.performClick(nil)
    var result: NSTextView?
    for _ in 0..<50 {
      result = app.windows.flatMap { descendants(of: $0.contentView) }
        .compactMap { $0 as? NSTextView }
        .first { $0.window?.isVisible == true && $0.string.contains("PINSHOT") }
      if result != nil { break }
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    guard let result, let ocrWindow = result.window else {
      expect(false, "Escape OCR test recognizes the pinned image")
      return
    }
    ocrWindow.makeKeyAndOrderFront(nil)
    expect(ocrWindow.makeFirstResponder(result), "pinned OCR text takes first responder before Escape")
    app.sendEvent(key("\u{1b}", modifiers: [], keyCode: 53, in: ocrWindow))
    expect(!second.isVisible, "Escape from focused OCR text closes its owning pin")
    expect(!ocrWindow.isVisible, "closing a pin with Escape also dismisses its OCR popover")
    expect(third.isVisible, "Escape from OCR leaves unrelated pins open")
  }

  private static func testThemeContrast() {
    for name in [NSAppearance.Name.aqua, .darkAqua] {
      let appearance = NSAppearance(named: name)!
      let panel = OCRStatusPanelView(frame: NSRect(x: 0, y: 0, width: 384, height: 160))
      panel.appearance = appearance
      panel.update(state: .result(from: "浅色和深色都必须清晰可读"))
      let result = descendants(of: panel).compactMap { $0 as? NSTextView }.first!
      appearance.performAsCurrentDrawingAppearance {
        let foreground = result.textColor!.usingColorSpace(.sRGB)!
        let background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB)!
        expect(contrast(foreground, background) >= 4.5,
               "OCR text has readable contrast in \(name.rawValue)")
      }
    }
    let surface = PinShotSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))
    surface.appearance = NSAppearance(named: .aqua)
    let light = surface.layer?.backgroundColor
    surface.appearance = NSAppearance(named: .darkAqua)
    expect(light != surface.layer?.backgroundColor, "changing appearance updates resolved layer colors immediately")
  }

  private static func contrast(_ foreground: NSColor, _ background: NSColor) -> CGFloat {
    func luminance(_ color: NSColor) -> CGFloat {
      func linear(_ value: CGFloat) -> CGFloat {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * linear(color.redComponent)
        + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
    }
    let alpha = foreground.alphaComponent
    let composited = NSColor(srgbRed: foreground.redComponent * alpha + background.redComponent * (1 - alpha),
                             green: foreground.greenComponent * alpha + background.greenComponent * (1 - alpha),
                             blue: foreground.blueComponent * alpha + background.blueComponent * (1 - alpha), alpha: 1)
    let values = [luminance(composited), luminance(background)]
    return (values.max()! + 0.05) / (values.min()! + 0.05)
  }

  private static func scroll(_ vertical: Int32, horizontal: Int32 = 0, momentum: Int64 = 0) -> NSEvent {
    let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                        wheel1: vertical, wheel2: horizontal, wheel3: 0)!
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
    return NSEvent(cgEvent: event)!
  }

  private static func descendants(of view: NSView?) -> [NSView] {
    guard let view else { return [] }
    return [view] + view.subviews.flatMap { descendants(of: $0) }
  }

  private static func button(_ label: String, in view: NSView) -> NSButton? {
    descendants(of: view).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == label }
  }

  private static func tracking(_ type: NSEvent.EventType, in window: NSWindow) -> NSEvent {
    NSEvent.enterExitEvent(
      with: type, location: NSPoint(x: 40, y: 40), modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
    )!
  }

  private static func mouse(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) -> NSEvent {
    NSEvent.mouseEvent(
      with: type, location: point, modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
    )!
  }

  private static func key(
    _ character: String, modifiers: NSEvent.ModifierFlags = .command, keyCode: UInt16 = 8, in window: NSWindow
  ) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: window.windowNumber, context: nil, characters: character,
      charactersIgnoringModifiers: character, isARepeat: false, keyCode: keyCode
    )!
  }
}
