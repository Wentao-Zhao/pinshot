import AppKit
import PinShotCore

@MainActor
final class PinnedImageWindowManager {
  private var windows: [PinnedImageWindowController] = []
  private var nextOffset: CGFloat = 0

  func show(image: NSImage) {
    let controller = PinnedImageWindowController(image: image)
    controller.onClose = { [weak self, weak controller] in
      guard let controller else {
        return
      }
      self?.windows.removeAll { $0 === controller }
    }

    windows.append(controller)
    controller.show(offset: nextOffset)
    nextOffset = (nextOffset + 28).truncatingRemainder(dividingBy: 196)
  }
}

@MainActor
private final class PinnedImageWindowController: NSWindowController, NSWindowDelegate, NSPopoverDelegate {
  var onClose: (() -> Void)?
  private let image: NSImage
  private var ocrPopover: NSPopover?
  private var ocrTask: Task<Void, Never>?
  private var ocrResult: OCRPanelState?

  init(image: NSImage) {
    self.image = image
    let window = PinnedImagePanel(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
      styleMask: [.borderless, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "置顶截图"
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false
    window.isMovableByWindowBackground = true
    window.minSize = NSSize(width: 106, height: 44)

    super.init(window: window)
    window.onCopyImage = { [weak self] in self?.copyImage(nil) }
    window.delegate = self
    buildContent(in: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(offset: CGFloat) {
    guard let window else {
      return
    }
    window.setFrame(Self.defaultFrame(for: image, offset: offset, minimum: window.minSize), display: false)
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    ocrTask?.cancel()
    ocrPopover?.close()
    onClose?()
  }

  private func buildContent(in window: NSWindow) {
    let frameView = PinnedImageFrameView(image: image)
    frameView.onCopy = { [weak self] in self?.copyImage(nil) }
    frameView.onRecognize = { [weak self] in self?.toggleOCR(nil) }
    frameView.onClose = { [weak window] in
      window?.close()
    }
    let menu = NSMenu()
    for (title, action) in [
      ("复制图片", #selector(copyImage(_:))),
      ("识别文字", #selector(toggleOCR(_:))),
      ("关闭置顶", #selector(closePin(_:))),
    ] {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
      item.target = self
      menu.addItem(item)
    }
    frameView.imageView.menu = menu
    frameView.menu = menu
    window.contentView = frameView
  }

  @objc private func copyImage(_ sender: Any?) {
    PasteboardWriter.copy(image: image)
  }

  @objc private func closePin(_ sender: Any?) {
    window?.close()
  }

  @objc private func toggleOCR(_ sender: Any?) {
    guard let frameView = window?.contentView as? PinnedImageFrameView else { return }
    if let ocrPopover, ocrPopover.isShown {
      ocrPopover.performClose(nil)
      return
    }

    let popover = ocrPopover ?? makeOCRPopover()
    ocrPopover = popover
    updateOCRPopover(with: ocrResult ?? .recognizing)
    frameView.layoutSubtreeIfNeeded()
    popover.show(relativeTo: frameView.ocrAnchor, of: frameView, preferredEdge: .maxX)

    guard ocrResult == nil, ocrTask == nil else { return }
    ocrTask = Task { [weak self, image] in
      let text = await ImageTextRecognizer.recognizedText(from: image)
      guard !Task.isCancelled, let self else { return }
      self.ocrTask = nil
      let result = OCRPanelState.result(from: text)
      self.ocrResult = result
      if self.ocrPopover?.isShown == true {
        self.updateOCRPopover(with: result)
      }
    }
  }

  private func makeOCRPopover() -> NSPopover {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.delegate = self
    let viewController = NSViewController()
    let panel = OCRStatusPanelView(frame: .zero)
    panel.blendingMode = .withinWindow
    panel.onClose = { [weak popover] in popover?.performClose(nil) }
    viewController.view = panel
    popover.contentViewController = viewController
    return popover
  }

  private func updateOCRPopover(with state: OCRPanelState) {
    guard let ocrPopover, let panel = ocrPopover.contentViewController?.view as? OCRStatusPanelView else { return }
    panel.update(state: state)
    let availableSize = window?.screen?.visibleFrame.size ?? NSSize(width: 384, height: 224)
    ocrPopover.contentSize = panel.preferredSize(in: availableSize)
  }

  func popoverDidClose(_ notification: Notification) {
    (ocrPopover?.contentViewController?.view as? OCRStatusPanelView)?.update(state: .hidden)
  }

  private static func defaultFrame(for image: NSImage, offset: CGFloat, minimum: NSSize) -> NSRect {
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let preferred = NSSize(width: min(visibleFrame.width * 0.42, 560), height: min(visibleFrame.height * 0.46, 460))
    let fitted = PinnedImageFrameView.fit(image.size, in: preferred)
    let width = max(fitted.width, minimum.width)
    let height = max(fitted.height, minimum.height)
    return NSRect(
      x: min(visibleFrame.midX - width / 2 + offset, visibleFrame.maxX - width),
      y: max(visibleFrame.midY - height / 2 - offset, visibleFrame.minY),
      width: width,
      height: height
    )
  }
}

private final class PinnedImagePanel: NSPanel {
  var onCopyImage: (() -> Void)?

  override var canBecomeKey: Bool { true }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if let result = firstResponder as? OCRResultTextView, result.handleKeyEquivalent(event) {
      return true
    }
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "c", let onCopyImage {
      onCopyImage()
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
}
