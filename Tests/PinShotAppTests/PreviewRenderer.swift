import AppKit

/// Renders production views instead of a separate mock UI. Only used by the test runner.
@MainActor
enum PreviewRenderer {
  static func render(to directory: URL, sample: NSImage) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (name, theme) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
      let appearance = NSAppearance(named: name)!
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 980),
                            styleMask: [.borderless], backing: .buffered, defer: false)
      window.appearance = appearance
      window.isReleasedWhenClosed = false
      let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 740, height: 980))
      canvas.wantsLayer = true
      canvas.layer?.backgroundColor = PinShotTheme.resolved(.windowBackgroundColor, for: appearance)
      window.contentView = canvas

      let title = NSTextField(labelWithString: "PinShot · \(theme == "light" ? "浅色模式" : "深色模式")")
      title.font = .systemFont(ofSize: 24, weight: .semibold)
      title.frame = NSRect(x: 28, y: 910, width: 450, height: 36)
      canvas.addSubview(title)

      let icon = NSImageView(image: MenuBarIcon.image)
      icon.contentTintColor = .labelColor
      icon.frame = NSRect(x: 680, y: 921, width: 18, height: 18)
      canvas.addSubview(icon)
      let toolbar = AnnotationToolbarView(frame: .zero)
      toolbar.setSelectedTool(.rectangle)
      canvas.addSubview(toolbar)
      toolbar.frame = NSRect(origin: NSPoint(x: 28, y: 838), size: toolbar.fittingSize)

      let ocr = OCRStatusPanelView(frame: NSRect(x: 28, y: 648, width: 384, height: 160))
      ocr.update(state: .result(from: "项目计划\n本季度完成核心功能的开发与上线。\n选中文字后按 ⌘C 可复制。"))
      canvas.addSubview(ocr)
      let sampleImage = NSImage(cgImage: sample.cgImage(forProposedRect: nil, context: nil, hints: nil)!, size: sample.size)
      let pin = PinnedImageFrameView(image: sampleImage)
      pin.frame = NSRect(x: 434, y: 478, width: 278, height: 160)
      canvas.addSubview(pin)
      let enter = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
                                        windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                        trackingNumber: 0, userData: nil)!
      pin.mouseEntered(with: enter)

      let options = PinShotSurfaceView(frame: NSRect(x: 432, y: 680, width: 280, height: 108))
      let styles = AnnotationStyleOptionsView(style: .default, editsText: false, onStyleChanged: { _ in })
      styles.frame = options.bounds
      options.addSubview(styles)
      canvas.addSubview(options)

      let preferences = PreferencesWindowController(preferencesStore: PreferencesStore(), onConfigurationChanged: {})
      let settings = preferences.window!.contentView!
      settings.removeFromSuperview()
      settings.frame = NSRect(x: 28, y: 26, width: 540, height: 430)
      canvas.addSubview(settings)

      window.displayIfNeeded()
      canvas.layoutSubtreeIfNeeded()
      var data: Data?
      appearance.performAsCurrentDrawingAppearance {
        let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds)!
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        data = bitmap.representation(using: .png, properties: [:])
      }
      try data!.write(to: directory.appendingPathComponent("pinshot-\(theme).png"))
      window.close()
    }
    try renderToolbarComparison(to: directory.appendingPathComponent("toolbar-comparison.png"))
  }

  private static func renderToolbarComparison(to destination: URL) throws {
    let themes: [(NSAppearance.Name, String)] = [(.aqua, "浅色模式"), (.darkAqua, "深色模式")]
    let toolbars = themes.map { name, _ in
      let toolbar = AnnotationToolbarView(frame: .zero)
      toolbar.appearance = NSAppearance(named: name)
      toolbar.setSelectedTool(.rectangle)
      return toolbar
    }
    let width = max(540, toolbars.map { $0.fittingSize.width }.max()! + 48)
    let bounds = NSRect(x: 0, y: 0, width: width, height: 176)
    let window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let canvas = NSView(frame: bounds)
    window.contentView = canvas
    for (index, theme) in themes.enumerated() {
      let appearance = NSAppearance(named: theme.0)!
      let row = NSView(frame: NSRect(x: 0, y: index == 0 ? 88 : 0, width: width, height: 88))
      row.appearance = appearance
      row.wantsLayer = true
      row.layer?.backgroundColor = PinShotTheme.resolved(.windowBackgroundColor, for: appearance)
      canvas.addSubview(row)
      let label = NSTextField(labelWithString: theme.1)
      label.font = .systemFont(ofSize: 11, weight: .medium)
      label.textColor = .secondaryLabelColor
      label.frame = NSRect(x: 24, y: 66, width: 120, height: 16)
      row.addSubview(label)
      let toolbar = toolbars[index]
      row.addSubview(toolbar)
      toolbar.frame = NSRect(origin: NSPoint(x: 24, y: 12), size: toolbar.fittingSize)
    }
    window.displayIfNeeded()
    canvas.layoutSubtreeIfNeeded()
    let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds)!
    canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
    window.close()
  }
}
