import AppKit
import PinShotCore

final class PinnedImageFrameView: NSView {
  var onCopy: (() -> Void)?
  var onRecognize: (() -> Void)?
  var onClose: (() -> Void)?

  let imageView: NSImageView = PinnedImageView()
  var ocrAnchor: NSRect { toolbar.frame }

  private let toolbar = PinnedImageToolsSurface(frame: .zero)
  private let resizeHandle = PinnedImageResizeHandle()
  private var pointerTracking: NSTrackingArea?

  init(image: NSImage) {
    super.init(frame: .zero)
    imageView.image = image
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = 10
    imageView.layer?.masksToBounds = true
    imageView.setAccessibilityLabel("置顶截图")
    addSubview(imageView)
    addSubview(resizeHandle)

    toolbar.layer?.cornerRadius = 8
    toolbar.isHidden = true
    addSubview(toolbar)

    for (index, tool) in [
      ("square.on.square", "复制图片", #selector(copyImage)),
      ("text.viewfinder", "识别文字", #selector(recognizeText)),
      ("xmark", "关闭置顶", #selector(closePin)),
    ].enumerated() {
      let button = PinnedImageToolButton(frame: NSRect(x: 3 + index * 28, y: 1, width: 26, height: 26))
      button.image = NSImage(systemSymbolName: tool.0, accessibilityDescription: tool.1)?
        .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
      button.imagePosition = .imageOnly
      button.isBordered = false
      button.contentTintColor = .labelColor
      button.toolTip = tool.1
      button.setAccessibilityLabel(tool.1)
      button.target = self
      button.action = tool.2
      toolbar.addSubview(button)
    }
    toolTip = "拖动移动 · 滚轮缩放 · 右下角调整大小"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    needsLayout = true
  }

  override func layout() {
    super.layout()
    let size = Self.fit(imageView.image?.size ?? bounds.size, in: bounds.size)
    let imageFrame = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                            width: size.width, height: size.height)
    imageView.frame = imageFrame
    let width: CGFloat = 88
    let height: CGFloat = 28
    toolbar.frame = NSRect(
      x: max(bounds.minX + 6, imageFrame.maxX - width - 6),
      y: max(bounds.minY + 4, imageFrame.maxY - height - 6),
      width: width, height: height
    )
    resizeHandle.frame = NSRect(
      x: max(bounds.minX, imageFrame.maxX - 14), y: imageFrame.minY, width: 14, height: 14
    )
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let pointerTracking { removeTrackingArea(pointerTracking) }
    let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                              owner: self, userInfo: nil)
    addTrackingArea(area)
    pointerTracking = area
  }

  override func mouseEntered(with event: NSEvent) { toolbar.isHidden = false }
  override func mouseExited(with event: NSEvent) { toolbar.isHidden = true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }

  override func scrollWheel(with event: NSEvent) {
    guard let window, let screen = window.screen,
          event.momentumPhase.isEmpty, event.scrollingDeltaY != 0,
          abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) else { return }
    // Normalize natural scrolling so a physical upward wheel movement always zooms in.
    let delta = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
    let current = window.frame
    let visible = screen.visibleFrame
    let anchor = event.window == nil
      ? NSPoint(x: current.midX, y: current.midY)
      : window.convertPoint(toScreen: event.locationInWindow)
    let result = PinnedImageZoomPolicy.frame(
      byZooming: Rect2D(x: current.minX, y: current.minY, width: current.width, height: current.height),
      at: Point2D(x: anchor.x, y: anchor.y), scrollDelta: delta,
      precise: event.hasPreciseScrollingDeltas,
      minimumWidth: window.minSize.width, minimumHeight: window.minSize.height,
      visibleFrame: Rect2D(x: visible.minX, y: visible.minY, width: visible.width, height: visible.height)
    )
    window.setFrame(NSRect(x: result.x, y: result.y, width: result.width, height: result.height), display: true)
  }

  static func fit(_ image: NSSize, in bounds: NSSize) -> NSSize {
    guard image.width > 0, image.height > 0 else { return bounds }
    let scale = min(bounds.width / image.width, bounds.height / image.height)
    return NSSize(width: image.width * scale, height: image.height * scale)
  }

  @objc private func copyImage() { onCopy?() }
  @objc private func recognizeText() { onRecognize?() }
  @objc private func closePin() { onClose?() }
}

private final class PinnedImageView: NSImageView {
  // Screenshot pixels must not participate in the dark material's vibrancy blending.
  override var allowsVibrancy: Bool { false }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
  override func scrollWheel(with event: NSEvent) { superview?.scrollWheel(with: event) }
}

private final class PinnedImageToolsSurface: PinShotSurfaceView {
  override func scrollWheel(with event: NSEvent) { superview?.scrollWheel(with: event) }
}

private final class PinnedImageToolButton: NSButton {
  override var mouseDownCanMoveWindow: Bool { false }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func scrollWheel(with event: NSEvent) { superview?.scrollWheel(with: event) }
}

private final class PinnedImageResizeHandle: NSView {
  private var start: (point: NSPoint, frame: NSRect)?

  override var mouseDownCanMoveWindow: Bool { false }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func resetCursorRects() {
    if #available(macOS 15.0, *) {
      addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
    } else {
      addCursorRect(bounds, cursor: .crosshair)
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard let window else { return }
    start = (window.convertPoint(toScreen: event.locationInWindow), window.frame)
  }

  override func mouseDragged(with event: NSEvent) {
    guard let window, let start else { return }
    let point = window.convertPoint(toScreen: event.locationInWindow)
    let ratio = start.frame.width / start.frame.height
    let horizontal = point.x - start.point.x
    let vertical = (start.point.y - point.y) * ratio
    let delta = abs(horizontal) > abs(vertical) ? horizontal : vertical
    let width = max(start.frame.width + delta, window.minSize.width, window.minSize.height * ratio)
    let height = width / ratio
    window.setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height),
                    display: true)
  }

  override func mouseUp(with event: NSEvent) { start = nil }
}
