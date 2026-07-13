import AppKit
import PinShotCore

enum CaptureCommand {
  case finishDefault
  case copy
  case save
  case pin
  case ocr
  case cancel
}

@MainActor
final class CaptureOverlayWindowController: NSWindowController {
  var onCommand: ((CaptureCommand, NSImage?) -> Void)?

  private let snapshot: ScreenSnapshot

  init(snapshot: ScreenSnapshot) {
    self.snapshot = snapshot

    let panel = CaptureOverlayPanel(
      contentRect: snapshot.screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: snapshot.screen
    )
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.ignoresMouseEvents = false
    panel.isReleasedWhenClosed = false

    super.init(window: panel)
    let overlayView = CaptureOverlayView(snapshot: snapshot)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.onCommand = { [weak self] command, image in
      self?.onCommand?(command, image)
    }
    panel.contentView = overlayView
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show() {
    guard let window else {
      return
    }
    window.setFrame(snapshot.screen.frame, display: false)
    window.contentView?.frame = NSRect(origin: .zero, size: snapshot.screen.frame.size)
    window.orderFrontRegardless()
  }

  func makeKey() {
    window?.makeKey()
  }

  func updateImage(_ image: NSImage?) {
    guard let overlayView = window?.contentView as? CaptureOverlayView else {
      return
    }
    overlayView.updateImage(image)
  }

  func setOCRPanelState(_ state: OCRPanelState) {
    guard let overlayView = window?.contentView as? CaptureOverlayView else {
      return
    }
    overlayView.setOCRPanelState(state)
  }
}

private final class CaptureOverlayPanel: NSPanel {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }
}
