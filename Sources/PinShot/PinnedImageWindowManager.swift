import AppKit

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
private final class PinnedImageWindowController: NSWindowController, NSWindowDelegate {
  var onClose: (() -> Void)?
  private let image: NSImage

  init(image: NSImage) {
    self.image = image
    let window = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = ""
    window.titleVisibility = .hidden
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false
    window.isMovableByWindowBackground = true
    window.minSize = NSSize(width: 220, height: 160)
    window.titlebarAppearsTransparent = true
    window.standardWindowButton(.closeButton)?.isHidden = false

    super.init(window: window)
    window.delegate = self
    buildContent(in: window)
    configureWindowControls(in: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(offset: CGFloat) {
    guard let window else {
      return
    }
    window.setFrame(Self.defaultFrame(for: image, offset: offset), display: false)
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    onClose?()
  }

  private func buildContent(in window: NSWindow) {
    let frameView = PinnedImageFrameView()
    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = image
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = 12
    imageView.layer?.masksToBounds = true
    frameView.addSubview(imageView)
    window.contentView = frameView

    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
      imageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -8),
      imageView.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 26),
      imageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: -8),
    ])
  }

  private func configureWindowControls(in window: NSWindow) {
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    guard
      let closeButton = window.standardWindowButton(.closeButton),
      let container = closeButton.superview
    else {
      return
    }
    closeButton.setFrameOrigin(NSPoint(x: 16, y: max(container.bounds.height - closeButton.frame.height - 12, 8)))
  }

  private static func defaultFrame(for image: NSImage, offset: CGFloat) -> NSRect {
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let aspectRatio = image.size.width > 0 && image.size.height > 0 ? image.size.width / image.size.height : 4 / 3
    var width = min(visibleFrame.width * 0.42, 560)
    var height = width / aspectRatio
    let maxHeight = min(visibleFrame.height * 0.46, 460)
    if height > maxHeight {
      height = maxHeight
      width = height * aspectRatio
    }
    width = min(max(width, 260), visibleFrame.width - 40)
    height = min(max(height, 180), visibleFrame.height - 40)
    return NSRect(
      x: visibleFrame.midX - width / 2 + offset,
      y: visibleFrame.midY - height / 2 - offset,
      width: width,
      height: height
    )
  }
}

private final class PinnedImageFrameView: NSView {
  override var isOpaque: Bool {
    false
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 4, dy: 4)
    let path = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -5)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.windowBackgroundColor.withAlphaComponent(0.72).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
  }
}
